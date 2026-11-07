import 'package:http/http.dart' as http;

import '../../domain/entities/opencode.dart';

typedef OpenCodeHttpClientFactory = http.Client Function();

/// Parses and validates an OpenCode server base URL.
///
/// The returned URI always has a trailing slash on its path so that relative
/// API paths can be resolved without dropping an existing path prefix such as
/// `https://host/opencode`.
Uri openCodeBaseUri(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw const OpenCodeFailure(
      OpenCodeFailureKind.invalidPayload,
      detail: 'The OpenCode server URL must be an http or https URL.',
    );
  }

  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final basePath = path.isEmpty ? '/' : '$path/';
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: basePath,
  );
}

/// Normalizes a base URL for storage and display.
///
/// Unlike [openCodeBaseUri], the result has no trailing slash (unless it is a
/// bare host, which is also returned without one).
String normalizeOpenCodeBaseUrl(String raw) {
  final base = openCodeBaseUri(raw);
  var path = base.path;
  if (path == '/') {
    path = '';
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path.isEmpty ? null : path,
  ).toString();
}

/// Resolves [relative] against an OpenCode base URL while preserving any path
/// prefix.
Uri openCodeEndpoint(String baseUrl, String relative) {
  return openCodeBaseUri(baseUrl).resolve(relative);
}

/// Builds the pairing redemption endpoint for [code].
Uri openCodeConnectUri(String baseUrl, String code) {
  final normalizedCode = code.trim();
  if (normalizedCode.isEmpty || normalizedCode.contains(RegExp(r'\s'))) {
    throw const OpenCodeFailure(
      OpenCodeFailureKind.invalidPayload,
      detail: 'Enter a valid OpenCode pairing code.',
    );
  }
  return openCodeEndpoint(
    baseUrl,
    'auth/connect/${Uri.encodeComponent(normalizedCode)}',
  );
}
