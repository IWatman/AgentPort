import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/marketplace_repository.dart';
import '../../domain/entities/marketplace.dart';

class MarketplaceViewState {
  const MarketplaceViewState({
    required this.catalog,
    this.refreshing = const {},
    this.initializing = false,
    this.lastError,
    this.scanningCompatibility = false,
    this.scanTotal = 0,
    this.scanDone = 0,
    this.compatibilityErrors = 0,
  });

  final MarketplaceCatalog catalog;
  final Set<String> refreshing;
  final bool initializing;
  final String? lastError;
  final bool scanningCompatibility;
  final int scanTotal;
  final int scanDone;
  final int compatibilityErrors;

  MarketplacePlugin? pluginById(String id) {
    for (final plugin in catalog.plugins) {
      if (plugin.id == id) {
        return plugin;
      }
    }
    return null;
  }

  Marketplace? marketplaceById(String id) {
    for (final marketplace in catalog.marketplaces) {
      if (marketplace.id == id) {
        return marketplace;
      }
    }
    return null;
  }

  MarketplaceViewState copyWith({
    MarketplaceCatalog? catalog,
    Set<String>? refreshing,
    bool? initializing,
    String? lastError,
    bool clearError = false,
    bool? scanningCompatibility,
    int? scanTotal,
    int? scanDone,
    int? compatibilityErrors,
  }) {
    return MarketplaceViewState(
      catalog: catalog ?? this.catalog,
      refreshing: refreshing ?? this.refreshing,
      initializing: initializing ?? this.initializing,
      lastError: clearError ? null : (lastError ?? this.lastError),
      scanningCompatibility:
          scanningCompatibility ?? this.scanningCompatibility,
      scanTotal: scanTotal ?? this.scanTotal,
      scanDone: scanDone ?? this.scanDone,
      compatibilityErrors: compatibilityErrors ?? this.compatibilityErrors,
    );
  }
}

final marketplaceControllerProvider =
    AsyncNotifierProvider<MarketplaceController, MarketplaceViewState>(
      MarketplaceController.new,
    );

class MarketplaceController extends AsyncNotifier<MarketplaceViewState> {
  var _compatibilityScanRunning = false;

  @override
  Future<MarketplaceViewState> build() async {
    final repository = ref.read(marketplaceRepositoryProvider);
    await repository.ensureBuiltInMarketplace();
    var catalog = await repository.loadCatalog();

    // Refresh the built-in catalog on first use and once a day afterwards.
    final official = catalog.marketplaces
        .where((item) => item.builtIn)
        .toList(growable: false);
    if (official.isNotEmpty) {
      final first = official.first;
      final lastSync = first.lastSyncedAt;
      final stale =
          lastSync == null ||
          DateTime.now().difference(lastSync) > const Duration(hours: 24);
      if (stale) {
        try {
          await repository.refreshMarketplace(first.id);
        } on MarketplaceFailure {
          // The cached catalog stays usable; the marketplace row shows the
          // error and offers a retry.
        }
        catalog = await repository.loadCatalog();
      }
    }

    final pending = await repository.pendingProbeCount();
    if (pending > 0) {
      unawaited(_runCompatibilityScan(pending));
    }
    return MarketplaceViewState(
      catalog: catalog,
      scanningCompatibility: pending > 0,
      scanTotal: pending,
    );
  }

  Future<void> _runCompatibilityScan(
    int total, {
    bool includeErrors = false,
  }) async {
    if (total <= 0) {
      _updateState((value) => value.copyWith(scanningCompatibility: false));
      return;
    }
    if (_compatibilityScanRunning) {
      return;
    }
    _compatibilityScanRunning = true;
    _updateState(
      (value) => value.copyWith(
        scanningCompatibility: true,
        scanTotal: total,
        scanDone: 0,
        compatibilityErrors: 0,
      ),
    );
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .probePendingPlugins(
            includeErrors: includeErrors,
            onProbed: _onPluginProbed,
          );
    } catch (_) {
      // Keep the cached catalog; the retry action stays available.
    } finally {
      _compatibilityScanRunning = false;
      _updateState((value) => value.copyWith(scanningCompatibility: false));
    }
  }

  void _onPluginProbed(MarketplacePlugin plugin) {
    _replacePlugin(plugin);
    if (!_compatibilityScanRunning) {
      return;
    }
    _updateState(
      (value) => value.copyWith(
        scanDone: value.scanDone + 1,
        compatibilityErrors:
            value.compatibilityErrors +
            (plugin.mcpStatus == PluginMcpStatus.error ? 1 : 0),
      ),
    );
  }

  Future<void> _startCompatibilityScan() async {
    final pending = await ref
        .read(marketplaceRepositoryProvider)
        .pendingProbeCount();
    if (pending > 0) {
      await _runCompatibilityScan(pending);
    }
  }

  /// Retries plugins whose compatibility check failed.
  Future<void> retryCompatibility() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final errors = current.catalog.plugins
        .where(
          (plugin) =>
              !plugin.installed && plugin.mcpStatus == PluginMcpStatus.error,
        )
        .length;
    if (errors == 0) {
      return;
    }
    await _runCompatibilityScan(errors, includeErrors: true);
  }

  Future<void> reload() async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final catalog = await repository.loadCatalog();
    final current = state.value;
    state = AsyncData(
      (current ??
              const MarketplaceViewState(
                catalog: MarketplaceCatalog(marketplaces: [], plugins: []),
              ))
          .copyWith(catalog: catalog, clearError: true),
    );
  }

  Future<void> refreshMarketplace(String id) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    _setRefreshing(id, true);
    try {
      await ref.read(marketplaceRepositoryProvider).refreshMarketplace(id);
      await _reloadCatalog();
      unawaited(_startCompatibilityScan());
    } catch (error) {
      await _reloadCatalog();
      final message = switch (error) {
        MarketplaceFailure failure => failure.kind.name,
        _ => 'unknown',
      };
      _updateState((value) => value.copyWith(lastError: message));
      rethrow;
    } finally {
      _setRefreshing(id, false);
    }
  }

  Future<Marketplace> addMarketplace(String input) async {
    final marketplace = await ref
        .read(marketplaceRepositoryProvider)
        .addMarketplace(input);
    await _reloadCatalog();
    unawaited(_startCompatibilityScan());
    return marketplace;
  }

  Future<void> deleteMarketplace(String id) async {
    await ref.read(marketplaceRepositoryProvider).deleteMarketplace(id);
    await _reloadCatalog();
  }

  Future<MarketplacePlugin> probePlugin(String pluginId) async {
    final plugin = await ref
        .read(marketplaceRepositoryProvider)
        .probePlugin(pluginId);
    _replacePlugin(plugin);
    return plugin;
  }

  Future<MarketplacePlugin> installPlugin(String pluginId) async {
    final plugin = await ref
        .read(marketplaceRepositoryProvider)
        .installPlugin(pluginId);
    _replacePlugin(plugin);
    return plugin;
  }

  Future<MarketplacePlugin> uninstallPlugin(String pluginId) async {
    final plugin = await ref
        .read(marketplaceRepositoryProvider)
        .uninstallPlugin(pluginId);
    _replacePlugin(plugin);
    return plugin;
  }

  Future<MarketplacePlugin> acceptPluginConfig(String pluginId) async {
    final plugin = await ref
        .read(marketplaceRepositoryProvider)
        .acceptPluginConfig(pluginId);
    _replacePlugin(plugin);
    return plugin;
  }

  Future<MarketplacePlugin> setPluginEnabled(
    String pluginId,
    bool enabled,
  ) async {
    final plugin = await ref
        .read(marketplaceRepositoryProvider)
        .setPluginEnabled(pluginId, enabled);
    _replacePlugin(plugin);
    return plugin;
  }

  Future<void> _reloadCatalog() async {
    final catalog = await ref.read(marketplaceRepositoryProvider).loadCatalog();
    _updateState((value) => value.copyWith(catalog: catalog));
  }

  void _replacePlugin(MarketplacePlugin plugin) {
    _updateState((value) {
      final plugins = [
        for (final item in value.catalog.plugins)
          if (item.id == plugin.id) plugin else item,
      ];
      if (!plugins.any((item) => item.id == plugin.id)) {
        plugins.add(plugin);
      }
      return value.copyWith(
        catalog: MarketplaceCatalog(
          marketplaces: value.catalog.marketplaces,
          plugins: plugins,
        ),
      );
    });
  }

  void _setRefreshing(String id, bool refreshing) {
    _updateState((value) {
      final ids = Set<String>.from(value.refreshing);
      if (refreshing) {
        ids.add(id);
      } else {
        ids.remove(id);
      }
      return value.copyWith(refreshing: ids);
    });
  }

  void _updateState(
    MarketplaceViewState Function(MarketplaceViewState) update,
  ) {
    if (!ref.mounted) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(update(current));
  }
}
