import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/marketplace.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'marketplace_controller.dart';
import 'marketplace_failure_text.dart';

enum _PluginFilter { all, withMcp, installed }

class _SectionHeaderData {
  const _SectionHeaderData(this.label, this.count);

  final String label;
  final int count;
}

List<Object> _pluginRows({
  required List<MarketplacePlugin> installed,
  required List<MarketplacePlugin> available,
  required String installedLabel,
  required String availableLabel,
}) {
  return [
    if (installed.isNotEmpty) ...[
      _SectionHeaderData(installedLabel, installed.length),
      ...installed,
    ],
    if (available.isNotEmpty) ...[
      _SectionHeaderData(availableLabel, available.length),
      ...available,
    ],
  ];
}

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabs;
  _PluginFilter _filter = _PluginFilter.all;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(marketplaceControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.marketplaceTitle),
        bottom: TabBar(
          controller: _tabs,
          dividerColor: Theme.of(context).colorScheme.outlineVariant,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.marketplacePluginsTab),
            Tab(text: l10n.marketplaceMarketplacesTab),
          ],
        ),
      ),
      body: state.when(
        loading: () =>
            _LoadingCatalog(message: l10n.marketplaceOfficialLoading),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.marketplaceErrorUnknown,
          body: marketplaceFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(marketplaceControllerProvider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (value) => _tabs.index == 0
            ? _PluginsTab(
                state: value,
                search: _search,
                filter: _filter,
                onFilterChanged: (filter) => setState(() => _filter = filter),
              )
            : _MarketplacesTab(state: value),
      ),
    );
  }
}

class _PluginsTab extends ConsumerWidget {
  const _PluginsTab({
    required this.state,
    required this.search,
    required this.filter,
    required this.onFilterChanged,
  });

  final MarketplaceViewState state;
  final TextEditingController search;
  final _PluginFilter filter;
  final ValueChanged<_PluginFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final official = state.catalog.marketplaces
        .where((item) => item.builtIn)
        .toList(growable: false);
    final officialMarketplace = official.isEmpty ? null : official.first;
    final hasCatalog = state.catalog.plugins.isNotEmpty;

    if (!hasCatalog &&
        officialMarketplace != null &&
        officialMarketplace.lastError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: l10n.marketplaceOfficialError,
        body: marketplaceStoredErrorText(l10n, officialMarketplace.lastError),
        action: OutlinedButton.icon(
          onPressed: state.refreshing.contains(officialMarketplace.id)
              ? null
              : () => _refresh(context, ref, officialMarketplace.id),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.commonRetry),
        ),
      );
    }

    if (!hasCatalog &&
        officialMarketplace != null &&
        officialMarketplace.lastSyncedAt == null) {
      return _LoadingCatalog(
        message: l10n.marketplaceOfficialLoading,
        error: officialMarketplace.lastError,
      );
    }

    if (state.catalog.marketplaces.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: l10n.marketplaceNoMarketplacesTitle,
        body: l10n.marketplaceNoMarketplacesBody,
      );
    }

    if (!hasCatalog) {
      return EmptyState(
        icon: Icons.extension_outlined,
        title: l10n.marketplaceEmptyTitle,
        body: l10n.marketplaceOfficialEmpty,
      );
    }

    final query = search.text.trim().toLowerCase();
    final matching = state.catalog.plugins
        .where((plugin) {
          final matchesQuery =
              query.isEmpty ||
              plugin.title.toLowerCase().contains(query) ||
              plugin.name.toLowerCase().contains(query) ||
              plugin.description.toLowerCase().contains(query) ||
              (plugin.author?.toLowerCase().contains(query) ?? false) ||
              (plugin.category?.toLowerCase().contains(query) ?? false);
          if (!matchesQuery) {
            return false;
          }
          return switch (filter) {
            _PluginFilter.all => true,
            _PluginFilter.withMcp => plugin.hasRemoteServers,
            _PluginFilter.installed => plugin.installed,
          };
        })
        .toList(growable: false);

    final installed = matching.where((plugin) => plugin.installed).toList();
    final available = matching.where((plugin) => !plugin.installed).toList();
    final rows = _pluginRows(
      installed: installed,
      available: available,
      installedLabel: l10n.marketplaceInstalledSection,
      availableLabel: l10n.marketplaceAvailableSection,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.marketplaceSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: search.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _FilterChip(
                label: l10n.marketplaceFilterAll,
                selected: filter == _PluginFilter.all,
                onSelected: () => onFilterChanged(_PluginFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.marketplaceFilterMcp,
                selected: filter == _PluginFilter.withMcp,
                onSelected: () => onFilterChanged(_PluginFilter.withMcp),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: l10n.marketplaceFilterInstalled,
                selected: filter == _PluginFilter.installed,
                onSelected: () => onFilterChanged(_PluginFilter.installed),
              ),
            ],
          ),
        ),
        Expanded(
          child: matching.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: l10n.marketplaceNoResultsTitle,
                  body: l10n.marketplaceNoResultsBody,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is _SectionHeaderData) {
                      return _SectionHeader(label: row.label, count: row.count);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PluginCard(plugin: row as MarketplacePlugin),
                    );
                  },
                ),
        ),
        if (state.refreshing.isNotEmpty)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }

  Future<void> _refresh(
    BuildContext context,
    WidgetRef ref,
    String marketplaceId,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .refreshMarketplace(marketplaceId);
    } on MarketplaceFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    }
  }
}

class _LoadingCatalog extends StatelessWidget {
  const _LoadingCatalog({required this.message, this.error});

  final String message;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketplacesTab extends ConsumerStatefulWidget {
  const _MarketplacesTab({required this.state});

  final MarketplaceViewState state;

  @override
  ConsumerState<_MarketplacesTab> createState() => _MarketplacesTabState();
}

class _MarketplacesTabState extends ConsumerState<_MarketplacesTab> {
  final _input = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final input = _input.text.trim();
    if (input.isEmpty || _adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .addMarketplace(input);
      if (!mounted) {
        return;
      }
      _input.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.marketplaceAdded)));
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _refresh(Marketplace marketplace) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .refreshMarketplace(marketplace.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.marketplaceRefreshed)));
      }
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    }
  }

  Future<void> _delete(Marketplace marketplace) async {
    final l10n = AppLocalizations.of(context);
    if (marketplace.builtIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.marketplaceDeleteBuiltIn)));
      return;
    }
    final installed = widget.state.catalog.plugins
        .where(
          (plugin) =>
              plugin.marketplaceId == marketplace.id && plugin.installed,
        )
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.marketplaceDeleteTitle),
        content: Text(
          installed == 0
              ? l10n.marketplaceDeleteBody(marketplace.name)
              : l10n.marketplaceDeleteWithInstalledBody(
                  marketplace.name,
                  installed,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .deleteMarketplace(marketplace.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.marketplaceDeleted)));
      }
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final marketplaces = widget.state.catalog.marketplaces;

    if (marketplaces.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _AddMarketplaceCard(
              controller: _input,
              busy: _adding,
              onAdd: _add,
            ),
          ),
          Expanded(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: l10n.marketplaceNoMarketplacesTitle,
              body: l10n.marketplaceNoMarketplacesBody,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _AddMarketplaceCard(controller: _input, busy: _adding, onAdd: _add),
        const SizedBox(height: 20),
        for (final marketplace in marketplaces)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MarketplaceCard(
              marketplace: marketplace,
              pluginCount: widget.state.catalog.plugins
                  .where((plugin) => plugin.marketplaceId == marketplace.id)
                  .length,
              refreshing: widget.state.refreshing.contains(marketplace.id),
              onRefresh: () => _refresh(marketplace),
              onDelete: marketplace.builtIn ? null : () => _delete(marketplace),
            ),
          ),
      ],
    );
  }
}

class _AddMarketplaceCard extends StatelessWidget {
  const _AddMarketplaceCard({
    required this.controller,
    required this.busy,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.marketplaceAdd,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                hintText: l10n.marketplaceAddHint,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onAdd,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(l10n.marketplaceAdd),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.marketplaceAddHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.marketplace,
    required this.pluginCount,
    required this.refreshing,
    required this.onRefresh,
    required this.onDelete,
  });

  final Marketplace marketplace;
  final int pluginCount;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final syncedAt = marketplace.lastSyncedAt;
    final materialL10n = MaterialLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    marketplace.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (refreshing)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: l10n.marketplaceRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    tooltip: l10n.marketplaceDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            if (marketplace.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                marketplace.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (marketplace.builtIn)
                  _Tag(
                    label: l10n.marketplaceBuiltIn,
                    icon: Icons.verified_outlined,
                    highlighted: true,
                  ),
                _Tag(
                  label: l10n.marketplacePluginCount(pluginCount),
                  icon: Icons.extension_outlined,
                ),
                _Tag(
                  label: syncedAt == null
                      ? l10n.marketplaceNeverSynced
                      : l10n.marketplaceLastSynced(
                          materialL10n.formatMediumDate(syncedAt.toLocal()),
                        ),
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
            if (marketplace.lastError != null &&
                marketplace.lastError!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      marketplaceStoredErrorText(l10n, marketplace.lastError),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin});

  final MarketplacePlugin plugin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/marketplace/plugins/${Uri.encodeComponent(plugin.id)}',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              _StatusDot(
                color: plugin.installed
                    ? (plugin.enabled
                          ? Colors.greenAccent
                          : theme.colorScheme.outline)
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plugin.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plugin.qualifiedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (plugin.installed ||
                        plugin.mcpStatus != PluginMcpStatus.unknown) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (plugin.installed)
                            _Tag(
                              label: plugin.enabled
                                  ? l10n.marketplaceInstalled
                                  : l10n.marketplaceDisabled,
                              icon: Icons.check_circle_outline_rounded,
                              highlighted: true,
                            ),
                          if (plugin.mcpStatus != PluginMcpStatus.unknown)
                            _Tag(
                              label: marketplaceStatusText(
                                l10n,
                                plugin.mcpStatus,
                              ),
                              icon: plugin.hasRemoteServers
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                              highlighted: plugin.hasRemoteServers,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.highlighted = false});

  final String label;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
