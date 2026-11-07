package com.iwatman.agentport

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the result of a [android.content.pm.PackageInstaller] session commit.
 *
 * The receiver is declared in the manifest with `android:exported="false"` and is targeted
 * explicitly by the pending intent created in [ApkInstaller].
 */
class ApkInstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ApkInstaller.handleInstallResult(context, intent)
    }
}
