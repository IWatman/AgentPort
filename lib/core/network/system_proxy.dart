import 'dart:io';

import 'package:flutter/services.dart';

/// Applies the Android system HTTP proxy to Dart's HTTP stack.
///
/// Flutter's `dart:io` client does not consult Android's proxy settings, so
/// traffic bypasses system proxies and VPN helper apps that expose one. The
/// platform channel returns the current static proxy, and the installed
/// [HttpOverrides] routes external HTTP(S) traffic through it while keeping
/// loopback, link-local, and private LAN addresses direct.
class SystemProxy {
  SystemProxy._();

  static const channel = MethodChannel('com.iwatman.agentport/network');

  static String? _current;
  static bool _installed = false;

  /// Reads the current proxy and installs or updates the HTTP overrides.
  ///
  /// Returns the normalized `host:port` value, or null when no static proxy is
  /// configured. Failures are ignored so startup never depends on the channel.
  static Future<String?> apply() async {
    String? proxy;
    try {
      proxy = await channel
          .invokeMethod<String>('getProxy')
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      proxy = null;
    }
    final normalized = normalize(proxy);
    if (normalized != _current || (normalized == null && _installed)) {
      _current = normalized;
      _installed = normalized != null;
      HttpOverrides.global = normalized == null
          ? null
          : _SystemProxyOverrides(normalized);
    }
    return normalized;
  }

  /// Accepts only `host:port` values; rejects PAC URLs and malformed input.
  static String? normalize(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^([A-Za-z0-9._-]+|\[[0-9A-Fa-f:.]+\]):([0-9]{1,5})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    final port = int.tryParse(match.group(2)!);
    if (port == null || port < 1 || port > 65535) return null;
    return '${match.group(1)}:$port';
  }

  /// Keeps loopback, link-local, single-label LAN names, and private ranges
  /// off the proxy so local MCP/OpenCode servers keep working.
  static bool shouldBypass(String host) {
    final value = host.toLowerCase();
    if (value.isEmpty || value == 'localhost' || value.endsWith('.local')) {
      return true;
    }
    final address = InternetAddress.tryParse(value);
    if (address == null) {
      // Single-label names are usually local devices, not public hosts.
      return !value.contains('.');
    }
    if (address.isLoopback || address.isLinkLocal) return true;
    if (address.type == InternetAddressType.IPv4) {
      final parts = value.split('.').map(int.tryParse).toList();
      if (parts.length != 4 || parts.any((part) => part == null)) {
        return false;
      }
      final first = parts[0]!;
      final second = parts[1]!;
      return first == 10 ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168);
    }
    // IPv6 unique local addresses fc00::/7.
    return (address.rawAddress.first & 0xfe) == 0xfc;
  }
}

class _SystemProxyOverrides extends HttpOverrides {
  _SystemProxyOverrides(this.proxy);

  final String proxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = findProxy;
    return client;
  }

  String findProxy(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return 'DIRECT';
    if (SystemProxy.shouldBypass(uri.host)) return 'DIRECT';
    // Fall back to a direct connection when the proxy is unavailable.
    return 'PROXY $proxy; DIRECT';
  }
}
