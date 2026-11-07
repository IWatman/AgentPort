package com.iwatman.agentport

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Bridges APK installation requests from Flutter to the Android package installer.
 *
 * The primary path uses a [PackageInstaller] session, which is the supported way for an
 * application to install an update of itself. When a session cannot be created the code falls
 * back to opening the package installer through an [Intent] with a [FileProvider] URI.
 */
class ApkInstaller(context: Context) : MethodChannel.MethodCallHandler {
    private val context = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_INSTALL_APK -> {
                val path = call.arguments as? String
                // Copying the APK into the session can take a while, so keep it off the main thread.
                executor.execute { installApk(path, result) }
            }

            METHOD_CAN_INSTALL_PACKAGES -> result.success(canInstallPackages())
            else -> result.notImplemented()
        }
    }

    private fun installApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            postError(result, ERROR_INVALID_FILE, "The APK path is empty.")
            return
        }

        val apk = File(path)
        if (!apk.exists() || !apk.isFile) {
            postError(result, ERROR_FILE_NOT_FOUND, "The APK does not exist: $path")
            return
        }
        if (!apk.name.lowercase(Locale.ROOT).endsWith(APK_EXTENSION)) {
            postError(result, ERROR_INVALID_FILE, "The selected file is not an APK.")
            return
        }
        if (!canInstallPackages()) {
            postError(
                result,
                ERROR_PERMISSION_DENIED,
                "Installing unknown apps is not allowed for this app.",
            )
            return
        }

        when (val session = startSessionInstall(apk, result)) {
            SessionStart.Started -> Unit
            is SessionStart.Failed -> launchFallback(apk, session.cause, result)
        }
    }

    private fun canInstallPackages(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }
        return context.packageManager.canRequestPackageInstalls()
    }

    private fun startSessionInstall(
        apk: File,
        result: MethodChannel.Result,
    ): SessionStart {
        var sessionId: Int? = null
        var session: PackageInstaller.Session? = null
        try {
            val installer = context.packageManager.packageInstaller
            val params =
                PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)

            sessionId = installer.createSession(params)
            session = installer.openSession(sessionId)
            session.openWrite(APK_SESSION_NAME, 0, apk.length()).use { output ->
                apk.inputStream().use { input -> input.copyTo(output) }
                session.fsync(output)
            }

            val pendingIntent = createResultPendingIntent(sessionId)
            pendingInstallResults[sessionId] = result
            session.commit(pendingIntent.intentSender)
            return SessionStart.Started
        } catch (error: Exception) {
            sessionId?.let { pendingInstallResults.remove(it) }
            try {
                session?.abandon()
            } catch (_: Exception) {
                // The session may already be closed.
            }
            return SessionStart.Failed(error)
        } finally {
            try {
                session?.close()
            } catch (_: Exception) {
                // The session may already be closed.
            }
        }
    }

    private fun createResultPendingIntent(sessionId: Int): PendingIntent {
        val intent =
            Intent(context, ApkInstallResultReceiver::class.java)
                .setAction(ACTION_INSTALL_RESULT)
        val mutableFlag =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(
            context,
            sessionId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag,
        )
    }

    private fun launchFallback(
        apk: File,
        sessionCause: Exception,
        result: MethodChannel.Result,
    ) {
        try {
            val uri = sharedUri(apk)
            val intent =
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, APK_MIME_TYPE)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            context.startActivity(intent)
            mainHandler.post { result.success(null) }
        } catch (error: Exception) {
            val message =
                error.message
                    ?: sessionCause.message
                    ?: "Failed to open the package installer."
            postError(result, errorCodeFor(error), message)
        }
    }

    private fun sharedUri(apk: File): Uri {
        val authority = "${context.packageName}.fileprovider"
        return try {
            FileProvider.getUriForFile(context, authority, apk)
        } catch (_: IllegalArgumentException) {
            // The file lives outside the configured provider roots; copy it into the cache.
            val updatesDir = File(context.cacheDir, "updates")
            if (!updatesDir.exists() && !updatesDir.mkdirs()) {
                throw IOException("Could not create the APK cache directory.")
            }
            val cached = File(updatesDir, apk.name)
            apk.copyTo(cached, overwrite = true)
            FileProvider.getUriForFile(context, authority, cached)
        }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    private fun errorCodeFor(error: Throwable): String =
        when (error) {
            is SecurityException -> ERROR_PERMISSION_DENIED
            is FileNotFoundException -> ERROR_FILE_NOT_FOUND
            is IOException -> ERROR_INSTALL_FAILED
            else -> ERROR_INSTALL_FAILED
        }

    private sealed interface SessionStart {
        data object Started : SessionStart

        data class Failed(val cause: Exception) : SessionStart
    }

    companion object {
        const val CHANNEL = "com.iwatman.agentport/installer"

        private const val METHOD_INSTALL_APK = "installApk"
        private const val METHOD_CAN_INSTALL_PACKAGES = "canInstallPackages"

        private const val ACTION_INSTALL_RESULT = "com.iwatman.agentport.INSTALL_RESULT"

        private const val ERROR_PERMISSION_DENIED = "permission_denied"
        private const val ERROR_FILE_NOT_FOUND = "file_not_found"
        private const val ERROR_INVALID_FILE = "invalid_file"
        private const val ERROR_INSTALL_FAILED = "install_failed"

        private const val APK_EXTENSION = ".apk"
        private const val APK_SESSION_NAME = "base.apk"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"

        private val pendingInstallResults = ConcurrentHashMap<Int, MethodChannel.Result>()

        /**
         * Handles the result broadcast produced by a [PackageInstaller] session commit.
         *
         * The broadcast is delivered to [ApkInstallResultReceiver], which forwards it here so the
         * pending Flutter [MethodChannel.Result] can be completed.
         */
        internal fun handleInstallResult(context: Context, intent: Intent) {
            val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
            val result = pendingInstallResults[sessionId] ?: return

            when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
                PackageInstaller.STATUS_SUCCESS -> {
                    if (pendingInstallResults.remove(sessionId, result)) {
                        result.success(null)
                    }
                }

                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    val confirmation = extractConfirmationIntent(intent)
                    if (confirmation == null) {
                        if (pendingInstallResults.remove(sessionId, result)) {
                            result.error(
                                ERROR_INSTALL_FAILED,
                                "The package installer did not provide a confirmation screen.",
                                null,
                            )
                        }
                        return
                    }
                    confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        context.startActivity(confirmation)
                    } catch (error: Exception) {
                        if (pendingInstallResults.remove(sessionId, result)) {
                            result.error(
                                ERROR_INSTALL_FAILED,
                                error.message ?: "Failed to open the package installer.",
                                null,
                            )
                        }
                    }
                }

                else -> {
                    val message =
                        intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                            ?: "The package installer rejected the update."
                    if (pendingInstallResults.remove(sessionId, result)) {
                        result.error(ERROR_INSTALL_FAILED, message, null)
                    }
                }
            }
        }

        @Suppress("DEPRECATION")
        private fun extractConfirmationIntent(intent: Intent): Intent? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
    }
}
