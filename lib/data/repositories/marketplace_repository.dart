import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/marketplace.dart';
import '../marketplace/marketplace_api.dart';
import '../marketplace/marketplace_manifest_parser.dart';
import '../marketplace/marketplace_sources.dart';

class MarketplaceRepository {
  MarketplaceRepository(
    this._database,
    this._api, {
    Uuid? uuid,
    MarketplaceSourceResolver? sourceResolver,
  }) : _uuid = uuid ?? const Uuid(),
       _sources = sourceResolver ?? const MarketplaceSourceResolver();

  final AppDatabase _database;
  final MarketplaceApi _api;
  final Uuid _uuid;
  final MarketplaceSourceResolver _sources;

  Future<void> ensureBuiltInMarketplace() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (_database.select(_database.marketplaceEntries)
              ..where((table) => table.id.equals(kOfficialMarketplaceId)))
            .getSingleOrNull();

    if (existing != null) {
      // Keep user-local state (etag, last sync) but reconcile the immutable
      // built-in metadata when the app ships a newer definition.
      if (existing.name != 'Claude Plugins Official' ||
          existing.sourceUrl != kOfficialMarketplaceSource ||
          existing.manifestUrl != kOfficialMarketplaceManifest) {
        await (_database.update(
          _database.marketplaceEntries,
        )..where((table) => table.id.equals(kOfficialMarketplaceId))).write(
          const MarketplaceEntriesCompanion(
            name: Value('Claude Plugins Official'),
            description: Value(
              'The official Anthropic directory of Claude Code plugins and MCP integrations.',
            ),
            sourceUrl: Value(kOfficialMarketplaceSource),
            manifestUrl: Value(kOfficialMarketplaceManifest),
            builtIn: Value(true),
          ),
        );
      }
      return;
    }

    await _database
        .into(_database.marketplaceEntries)
        .insert(
          MarketplaceEntriesCompanion.insert(
            id: kOfficialMarketplaceId,
            name: 'Claude Plugins Official',
            description: const Value(
              'The official Anthropic directory of Claude Code plugins and MCP integrations.',
            ),
            sourceUrl: kOfficialMarketplaceSource,
            manifestUrl: kOfficialMarketplaceManifest,
            builtIn: const Value(true),
            createdAt: now,
          ),
        );
  }

  Future<MarketplaceCatalog> loadCatalog() async {
    final marketplaceRows = await _database
        .select(_database.marketplaceEntries)
        .get();
    final pluginRows = await _database
        .select(_database.marketplacePluginEntries)
        .get();
    final marketplaces = marketplaceRows
        .map(_toMarketplace)
        .toList(growable: false);
    final byId = {for (final item in marketplaces) item.id: item};
    final plugins = <MarketplacePlugin>[];
    for (final row in pluginRows) {
      final marketplace = byId[row.marketplaceId];
      if (marketplace == null) {
        continue;
      }
      plugins.add(_toPlugin(row, marketplace));
    }
    return MarketplaceCatalog(marketplaces: marketplaces, plugins: plugins);
  }

  Future<List<Marketplace>> listMarketplaces() async {
    final rows = await _database.select(_database.marketplaceEntries).get();
    return rows.map(_toMarketplace).toList(growable: false);
  }

  Future<Marketplace?> marketplaceById(String id) async {
    final row = await (_database.select(
      _database.marketplaceEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toMarketplace(row);
  }

  Future<MarketplacePlugin?> pluginById(String id) async {
    final row = await (_database.select(
      _database.marketplacePluginEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final marketplace = await marketplaceById(row.marketplaceId);
    return marketplace == null ? null : _toPlugin(row, marketplace);
  }

  /// Adds a marketplace from `owner/repo`, a GitHub URL, or a manifest URL.
  Future<Marketplace> addMarketplace(String input) async {
    final reference = _sources.parseInput(input);
    if (reference == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.invalidInput,
        'Use owner/repo, a GitHub URL, or a manifest.json URL.',
      );
    }

    final normalizedSource = reference.sourceUrl.replaceAll(
      RegExp(r'\.git$'),
      '',
    );
    if (normalizedSource == kOfficialMarketplaceSource) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.duplicate,
        'The official marketplace is already built in.',
      );
    }

    final remote = await _api.fetchManifest(reference);
    if (remote == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.invalidManifest,
        'The marketplace manifest did not return content.',
      );
    }

    final duplicate =
        await (_database.select(_database.marketplaceEntries)
              ..where((table) => table.manifestUrl.equals(remote.manifestUrl)))
            .getSingleOrNull();
    if (duplicate != null) {
      throw MarketplaceFailure(
        MarketplaceFailureKind.duplicate,
        duplicate.name,
      );
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction(() async {
      await _database
          .into(_database.marketplaceEntries)
          .insert(
            MarketplaceEntriesCompanion.insert(
              id: id,
              name: remote.manifest.name,
              description: Value(remote.manifest.description),
              sourceUrl: normalizedSource,
              manifestUrl: remote.manifestUrl,
              etag: Value(remote.etag),
              lastSyncedAt: Value(now),
              createdAt: now,
            ),
          );
      await _replaceCatalogPlugins(
        marketplaceId: id,
        plugins: remote.manifest.plugins,
        refreshedAt: now,
      );
    });

    final created = await marketplaceById(id);
    if (created == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.storage,
        'The marketplace could not be saved.',
      );
    }
    return created;
  }

  /// Refreshes a marketplace and keeps installation state.
  Future<void> refreshMarketplace(String id) async {
    final marketplace = await marketplaceById(id);
    if (marketplace == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Marketplace not found.',
      );
    }

    final resolved = _sources.parseInput(marketplace.sourceUrl);
    final candidates = <String>[
      marketplace.manifestUrl,
      ...?resolved?.manifestUrls.where((url) => url != marketplace.manifestUrl),
    ];
    final reference = MarketplaceReference(
      sourceUrl: marketplace.sourceUrl,
      manifestUrls: candidates,
    );

    try {
      final remote = await _api.fetchManifest(
        reference,
        etag: marketplace.etag,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (remote == null) {
        await (_database.update(
          _database.marketplaceEntries,
        )..where((table) => table.id.equals(id))).write(
          MarketplaceEntriesCompanion(
            lastSyncedAt: Value(now),
            lastError: const Value(null),
          ),
        );
        return;
      }

      await _database.transaction(() async {
        await (_database.update(
          _database.marketplaceEntries,
        )..where((table) => table.id.equals(id))).write(
          MarketplaceEntriesCompanion(
            name: Value(
              marketplace.builtIn
                  ? 'Claude Plugins Official'
                  : remote.manifest.name,
            ),
            description: Value(remote.manifest.description),
            manifestUrl: Value(remote.manifestUrl),
            etag: Value(remote.etag),
            lastSyncedAt: Value(now),
            lastError: const Value(null),
          ),
        );
        await _replaceCatalogPlugins(
          marketplaceId: id,
          plugins: remote.manifest.plugins,
          refreshedAt: now,
        );
      });
    } catch (error) {
      final message = switch (error) {
        MarketplaceFailure failure => failure.kind.name,
        _ => 'Unexpected error',
      };
      await (_database.update(_database.marketplaceEntries)
            ..where((table) => table.id.equals(id)))
          .write(MarketplaceEntriesCompanion(lastError: Value(message)));
      rethrow;
    }
  }

  Future<void> deleteMarketplace(String id) async {
    final marketplace = await marketplaceById(id);
    if (marketplace == null) {
      return;
    }
    if (marketplace.builtIn) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.unsupportedSource,
        'The built-in marketplace cannot be deleted.',
      );
    }
    await (_database.delete(
      _database.marketplaceEntries,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<int> installedPluginCount(String marketplaceId) async {
    final count = _database.marketplacePluginEntries.id.count();
    final query = _database.selectOnly(_database.marketplacePluginEntries)
      ..addColumns([count])
      ..where(
        _database.marketplacePluginEntries.marketplaceId.equals(marketplaceId) &
            _database.marketplacePluginEntries.installed.equals(true),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Fetches `.mcp.json` for a plugin and caches the result.
  Future<MarketplacePlugin> probePlugin(String pluginId) async {
    final plugin = await pluginById(pluginId);
    if (plugin == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Plugin not found.',
      );
    }
    final marketplace = await marketplaceById(plugin.marketplaceId);
    if (marketplace == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Marketplace not found.',
      );
    }

    final metadata = await _api.fetchMcpMetadata(
      marketplace: marketplace,
      source: plugin.source,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final isError = metadata.status == PluginMcpStatus.error;
    final configJson = metadata.servers.isEmpty
        ? null
        : jsonEncode(
            metadata.servers.map((server) => server.toJson()).toList(),
          );

    await _database.transaction(() async {
      if (plugin.installed && !isError) {
        final oldHash = _api.configHash(plugin.installedServers);
        final newHash = _api.configHash(metadata.servers);
        if (oldHash != newHash) {
          await (_database.update(
            _database.marketplacePluginEntries,
          )..where((table) => table.id.equals(pluginId))).write(
            const MarketplacePluginEntriesCompanion(
              needsReconsent: Value(true),
              enabled: Value(false),
            ),
          );
          await (_database.update(
            _database.mcpServerEntries,
          )..where((table) => table.pluginId.equals(pluginId))).write(
            const McpServerEntriesCompanion(
              enabled: Value(false),
              needsReconsent: Value(true),
            ),
          );
        }
      }

      await (_database.update(
        _database.marketplacePluginEntries,
      )..where((table) => table.id.equals(pluginId))).write(
        isError
            ? MarketplacePluginEntriesCompanion(
                mcpStatus: Value(metadata.status.storageValue),
                mcpCheckedAt: Value(now),
                lastError: Value(metadata.error),
              )
            : MarketplacePluginEntriesCompanion(
                mcpStatus: Value(metadata.status.storageValue),
                mcpConfigJson: Value(configJson),
                mcpCheckedAt: Value(now),
                lastError: const Value(null),
              ),
      );
    });

    final updated = await pluginById(pluginId);
    if (updated == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.storage,
        'The plugin could not be reloaded.',
      );
    }
    return updated;
  }

  /// Installs remote MCP servers declared by a plugin.
  Future<MarketplacePlugin> installPlugin(String pluginId) async {
    final plugin = await probePlugin(pluginId);

    if (plugin.mcpStatus == PluginMcpStatus.error) {
      throw MarketplaceFailure(
        MarketplaceFailureKind.network,
        plugin.lastError,
      );
    }
    if (plugin.servers.isEmpty) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.noRemoteMcp,
        'This plugin has no remote MCP servers supported on Android.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final configJson = jsonEncode(
      plugin.servers.map((server) => server.toJson()).toList(),
    );

    await _database.transaction(() async {
      await _replaceServerRows(
        pluginId: pluginId,
        marketplaceId: plugin.marketplaceId,
        servers: plugin.servers,
        now: now,
      );

      await (_database.update(
        _database.marketplacePluginEntries,
      )..where((table) => table.id.equals(pluginId))).write(
        MarketplacePluginEntriesCompanion(
          installed: const Value(true),
          enabled: const Value(true),
          installedConfigJson: Value(configJson),
          needsReconsent: const Value(false),
          lastError: const Value(null),
        ),
      );
    });

    final updated = await pluginById(pluginId);
    if (updated == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.storage,
        'The plugin could not be reloaded.',
      );
    }
    return updated;
  }

  /// Accepts a changed MCP configuration and re-enables the plugin.
  Future<MarketplacePlugin> acceptPluginConfig(String pluginId) async {
    final plugin = await pluginById(pluginId);
    if (plugin == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Plugin not found.',
      );
    }
    if (!plugin.installed) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'The plugin is not installed.',
      );
    }
    if (plugin.servers.isEmpty) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.noRemoteMcp,
        'This plugin has no remote MCP servers supported on Android.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final configJson = jsonEncode(
      plugin.servers.map((server) => server.toJson()).toList(),
    );

    await _database.transaction(() async {
      await _replaceServerRows(
        pluginId: pluginId,
        marketplaceId: plugin.marketplaceId,
        servers: plugin.servers,
        now: now,
      );
      await (_database.update(
        _database.marketplacePluginEntries,
      )..where((table) => table.id.equals(pluginId))).write(
        MarketplacePluginEntriesCompanion(
          installed: const Value(true),
          enabled: const Value(true),
          installedConfigJson: Value(configJson),
          needsReconsent: const Value(false),
          lastError: const Value(null),
        ),
      );
    });

    final updated = await pluginById(pluginId);
    if (updated == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.storage,
        'The plugin could not be reloaded.',
      );
    }
    return updated;
  }

  Future<MarketplacePlugin> uninstallPlugin(String pluginId) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.mcpServerEntries,
      )..where((table) => table.pluginId.equals(pluginId))).go();
      await (_database.update(
        _database.marketplacePluginEntries,
      )..where((table) => table.id.equals(pluginId))).write(
        const MarketplacePluginEntriesCompanion(
          installed: Value(false),
          enabled: Value(true),
          installedConfigJson: Value(null),
          mcpConfigJson: Value(null),
          mcpCheckedAt: Value(null),
          needsReconsent: Value(false),
          lastError: Value(null),
        ),
      );
    });
    final updated = await pluginById(pluginId);
    if (updated == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Plugin not found.',
      );
    }
    return updated;
  }

  Future<MarketplacePlugin> setPluginEnabled(
    String pluginId,
    bool enabled,
  ) async {
    final plugin = await pluginById(pluginId);
    if (plugin == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Plugin not found.',
      );
    }
    if (enabled && plugin.needsReconsent) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.needsReconsent,
        'Review the new MCP configuration before enabling this plugin.',
      );
    }
    await _database.transaction(() async {
      await (_database.update(_database.marketplacePluginEntries)
            ..where((table) => table.id.equals(pluginId)))
          .write(MarketplacePluginEntriesCompanion(enabled: Value(enabled)));
      await (_database.update(_database.mcpServerEntries)
            ..where((table) => table.pluginId.equals(pluginId)))
          .write(McpServerEntriesCompanion(enabled: Value(enabled)));
    });
    final updated = await pluginById(pluginId);
    if (updated == null) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.notFound,
        'Plugin not found.',
      );
    }
    return updated;
  }

  Future<void> _replaceServerRows({
    required String pluginId,
    required String marketplaceId,
    required List<McpServerConfig> servers,
    required int now,
  }) async {
    await (_database.delete(
      _database.mcpServerEntries,
    )..where((table) => table.pluginId.equals(pluginId))).go();

    for (final server in servers) {
      await _database
          .into(_database.mcpServerEntries)
          .insert(
            McpServerEntriesCompanion.insert(
              id: '$pluginId/${server.name}',
              pluginId: Value(pluginId),
              marketplaceId: Value(marketplaceId),
              name: server.name,
              url: server.url,
              transport: server.transport.storageValue,
              authType: server.authType.storageValue,
              headerNamesJson: server.headerNames.isEmpty
                  ? const Value.absent()
                  : Value(jsonEncode(server.headerNames)),
              configHash: _api.configHash([server]),
              createdAt: now,
            ),
          );
    }
  }

  Future<void> _replaceCatalogPlugins({
    required String marketplaceId,
    required List<ParsedMarketplacePlugin> plugins,
    required int refreshedAt,
  }) async {
    final existingRows = await (_database.select(
      _database.marketplacePluginEntries,
    )..where((table) => table.marketplaceId.equals(marketplaceId))).get();
    final existingByName = {for (final row in existingRows) row.name: row};
    final seenNames = <String>{};

    for (final plugin in plugins) {
      seenNames.add(plugin.name);
      final id = pluginIdFor(marketplaceId, plugin.name);
      final existing = existingByName[plugin.name];
      if (existing == null) {
        await _database
            .into(_database.marketplacePluginEntries)
            .insert(
              MarketplacePluginEntriesCompanion.insert(
                id: id,
                marketplaceId: marketplaceId,
                name: plugin.name,
                displayName: Value(plugin.displayName),
                description: Value(plugin.description),
                author: Value(plugin.author),
                category: Value(plugin.category),
                homepage: Value(plugin.homepage),
                version: Value(plugin.version),
                sourceJson: plugin.source.rawJson,
                sourceKind: plugin.source.kind.storageValue,
                sourceUrl: Value(plugin.source.url),
                sourcePath: Value(plugin.source.path),
                sourceRef: Value(plugin.source.ref),
                sourceSha: Value(plugin.source.sha),
                lastSeenAt: refreshedAt,
                createdAt: refreshedAt,
              ),
            );
      } else {
        final sourceChanged =
            existing.sourceJson != plugin.source.rawJson ||
            existing.sourceSha != plugin.source.sha;
        await (_database.update(
          _database.marketplacePluginEntries,
        )..where((table) => table.id.equals(id))).write(
          MarketplacePluginEntriesCompanion(
            displayName: Value(plugin.displayName),
            description: Value(plugin.description),
            author: Value(plugin.author),
            category: Value(plugin.category),
            homepage: Value(plugin.homepage),
            version: Value(plugin.version),
            sourceJson: Value(plugin.source.rawJson),
            sourceKind: Value(plugin.source.kind.storageValue),
            sourceUrl: Value(plugin.source.url),
            sourcePath: Value(plugin.source.path),
            sourceRef: Value(plugin.source.ref),
            sourceSha: Value(plugin.source.sha),
            lastSeenAt: Value(refreshedAt),
            mcpCheckedAt: sourceChanged
                ? const Value(null)
                : const Value.absent(),
            mcpConfigJson: sourceChanged
                ? const Value(null)
                : const Value.absent(),
            needsReconsent: sourceChanged && existing.installed
                ? const Value(true)
                : const Value.absent(),
            enabled: sourceChanged && existing.installed
                ? const Value(false)
                : const Value.absent(),
          ),
        );
      }
    }

    for (final existing in existingRows) {
      if (existing.installed || seenNames.contains(existing.name)) {
        continue;
      }
      await (_database.delete(
        _database.marketplacePluginEntries,
      )..where((table) => table.id.equals(existing.id))).go();
    }
  }

  String pluginIdFor(String marketplaceId, String pluginName) {
    return '$marketplaceId/$pluginName';
  }

  Marketplace _toMarketplace(MarketplaceEntry row) {
    return Marketplace(
      id: row.id,
      name: row.name,
      description: row.description,
      sourceUrl: row.sourceUrl,
      manifestUrl: row.manifestUrl,
      builtIn: row.builtIn,
      enabled: row.enabled,
      lastSyncedAt: _date(row.lastSyncedAt),
      lastError: row.lastError,
      etag: row.etag,
      createdAt: _date(row.createdAt) ?? DateTime.now(),
    );
  }

  MarketplacePlugin _toPlugin(
    MarketplacePluginEntry row,
    Marketplace marketplace,
  ) {
    return MarketplacePlugin(
      id: row.id,
      marketplaceId: row.marketplaceId,
      marketplaceName: marketplace.name,
      name: row.name,
      displayName: row.displayName,
      description: row.description,
      author: row.author,
      category: row.category,
      homepage: row.homepage,
      version: row.version,
      source: PluginSource(
        kind: MarketplaceSourceKind.fromStorage(row.sourceKind),
        rawJson: row.sourceJson,
        url: row.sourceUrl,
        path: row.sourcePath,
        ref: row.sourceRef,
        sha: row.sourceSha,
      ),
      installed: row.installed,
      enabled: row.enabled,
      mcpStatus: PluginMcpStatus.fromStorage(row.mcpStatus),
      servers: _decodeServersFromJson(row.mcpConfigJson),
      installedServers: _decodeServersFromJson(row.installedConfigJson),
      mcpCheckedAt: _date(row.mcpCheckedAt),
      needsReconsent: row.needsReconsent,
      lastError: row.lastError,
      lastSeenAt: _date(row.lastSeenAt) ?? DateTime.now(),
    );
  }

  List<McpServerConfig> _decodeServersFromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => McpServerConfig.fromJson(Map<String, Object?>.from(item)),
          )
          .whereType<McpServerConfig>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  DateTime? _date(int? value) {
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(marketplaceApiProvider),
  );
});
