/// A parsed OpenCode pairing payload.
///
/// The pair code is single-use and expires after five minutes. The URLs are
/// reachable server base URLs, in the order advertised by the server.
class OpenCodePairing {
  const OpenCodePairing({required this.code, required this.urls})
    : assert(code != ''),
      assert(urls.length > 0);

  final String code;
  final List<String> urls;

  String get primaryUrl => urls.first;
}

/// A saved OpenCode server connection.
///
/// The access token is kept in secure storage; only its reference is stored in
/// this model.
class OpenCodeConnection {
  const OpenCodeConnection({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.username = 'opencode',
    required this.tokenRef,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String username;
  final String tokenRef;
  final DateTime? lastSeen;
}

/// A session exposed by an OpenCode server.
class OpenCodeSession {
  const OpenCodeSession({
    required this.id,
    required this.title,
    this.project,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? project;
  final DateTime? updatedAt;
}

/// Server information returned by `GET /api/info`.
class OpenCodeInfo {
  const OpenCodeInfo({
    required this.version,
    this.urls = const [],
    this.capabilities = const {},
  });

  final String version;
  final List<String> urls;
  final Map<String, Object?> capabilities;
}

enum OpenCodeFailureKind {
  invalidPayload,
  network,
  timeout,
  unauthorized,
  unsupportedVersion,
  server,
  invalidResponse,
}

/// A user-presentable OpenCode failure.
class OpenCodeFailure implements Exception {
  const OpenCodeFailure(this.kind, {this.detail, this.statusCode});

  final OpenCodeFailureKind kind;
  final String? detail;
  final int? statusCode;

  @override
  String toString() {
    return detail == null ? kind.name : '${kind.name}: $detail';
  }
}

/// A single server-sent event from `GET /api/event`.
class OpenCodeEvent {
  const OpenCodeEvent({required this.type, required this.data, this.id});

  /// The SSE `id` field, when the server sent one.
  final String? id;

  /// The SSE `event` field, falling back to the JSON `type` value.
  final String type;

  /// The decoded JSON object carried by the event.
  final Map<String, Object?> data;
}
