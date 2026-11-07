import 'dart:convert';

import '../../domain/entities/opencode.dart';
import 'opencode_endpoints.dart';

/// Parses the two payload shapes produced by `opencode pair`:
///
/// * JSON: `{"code":"abc123","urls":["http://192.168.1.10:4096"]}`
/// * Link: `http://192.168.1.10:4096/auth/connect/abc123`
class OpenCodePairingParser {
  const OpenCodePairingParser();

  OpenCodePairing parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload is empty.',
      );
    }

    if (trimmed.startsWith('{')) {
      return _parseJson(trimmed);
    }
    return _parseLink(trimmed);
  }

  OpenCodePairing _parseJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload must be a JSON object.',
      );
    }

    final map = Map<String, Object?>.from(decoded);
    final code = _readCode(map['code']);
    final rawUrls = map['urls'];
    if (rawUrls is! List) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload has no server URLs.',
      );
    }

    final urls = <String>[];
    for (final item in rawUrls) {
      if (item is! String) {
        continue;
      }
      try {
        final normalized = normalizeOpenCodeBaseUrl(item);
        if (!urls.contains(normalized)) {
          urls.add(normalized);
        }
      } on OpenCodeFailure {
        // Ignore unreachable or malformed entries; the payload only needs one
        // usable URL.
      }
    }
    if (urls.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload has no reachable http or https URLs.',
      );
    }

    return OpenCodePairing(code: code, urls: List.unmodifiable(urls));
  }

  OpenCodePairing _parseLink(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing link must be an http or https URL.',
      );
    }

    final segments = uri.pathSegments.toList(growable: false);
    final end = _trimTrailingEmpty(segments);
    var connectIndex = -1;
    for (var index = 0; index + 2 < end; index++) {
      if (segments[index] == 'auth' && segments[index + 1] == 'connect') {
        connectIndex = index;
        break;
      }
    }
    if (connectIndex < 0 || connectIndex + 2 >= end) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing link does not contain an auth/connect code.',
      );
    }
    if (connectIndex + 3 != end) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing link has an unexpected path after the code.',
      );
    }

    final code = _readCode(segments[connectIndex + 2]);
    final prefix = segments.sublist(0, connectIndex);
    final base = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: prefix.isEmpty ? null : '/${prefix.join('/')}',
    );

    return OpenCodePairing(
      code: code,
      urls: List.unmodifiable([base.toString()]),
    );
  }

  String _readCode(Object? value) {
    if (value is! String) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing payload has no code.',
      );
    }
    final code = value.trim();
    if (code.isEmpty || code.contains(RegExp(r'\s'))) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The pairing code is empty or malformed.',
      );
    }
    return code;
  }

  int _trimTrailingEmpty(List<String> segments) {
    var end = segments.length;
    while (end > 0 && segments[end - 1].isEmpty) {
      end--;
    }
    return end;
  }
}
