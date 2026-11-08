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

/// A slash command exposed by `GET /api/command`.
class OpenCodeCommand {
  const OpenCodeCommand({required this.name, this.description = ''});

  final String name;
  final String description;

  String get displayName => '/$name';
}

/// A project file returned by the filesystem search endpoint.
class OpenCodeFileEntry {
  const OpenCodeFileEntry({required this.path, this.isDirectory = false});

  final String path;
  final bool isDirectory;
}

/// A session exposed by an OpenCode server.
class OpenCodeSession {
  const OpenCodeSession({
    required this.id,
    required this.title,
    this.parentId,
    this.project,
    this.directory,
    this.createdAt,
    this.updatedAt,
    this.cost,
    this.tokensInput,
    this.tokensOutput,
    this.tokensReasoning,
    this.tokensCacheRead,
    this.tokensCacheWrite,
    this.agentId,
    this.modelId,
    this.modelProviderId,
    this.modelVariant,
  });

  final String id;
  final String title;
  final String? parentId;
  final String? project;

  /// Absolute project directory reported by the server.
  final String? directory;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? cost;
  final int? tokensInput;
  final int? tokensOutput;
  final int? tokensReasoning;
  final int? tokensCacheRead;
  final int? tokensCacheWrite;
  final String? agentId;
  final String? modelId;
  final String? modelProviderId;
  final String? modelVariant;

  int get tokensTotal =>
      (tokensInput ?? 0) +
      (tokensOutput ?? 0) +
      (tokensReasoning ?? 0) +
      (tokensCacheRead ?? 0) +
      (tokensCacheWrite ?? 0);

  OpenCodeSession copyWith({String? title}) {
    return OpenCodeSession(
      id: id,
      title: title ?? this.title,
      parentId: parentId,
      project: project,
      directory: directory,
      createdAt: createdAt,
      updatedAt: updatedAt,
      cost: cost,
      tokensInput: tokensInput,
      tokensOutput: tokensOutput,
      tokensReasoning: tokensReasoning,
      tokensCacheRead: tokensCacheRead,
      tokensCacheWrite: tokensCacheWrite,
      agentId: agentId,
      modelId: modelId,
      modelProviderId: modelProviderId,
      modelVariant: modelVariant,
    );
  }
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
    this.variants = const [],
    this.contextLimit,
    this.outputLimit,
  });

  final String id;
  final String providerId;
  final String name;

  /// Optional variant IDs such as `max`, `high`, or `fast`.
  final List<String> variants;

  /// Maximum context window reported by the server, when available.
  final int? contextLimit;

  /// Maximum output tokens reported by the server, when available.
  final int? outputLimit;

  OpenCodeModelRef get ref => OpenCodeModelRef(id: id, providerId: providerId);
}

/// An MCP server configured in the OpenCode host.
class OpenCodeMcpServer {
  const OpenCodeMcpServer({
    required this.name,
    required this.status,
    this.title,
    this.error,
  });

  final String name;
  final String status;
  final String? title;
  final String? error;

  String get displayName =>
      title?.trim().isNotEmpty == true ? title!.trim() : name;

  bool get isConnected => status == 'connected';
  bool get needsAuth => status == 'needs-auth';
  bool get hasFailed => status == 'failed';
}

/// A plugin loaded by the OpenCode host.
class OpenCodePlugin {
  const OpenCodePlugin({
    required this.id,
    required this.sourceType,
    required this.status,
    this.sourceLabel,
    this.version,
    this.error,
  });

  final String id;
  final String sourceType;
  final String status;
  final String? sourceLabel;
  final String? version;
  final String? error;

  bool get isBuiltin => sourceType == 'builtin';
  bool get hasFailed => status == 'failed';

  String get displayName {
    final label = sourceLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return id;
  }
}

/// A skill exposed by the OpenCode host.
class OpenCodeSkill {
  const OpenCodeSkill({
    required this.id,
    required this.name,
    required this.description,
    this.path,
  });

  final String id;
  final String name;
  final String description;
  final String? path;
}

/// System context returned by `GET /api/session/{id}/context`.
class OpenCodeSessionContext {
  const OpenCodeSessionContext({
    required this.systemPrompts,
    required this.messageCount,
  });

  final List<String> systemPrompts;
  final int messageCount;
}

/// A loaded transcript and the system prompts found among its messages.
class OpenCodeTranscript {
  const OpenCodeTranscript({
    required this.messages,
    this.systemPrompts = const [],
  });

  final List<OpenCodeMessage> messages;
  final List<String> systemPrompts;
}

/// A project registered by `GET /api/location`.
class OpenCodeProjectRegistration {
  const OpenCodeProjectRegistration({
    required this.project,
    required this.directory,
  });

  final OpenCodeProject project;

  /// Canonical location directory reported by the server.
  final String directory;
}

/// A directory returned by the OpenCode filesystem browser.
class OpenCodeDirectoryEntry {
  const OpenCodeDirectoryEntry({required this.path, required this.name});

  /// Absolute path on the OpenCode host.
  final String path;

  /// Last path segment shown in the picker.
  final String name;
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
    this.tokensInput,
    this.tokensOutput,
    this.tokensReasoning,
    this.tokensCacheRead,
    this.tokensCacheWrite,
  });

  final String id;

  /// `user` or `assistant`.
  final String role;

  final String text;
  final String reasoning;
  final List<String> tools;
  final List<OpenCodeAttachment> attachments;
  final DateTime? createdAt;

  /// Token usage reported for this assistant message.
  final int? tokensInput;
  final int? tokensOutput;
  final int? tokensReasoning;
  final int? tokensCacheRead;
  final int? tokensCacheWrite;

  /// Tokens occupied by the model context for this turn: fresh input plus
  /// cache reads. This is what OpenCode Web shows as the current context size.
  int? get contextTokens {
    final input = tokensInput;
    final cacheRead = tokensCacheRead;
    if (input == null && cacheRead == null) {
      return null;
    }
    return (input ?? 0) + (cacheRead ?? 0);
  }

  bool get isUser => role == 'user';
}
