import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/marketplace.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'marketplace_controller.dart';
import 'marketplace_failure_text.dart';

class PluginDetailScreen extends ConsumerStatefulWidget {
  const PluginDetailScreen({required this.pluginId, super.key});

  final String pluginId;

  @override
  ConsumerState<PluginDetailScreen> createState() => _PluginDetailScreenState();
}

class _PluginDetailScreenState extends ConsumerState<PluginDetailScreen> {
  bool _busy = false;
  bool _probeStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _probe();
      }
    });
  }

  Future<void> _probe() async {
    if (_probeStarted) {
      return;
    }
    final plugin = ref
        .read(marketplaceControllerProvider)
        .value
        ?.pluginById(widget.pluginId);
    if (plugin == null) {
      return;
    }
    if (plugin.mcpCheckedAt != null &&
        plugin.mcpStatus != PluginMcpStatus.unknown &&
        plugin.mcpStatus != PluginMcpStatus.error) {
      _probeStarted = true;
      return;
    }
    _probeStarted = true;
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .probePlugin(widget.pluginId);
    } on MarketplaceFailure {
      // The failure is cached on the plugin row and rendered below.
    }
  }

  Future<void> _install() async {
    if (_busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final plugin = ref
        .read(marketplaceControllerProvider)
        .value
        ?.pluginById(widget.pluginId);
    if (plugin != null && plugin.trustLevel == TrustLevel.community) {
      final servers = plugin.servers.isEmpty
          ? plugin.homepage ?? plugin.qualifiedName
          : plugin.servers.map((server) => server.url).join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.marketplaceCommunityInstallTitle),
          content: Text(l10n.marketplaceCommunityInstallBody(servers)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.marketplaceInstall),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .installPlugin(widget.pluginId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.marketplaceInstallSuccess)));
    } on MarketplaceFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (error.kind == MarketplaceFailureKind.noRemoteMcp) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.marketplaceUnsupportedInstallTitle),
            content: Text(l10n.marketplaceUnsupportedInstallBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonDone),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _uninstall(MarketplacePlugin plugin) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.marketplaceUninstallTitle),
        content: Text(l10n.marketplaceUninstallBody(plugin.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.marketplaceUninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .uninstallPlugin(widget.pluginId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.marketplaceUninstallSuccess)),
        );
      }
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggle(MarketplacePlugin plugin, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    if (enabled && plugin.needsReconsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.marketplaceNeedsReconsentBody)),
      );
      return;
    }
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .setPluginEnabled(widget.pluginId, enabled);
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    }
  }

  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .probePlugin(widget.pluginId);
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

  Future<void> _accept() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(marketplaceControllerProvider.notifier)
          .acceptPluginConfig(widget.pluginId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.marketplaceReconsentAccepted)),
        );
      }
    } on MarketplaceFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(marketplaceFailureText(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(marketplaceControllerProvider);
    final plugin = state.value?.pluginById(widget.pluginId);

    ref.listen(marketplaceControllerProvider, (previous, next) {
      if (next.value?.pluginById(widget.pluginId) != null) {
        _probe();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(plugin?.title ?? l10n.marketplaceTitle),
        actions: [
          IconButton(
            onPressed: plugin == null ? null : _refresh,
            tooltip: l10n.marketplaceRefreshPlugin,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.marketplaceErrorUnknown,
          body: marketplaceFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(marketplaceControllerProvider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (_) {
          if (plugin == null) {
            return EmptyState(
              icon: Icons.extension_off_rounded,
              title: l10n.marketplacePluginNotFoundTitle,
              body: l10n.marketplacePluginNotFoundBody,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderCard(plugin: plugin),
              const SizedBox(height: 12),
              _InstallCard(
                plugin: plugin,
                busy: _busy,
                onInstall: _install,
                onUninstall: () => _uninstall(plugin),
                onAccept: _accept,
                onToggle: (enabled) => _toggle(plugin, enabled),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.marketplaceServers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ServersCard(plugin: plugin, onRetry: _refresh),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.plugin});

  final MarketplacePlugin plugin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final category = plugin.category;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.extension_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (plugin.author != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.marketplaceByAuthor(plugin.author!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(
                  label: marketplaceTrustText(l10n, plugin.trustLevel),
                  icon: Icons.verified_user_outlined,
                  highlighted: plugin.trustLevel != TrustLevel.community,
                ),
                _Tag(
                  label: plugin.qualifiedName,
                  icon: Icons.storefront_outlined,
                ),
                if (category != null)
                  _Tag(label: category, icon: Icons.sell_outlined),
                if (plugin.version != null)
                  _Tag(
                    label: l10n.marketplaceVersion(plugin.version!),
                    icon: Icons.sell_outlined,
                  ),
              ],
            ),
            if (plugin.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(plugin.description, style: theme.textTheme.bodyMedium),
            ],
            if (plugin.homepage != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      plugin.homepage!,
                      maxLines: 2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.marketplaceCopyLink,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: plugin.homepage!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.marketplaceCopied)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _InfoRow(
              label: l10n.marketplaceSource,
              value: plugin.source.kind.storageValue,
            ),
            if (plugin.lastError != null && plugin.lastError!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  plugin.lastError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InstallCard extends StatelessWidget {
  const _InstallCard({
    required this.plugin,
    required this.busy,
    required this.onInstall,
    required this.onUninstall,
    required this.onAccept,
    required this.onToggle,
  });

  final MarketplacePlugin plugin;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;
  final VoidCallback onAccept;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final checking =
        plugin.mcpStatus == PluginMcpStatus.unknown &&
        plugin.mcpCheckedAt == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusDot(
                  color: plugin.installed
                      ? (plugin.enabled
                            ? Colors.greenAccent
                            : theme.colorScheme.outline)
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plugin.installed
                        ? (plugin.enabled
                              ? l10n.marketplaceInstalled
                              : l10n.marketplaceDisabled)
                        : l10n.marketplaceNotInstalled,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (plugin.installed)
                  Switch.adaptive(
                    value: plugin.enabled,
                    onChanged: busy ? null : onToggle,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(
                  label: marketplaceStatusText(l10n, plugin.mcpStatus),
                  icon: plugin.hasRemoteServers
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  highlighted: plugin.hasRemoteServers,
                ),
                if (plugin.servers.isNotEmpty)
                  _Tag(
                    label: l10n.marketplaceServers,
                    icon: Icons.dns_outlined,
                  ),
              ],
            ),
            if (plugin.needsReconsent) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.marketplaceNeedsReconsent,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.marketplaceNeedsReconsentBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(l10n.marketplaceReconsentAccept),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (checking)
              const LinearProgressIndicator()
            else if (plugin.installed)
              OutlinedButton.icon(
                onPressed: busy ? null : onUninstall,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.marketplaceUninstall),
              )
            else
              FilledButton.icon(
                onPressed: busy || !plugin.hasRemoteServers ? null : onInstall,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(l10n.marketplaceInstall),
              ),
            if (!plugin.installed &&
                !plugin.hasRemoteServers &&
                !checking &&
                plugin.mcpStatus != PluginMcpStatus.unknown) ...[
              const SizedBox(height: 8),
              Text(
                l10n.marketplaceUnsupportedInstallBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServersCard extends StatelessWidget {
  const _ServersCard({required this.plugin, required this.onRetry});

  final MarketplacePlugin plugin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (plugin.mcpStatus == PluginMcpStatus.unknown) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.marketplaceServersChecking)),
            ],
          ),
        ),
      );
    }

    if (plugin.mcpStatus == PluginMcpStatus.error) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.marketplaceMcpError,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              if (plugin.lastError != null) ...[
                const SizedBox(height: 4),
                Text(plugin.lastError!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }

    if (plugin.servers.isEmpty) {
      final noMcp = plugin.mcpStatus == PluginMcpStatus.none;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                noMcp
                    ? l10n.marketplaceServersEmpty
                    : l10n.marketplaceServersUnsupported,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                noMcp
                    ? l10n.marketplaceServersEmptyBody
                    : l10n.marketplaceUnsupportedInstallBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final server in plugin.servers) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          server.name,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      _Tag(
                        label: server.transport.storageValue.toUpperCase(),
                        highlighted: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    server.url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: l10n.marketplaceAuth,
                    value: marketplaceAuthText(l10n, server.authType),
                  ),
                  if (server.headerNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: l10n.marketplaceHeader,
                      value: server.headerNames.join(', '),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (plugin.mcpStatus == PluginMcpStatus.stdio ||
            plugin.mcpStatus == PluginMcpStatus.unsupported ||
            plugin.mcpStatus == PluginMcpStatus.mixed)
          Card(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                plugin.mcpStatus == PluginMcpStatus.mixed
                    ? l10n.marketplaceServersMixedWarning
                    : l10n.marketplaceServersUnsupported,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
