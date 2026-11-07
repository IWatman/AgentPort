import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/marketplace_repository.dart';
import '../../domain/entities/marketplace.dart';

class MarketplaceViewState {
  const MarketplaceViewState({
    required this.catalog,
    this.refreshing = const {},
    this.initializing = false,
    this.lastError,
  });

  final MarketplaceCatalog catalog;
  final Set<String> refreshing;
  final bool initializing;
  final String? lastError;

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
  }) {
    return MarketplaceViewState(
      catalog: catalog ?? this.catalog,
      refreshing: refreshing ?? this.refreshing,
      initializing: initializing ?? this.initializing,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final marketplaceControllerProvider =
    AsyncNotifierProvider<MarketplaceController, MarketplaceViewState>(
      MarketplaceController.new,
    );

class MarketplaceController extends AsyncNotifier<MarketplaceViewState> {
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

    return MarketplaceViewState(catalog: catalog);
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
