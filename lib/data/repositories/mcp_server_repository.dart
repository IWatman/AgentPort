import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';
import '../../domain/entities/mcp_oauth.dart';
import '../mcp/mcp_client.dart';
import '../mcp/mcp_credentials.dart';
import '../mcp/mcp_oauth.dart';

class McpServerRepository {
  McpServerRepository(
    this._database,
    this._credentials, {
    McpClient? client,
    McpOAuthFlow? oauth,
  }) : _client = client ?? McpClient(),
       _oauth = oauth ?? McpOAuthFlow();

  final AppDatabase _database;
  final McpCredentialStore _credentials;
  final McpClient _client;
  final McpOAuthFlow _oauth;

  Future<List<McpServer>> listServers() async {
    final serverRows = await _database.select(_database.mcpServerEntries).get();
    final pluginRows = await _database
        .select(_database.marketplacePluginEntries)
        .get();
    final marketplaceRows = await _database
        .select(_database.marketplaceEntries)
        .get();

    final plugins = {for (final row in pluginRows) row.id: row};
    final marketplaces = {for (final row in marketplaceRows) row.id: row};

    return serverRows
        .map((row) => _toServer(row, plugins, marketplaces))
        .toList(growable: false);
  }

  Future<McpServer?> serverById(String id) async {
    final row = await (_database.select(
      _database.mcpServerEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final pluginRow = row.pluginId == null
        ? null
        : await (_database.select(_database.marketplacePluginEntries)
                ..where((table) => table.id.equals(row.pluginId!)))
              .getSingleOrNull();
    final marketplaceRow = row.marketplaceId == null
        ? null
        : await (_database.select(_database.marketplaceEntries)
                ..where((table) => table.id.equals(row.marketplaceId!)))
              .getSingleOrNull();
    return _toServer(
      row,
      pluginRow == null ? const {} : {pluginRow.id: pluginRow},
      marketplaceRow == null ? const {} : {marketplaceRow.id: marketplaceRow},
    );
  }

  Future<List<McpTool>> toolsFor(String serverId) async {
    final rows =
        await (_database.select(_database.mcpToolEntries)
              ..where((table) => table.serverId.equals(serverId))
              ..orderBy([(table) => OrderingTerm.asc(table.name)]))
            .get();
    return rows.map(_toolFromRow).toList(growable: false);
  }

  Future<Map<String, List<McpTool>>> allTools() async {
    final servers = await listServers();
    final result = <String, List<McpTool>>{};
    for (final server in servers.where((item) => item.enabled)) {
      final tools = await toolsFor(server.id);
      if (tools.isNotEmpty) {
        result[server.id] = tools;
      }
    }
    return result;
  }

  /// Creates or updates a standalone (non-marketplace) MCP server.
  Future<McpServer> saveServer({
    required String id,
    required String name,
    required String url,
    McpTransport transport = McpTransport.http,
    McpAuthType authType = McpAuthType.oauth,
  }) async {
    final existing = await (_database.select(
      _database.mcpServerEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      await _database
          .into(_database.mcpServerEntries)
          .insert(
            McpServerEntriesCompanion.insert(
              id: id,
              name: name,
              url: url,
              transport: transport.storageValue,
              authType: authType.storageValue,
              configHash: url,
              createdAt: now,
            ),
          );
    } else {
      await (_database.update(
        _database.mcpServerEntries,
      )..where((table) => table.id.equals(id))).write(
        McpServerEntriesCompanion(
          name: Value(name),
          url: Value(url),
          transport: Value(transport.storageValue),
          authType: Value(authType.storageValue),
        ),
      );
    }
    final server = await serverById(id);
    if (server == null) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server could not be saved.',
      );
    }
    return server;
  }

  Future<void> setEnabled(String serverId, bool enabled) async {
    await (_database.update(_database.mcpServerEntries)
          ..where((table) => table.id.equals(serverId)))
        .write(McpServerEntriesCompanion(enabled: Value(enabled)));
  }

  Future<Map<String, String>> headersFor(String serverId) {
    return _credentials.headers(serverId);
  }

  Future<bool> hasOAuthToken(String serverId) async {
    return await _credentials.oauthToken(serverId) != null;
  }

  Future<void> clearOAuth(String serverId) async {
    await _credentials.deleteOAuthToken(serverId);
  }

  Future<McpOAuthClientConfig?> oauthClientFor(String serverId) {
    return _credentials.oauthClient(serverId);
  }

  /// Saves a pre-registered OAuth client and invalidates tokens that belong to
  /// a different client configuration.
  Future<void> saveOAuthClient(
    String serverId,
    McpOAuthClientConfig config,
  ) async {
    final existing = await _credentials.oauthClient(serverId);
    final changed =
        existing == null ||
        existing.clientId != config.clientId ||
        existing.clientSecret != config.clientSecret ||
        existing.redirectUri != config.redirectUri ||
        existing.scope != config.scope;
    await _credentials.saveOAuthClient(serverId, config);
    if (changed) {
      await _credentials.deleteOAuthToken(serverId);
    }
  }

  Future<void> clearOAuthClient(String serverId) async {
    await _credentials.deleteOAuthClient(serverId);
    await _credentials.deleteOAuthToken(serverId);
  }

  /// Opens the browser OAuth flow and caches the discovered tools.
  Future<List<McpTool>> authorizeOAuth(String serverId) async {
    final server = await serverById(serverId);
    if (server == null) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server is not installed.',
      );
    }
    final token = await _oauth.authorize(
      resourceUrl: server.url,
      clientConfig: await _credentials.oauthClient(serverId),
    );
    await _credentials.saveOAuthToken(serverId, token);
    return refreshTools(serverId);
  }

  /// Header set used for HTTP requests, including a bearer token when present.
  Future<Map<String, String>> requestHeaders(String serverId) async {
    final headers = await _credentials.headers(serverId);
    final token = await _credentials.oauthToken(serverId);
    if (token == null) {
      return headers;
    }
    final valid = await _validToken(serverId, token);
    return {...headers, 'Authorization': 'Bearer ${valid.accessToken}'};
  }

  Future<McpOAuthToken> _validToken(
    String serverId,
    McpOAuthToken token, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !token.isExpired) {
      return token;
    }
    try {
      final refreshed = await _oauth.refresh(token);
      await _credentials.saveOAuthToken(serverId, refreshed);
      return refreshed;
    } on McpOAuthException catch (error) {
      await _credentials.deleteOAuthToken(serverId);
      throw McpFailure(McpFailureKind.unauthorized, error.message);
    }
  }

  Future<McpSession> _connectWithAuth(McpServer server, String serverId) async {
    var headers = await requestHeaders(serverId);
    try {
      return await _client.connect(server: server, headers: headers);
    } on McpFailure catch (error) {
      if (error.kind != McpFailureKind.unauthorized) {
        rethrow;
      }
      final token = await _credentials.oauthToken(serverId);
      if (token == null) {
        rethrow;
      }
      final refreshed = await _validToken(serverId, token, forceRefresh: true);
      headers = {
        ...await _credentials.headers(serverId),
        'Authorization': 'Bearer ${refreshed.accessToken}',
      };
      return _client.connect(server: server, headers: headers);
    }
  }

  Future<void> saveHeaders(String serverId, Map<String, String> headers) async {
    final cleaned = <String, String>{
      for (final entry in headers.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };
    await _credentials.saveHeaders(serverId, cleaned);
    await _credentials.deleteOAuthToken(serverId);
  }

  Future<void> clearHeaders(String serverId) {
    return _credentials.deleteHeaders(serverId);
  }

  /// Connects to a server, discovers tools, and caches them.
  Future<List<McpTool>> refreshTools(String serverId) async {
    final server = await serverById(serverId);
    if (server == null) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server is not installed.',
      );
    }
    final session = await _connectWithAuth(server, serverId);
    try {
      final discovered = await session.listTools();
      final tools = [
        for (final tool in discovered)
          McpTool(
            serverId: serverId,
            name: tool.name,
            description: tool.description,
            inputSchema: tool.inputSchema,
            needsApproval: tool.needsApproval,
          ),
      ];
      await _cacheTools(serverId, tools);
      return tools;
    } finally {
      session.close();
    }
  }

  Future<McpToolResult> callTool({
    required String serverId,
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    final server = await serverById(serverId);
    if (server == null) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server is not installed.',
      );
    }
    if (!server.enabled) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server is disabled.',
      );
    }
    final session = await _connectWithAuth(server, serverId);
    try {
      return await session.callTool(toolName, arguments);
    } finally {
      session.close();
    }
  }

  Future<void> _cacheTools(String serverId, List<McpTool> tools) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await (_database.delete(
        _database.mcpToolEntries,
      )..where((table) => table.serverId.equals(serverId))).go();
      for (final tool in tools) {
        await _database
            .into(_database.mcpToolEntries)
            .insert(
              McpToolEntriesCompanion.insert(
                id: '$serverId/${tool.name}',
                serverId: serverId,
                name: tool.name,
                description: Value(tool.description),
                schemaJson: jsonEncode(tool.inputSchema),
                needsApproval: Value(tool.needsApproval),
                discoveredAt: now,
              ),
            );
      }
    });
  }

  McpServer _toServer(
    McpServerEntry row,
    Map<String, MarketplacePluginEntry> plugins,
    Map<String, MarketplaceEntry> marketplaces,
  ) {
    final plugin = row.pluginId == null ? null : plugins[row.pluginId];
    final marketplace = row.marketplaceId == null
        ? null
        : marketplaces[row.marketplaceId];
    final headerNames = _decodeStringList(row.headerNamesJson);
    final headerTemplates = _headerTemplatesFor(plugin, row.name);

    return McpServer(
      id: row.id,
      pluginId: row.pluginId,
      marketplaceId: row.marketplaceId,
      name: row.name,
      pluginTitle: plugin?.displayName?.trim().isNotEmpty == true
          ? plugin!.displayName
          : plugin?.name,
      marketplaceName: marketplace?.name,
      url: row.url,
      transport: McpTransport.fromValue(row.transport) ?? McpTransport.http,
      authType: McpAuthType.fromStorage(row.authType),
      headerNames: headerNames,
      headerTemplates: headerTemplates,
      enabled: row.enabled,
      needsReconsent: row.needsReconsent,
    );
  }

  McpTool _toolFromRow(McpToolEntry row) {
    Map<String, Object?> schema = const {};
    try {
      final decoded = jsonDecode(row.schemaJson);
      if (decoded is Map) {
        schema = Map<String, Object?>.from(decoded);
      }
    } on FormatException {
      // Keep an empty schema for corrupt cache rows.
    }
    return McpTool(
      serverId: row.serverId,
      name: row.name,
      description: row.description,
      inputSchema: schema,
      needsApproval: row.needsApproval,
    );
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } on FormatException {
      // Ignore corrupt rows.
    }
    return const [];
  }

  Map<String, String> _headerTemplatesFor(
    MarketplacePluginEntry? plugin,
    String serverName,
  ) {
    final raw = plugin?.mcpConfigJson;
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const {};
      }
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, Object?>.from(item);
        if (map['name'] != serverName) {
          continue;
        }
        final templates = map['headerTemplates'];
        if (templates is! Map) {
          return const {};
        }
        return {
          for (final entry in templates.entries)
            if (entry.key is String && entry.value is String)
              entry.key! as String: entry.value! as String,
        };
      }
    } on FormatException {
      // Ignore corrupt cached plugin metadata.
    }
    return const {};
  }
}

final mcpServerRepositoryProvider = Provider<McpServerRepository>((ref) {
  return McpServerRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(mcpCredentialStoreProvider),
  );
});
