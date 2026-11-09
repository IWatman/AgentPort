package com.iwatman.agentport

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridges APK downloads to Android's DownloadManager.
 *
 * DownloadManager is a system service, so the transfer continues while the
 * screen is off or the app is in the background. The file is written to the
 * app-specific external Downloads directory, which does not require storage
 * permissions on modern Android versions.
 */
class UpdateDownloadManager(context: Context) : MethodChannel.MethodCallHandler {
    private val context = context.applicationContext
    private val downloadManager =
        context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_ENQUEUE -> enqueue(call, result)
            METHOD_QUERY -> query(call, result)
            METHOD_REMOVE -> remove(call, result)
            else -> result.notImplemented()
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val fileName = call.argument<String>("fileName")
        val title = call.argument<String>("title") ?: "AgentPort update"
        val description = call.argument<String>("description") ?: "Downloading update"

        if (url == null || url.isBlank() || !url.startsWith("https://", ignoreCase = true)) {
            result.error(ERROR_INVALID_REQUEST, "The update URL must use HTTPS.", null)
            return
        }
        if (fileName == null || fileName.isBlank() || !isSafeFileName(fileName)) {
            result.error(ERROR_INVALID_REQUEST, "The update file name is invalid.", null)
            return
        }

        val directory = downloadsDirectory()
        if (directory == null) {
            result.error(ERROR_ENQUEUE_FAILED, "External storage is not available.", null)
            return
        }
        if (!directory.exists() && !directory.mkdirs()) {
            result.error(ERROR_ENQUEUE_FAILED, "Could not create the download directory.", null)
            return
        }

        try {
            // Keep only the APK for the current update.
            directory.listFiles()?.forEach { file ->
                if (file.isFile &&
                    (file.name.endsWith(".apk") || file.name.endsWith(".apk.part"))
                ) {
                    file.delete()
                }
            }
        } catch (error: Exception) {
            result.error(
                ERROR_ENQUEUE_FAILED,
                error.message ?: "Could not remove the previous update file.",
                null,
            )
            return
        }

        try {
            val request =
                DownloadManager.Request(Uri.parse(url)).apply {
                    setTitle(title)
                    setDescription(description)
                    setMimeType(APK_MIME_TYPE)
                    setNotificationVisibility(
                        DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                    )
                    setAllowedOverMetered(true)
                    setAllowedOverRoaming(false)
                    setDestinationInExternalFilesDir(
                        context,
                        Environment.DIRECTORY_DOWNLOADS,
                        fileName,
                    )
                }
            val id = downloadManager.enqueue(request)
            result.success(
                mapOf(
                    "id" to id,
                    "path" to File(directory, fileName).absolutePath,
                ),
            )
        } catch (error: Exception) {
            result.error(
                ERROR_ENQUEUE_FAILED,
                error.message ?: "Could not start the update download.",
                null,
            )
        }
    }

    private fun query(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        if (id == null) {
            result.error(ERROR_INVALID_REQUEST, "The download id is missing.", null)
            return
        }
        val fileName = call.argument<String>("fileName")
        val directory = downloadsDirectory()
        val expectedFile =
            if (directory != null && fileName != null && isSafeFileName(fileName)) {
                File(directory, fileName)
            } else {
                null
            }

        try {
            downloadManager.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
                if (!cursor.moveToFirst()) {
                    if (expectedFile != null && expectedFile.exists()) {
                        result.success(successResult(expectedFile))
                    } else {
                        result.success(mapOf("status" to STATUS_UNKNOWN))
                    }
                    return
                }

                val status =
                    cursor.getInt(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
                    )
                val downloaded =
                    cursor.getLong(
                        cursor.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                        ),
                    )
                val total =
                    cursor.getLong(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                    )
                val reason =
                    cursor.getInt(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
                    )

                var path: String? = null
                if (status == DownloadManager.STATUS_SUCCESSFUL) {
                    if (expectedFile != null && expectedFile.exists()) {
                        path = expectedFile.absolutePath
                    } else {
                        val localUri =
                            cursor.getString(
                                cursor.getColumnIndexOrThrow(
                                    DownloadManager.COLUMN_LOCAL_URI,
                                ),
                            )
                        if (!localUri.isNullOrBlank()) {
                            val uri = Uri.parse(localUri)
                            if (uri.scheme == "file") {
                                path = uri.path
                            }
                        }
                    }
                    if (path == null) {
                        result.success(
                            mapOf(
                                "status" to STATUS_FAILED,
                                "downloaded" to downloaded,
                                "total" to total,
                                "reason" to reason,
                                "path" to null,
                            ),
                        )
                        return
                    }
                }

                result.success(
                    mapOf(
                        "status" to statusName(status),
                        "downloaded" to downloaded,
                        "total" to total,
                        "reason" to reason,
                        "path" to path,
                    ),
                )
            }
        } catch (error: Exception) {
            result.error(
                ERROR_QUERY_FAILED,
                error.message ?: "Could not query the update download.",
                null,
            )
        }
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        if (id == null) {
            result.error(ERROR_INVALID_REQUEST, "The download id is missing.", null)
            return
        }
        try {
            downloadManager.remove(id)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                ERROR_QUERY_FAILED,
                error.message ?: "Could not remove the update download.",
                null,
            )
        }
    }

    private fun successResult(file: File): Map<String, Any?> =
        mapOf(
            "status" to STATUS_SUCCESSFUL,
            "downloaded" to file.length(),
            "total" to file.length(),
            "reason" to 0,
            "path" to file.absolutePath,
        )

    private fun downloadsDirectory(): File? =
        context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)

    private fun isSafeFileName(name: String): Boolean =
        name.isNotBlank() &&
            name != "." &&
            name != ".." &&
            !name.contains('/') &&
            !name.contains('\\')

    private fun statusName(status: Int): String =
        when (status) {
            DownloadManager.STATUS_PENDING -> "pending"
            DownloadManager.STATUS_RUNNING -> "running"
            DownloadManager.STATUS_PAUSED -> "paused"
            DownloadManager.STATUS_SUCCESSFUL -> "successful"
            DownloadManager.STATUS_FAILED -> "failed"
            else -> "unknown"
        }

    companion object {
        const val CHANNEL = "com.iwatman.agentport/downloader"

        private const val METHOD_ENQUEUE = "enqueue"
        private const val METHOD_QUERY = "query"
        private const val METHOD_REMOVE = "remove"

        private const val STATUS_UNKNOWN = "unknown"
        private const val STATUS_SUCCESSFUL = "successful"
        private const val STATUS_FAILED = "failed"

        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"

        private const val ERROR_INVALID_REQUEST = "invalid_request"
        private const val ERROR_ENQUEUE_FAILED = "enqueue_failed"
        private const val ERROR_QUERY_FAILED = "query_failed"
    }
}
