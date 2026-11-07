import 'marketplace.dart';

/// An installed remote MCP server.
class McpServer {
  const McpServer({
    required this.id,
    required this.name,
    required this.url,
    required this.transport,
    required this.authType,
    required this.enabled,
    required this.headerNames,
    required this.headerTemplates,
    this.pluginId,
    this.marketplaceId,
    this.pluginTitle,
    this.marketplaceName,
    this.needsReconsent = false,
  });

  final String id;
  final String? pluginId;
  final String? marketplaceId;
  final String name;
  final String? pluginTitle;
  final String? marketplaceName;
  final String url;
  final McpTransport transport;
  final McpAuthType authType;
  final List<String> headerNames;
  final Map<String, String> headerTemplates;
  final bool enabled;
  final bool needsReconsent;

  String get displayName =>
      pluginTitle?.trim().isNotEmpty == true ? pluginTitle!.trim() : name;

  bool get supportsCurrentTransport => transport == McpTransport.http;

  List<String> get requiredHeaders {
    final names = <String>{...headerNames};
    if (names.isEmpty && authType != McpAuthType.none) {
      names.add('Authorization');
    }
    return names.toList(growable: false)..sort();
  }

  McpServer copyWith({bool? enabled}) {
    return McpServer(
      id: id,
      pluginId: pluginId,
      marketplaceId: marketplaceId,
      name: name,
      pluginTitle: pluginTitle,
      marketplaceName: marketplaceName,
      url: url,
      transport: transport,
      authType: authType,
      headerNames: headerNames,
      headerTemplates: headerTemplates,
      enabled: enabled ?? this.enabled,
      needsReconsent: needsReconsent,
    );
  }
}

/// A tool exposed by an MCP server.
class McpTool {
  const McpTool({
    required this.serverId,
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.needsApproval,
  });

  final String serverId;
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final bool needsApproval;

  String get qualifiedName => 'mcp__${serverId.replaceAll('/', '_')}__$name';
}

enum McpConnectionStatus { disconnected, checking, connected, needsAuth, error }

class McpToolResult {
  const McpToolResult({required this.content, this.isError = false});

  final String content;
  final bool isError;
}

enum McpFailureKind {
  unsupportedTransport,
  network,
  timeout,
  unauthorized,
  protocol,
  invalidResponse,
  toolError,
}

class McpFailure implements Exception {
  const McpFailure(this.kind, [this.details]);

  final McpFailureKind kind;
  final String? details;

  @override
  String toString() => details == null ? kind.name : '${kind.name}: $details';
}

/// Conservative read-only heuristic used until per-tool approvals are set by
/// the user. Unknown tools require approval.
bool mcpToolNeedsApproval(String name, String description) {
  final text = '$name $description'.toLowerCase();
  const writeWords = [
    'create',
    'delete',
    'execute',
    'modify',
    'post',
    'put',
    'remove',
    'run',
    'send',
    'shell',
    'update',
    'write',
  ];
  if (writeWords.any(text.contains)) {
    return true;
  }
  const readWords = [
    'describe',
    'fetch',
    'find',
    'get',
    'list',
    'read',
    'search',
  ];
  return !readWords.any(text.contains);
}
