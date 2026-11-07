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

/// A project exposed by `GET /api/project`.
class OpenCodeProject {
  const OpenCodeProject({required this.id, required this.directory, this.vcs});

  final String id;

  /// Absolute project directory on the OpenCode host.
  final String directory;

  /// Version control system, for example `git`, when reported.
  final String? vcs;

  /// The last path segment, used as the display name.
  String get name {
    final normalized = directory.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? directory : segments.last;
  }
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

  /// The event-specific payload, when the server wraps it in `data`.
  Map<String, Object?> get payload {
    final value = data['data'];
    return value is Map ? Map<String, Object?>.from(value) : data;
  }

  String? get sessionId {
    final value = payload['sessionID'] ?? payload['sessionId'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

/// An agent exposed by `GET /api/agent`.
class OpenCodeAgent {
  const OpenCodeAgent({required this.id, required this.name});

  final String id;
  final String name;
}

/// A chat model exposed by `GET /api/model`.
class OpenCodeModel {
  const OpenCodeModel({
    required this.id,
    required this.providerId,
    required this.name,
  });

  final String id;
  final String providerId;
  final String name;

  OpenCodeModelRef get ref => OpenCodeModelRef(id: id, providerId: providerId);
}

/// A model reference accepted by the session model endpoint.
class OpenCodeModelRef {
  const OpenCodeModelRef({
    required this.id,
    required this.providerId,
    this.variant,
  });

  final String id;
  final String providerId;
  final String? variant;

  Map<String, Object?> toJson() => {
    'id': id,
    'providerID': providerId,
    if (variant != null && variant!.isNotEmpty) 'variant': variant,
  };
}

/// A file attached to a user message.
class OpenCodeAttachment {
  const OpenCodeAttachment({
    required this.name,
    required this.mime,
    required this.data,
  });

  final String name;
  final String mime;

  /// Base64-encoded file bytes.
  final String data;

  bool get isImage => mime.toLowerCase().startsWith('image/');
}

/// A single user or assistant message in an OpenCode session.
class OpenCodeMessage {
  const OpenCodeMessage({
    required this.id,
    required this.role,
    required this.text,
    this.reasoning = '',
    this.tools = const [],
    this.attachments = const [],
    this.createdAt,
  });

  final String id;

  /// `user` or `assistant`.
  final String role;

  final String text;
  final String reasoning;
  final List<String> tools;
  final List<OpenCodeAttachment> attachments;
  final DateTime? createdAt;

  bool get isUser => role == 'user';
}
