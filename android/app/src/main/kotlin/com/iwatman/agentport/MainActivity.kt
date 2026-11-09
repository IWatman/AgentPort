package com.iwatman.agentport

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ApkInstaller.CHANNEL,
        ).setMethodCallHandler(ApkInstaller(this))
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UpdateDownloadManager.CHANNEL,
        ).setMethodCallHandler(UpdateDownloadManager(this))
    }
}
