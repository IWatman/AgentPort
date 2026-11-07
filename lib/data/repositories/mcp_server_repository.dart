import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';
import '../mcp/mcp_client.dart';
import '../mcp/mcp_credentials.dart';

class McpServerRepository {
  McpServerRepository(this._database, this._credentials, {McpClient? client})
    : _client = client ?? McpClient();

  final AppDatabase _database;
  final McpCredentialStore _credentials;
  final McpClient _client;

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

  Future<void> setEnabled(String serverId, bool enabled) async {
    await (_database.update(_database.mcpServerEntries)
          ..where((table) => table.id.equals(serverId)))
        .write(McpServerEntriesCompanion(enabled: Value(enabled)));
  }

  Future<Map<String, String>> headersFor(String serverId) {
    return _credentials.headers(serverId);
  }

  Future<void> saveHeaders(String serverId, Map<String, String> headers) async {
    final cleaned = <String, String>{
      for (final entry in headers.entries)
        if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
          entry.key.trim(): entry.value.trim(),
    };
    await _credentials.saveHeaders(serverId, cleaned);
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
    final headers = await _credentials.headers(serverId);
    final session = await _client.connect(server: server, headers: headers);
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
    final headers = await _credentials.headers(serverId);
    final session = await _client.connect(server: server, headers: headers);
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
