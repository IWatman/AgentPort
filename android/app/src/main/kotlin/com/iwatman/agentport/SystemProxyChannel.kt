package com.iwatman.agentport

import android.content.Context
import android.net.ConnectivityManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes the system HTTP proxy to Dart. Flutter's dart:io client does not
 * read Android proxy settings, so the app installs an HttpOverrides that
 * routes external traffic through the proxy reported here.
 */
class SystemProxyChannel(private val context: Context) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.iwatman.agentport/network"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "getProxy") {
            result.notImplemented()
            return
        }
        result.success(readProxy())
    }

    private fun readProxy(): String? {
        return try {
            val manager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE)
                    as? ConnectivityManager ?: return null
            val proxy = manager.defaultProxy ?: return null
            val host = proxy.host
            val port = proxy.port
            if (host.isNullOrBlank() || port !in 1..65535) return null
            val formattedHost =
                if (host.contains(":") && !host.startsWith("[")) "[$host]"
                else host
            "$formattedHost:$port"
        } catch (_: Exception) {
            null
        }
    }
}
