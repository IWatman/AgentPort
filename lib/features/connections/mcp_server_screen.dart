import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';
import '../../l10n/generated/app_localizations.dart';
import '../marketplace/marketplace_failure_text.dart';
import '../shared/empty_state.dart';
import 'mcp_connections_controller.dart';
import 'mcp_text.dart';

class McpServerScreen extends ConsumerWidget {
  const McpServerScreen({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mcpConnectionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcpServerTitle)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.mcpConnectionError,
          body: error.toString(),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(mcpConnectionsControllerProvider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (value) {
          final view = value.byId(serverId);
          if (view == null) {
            return EmptyState(
              icon: Icons.hub_outlined,
              title: l10n.mcpNoServersTitle,
              body: l10n.mcpNoServersBody,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _ServerHeader(view: view),
              const SizedBox(height: 12),
              _StatusCard(view: view),
              const SizedBox(height: 20),
              Text(
                l10n.mcpAuthTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _AuthCard(view: view),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.mcpToolsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.mcpToolsCount(view.tools.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (view.tools.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.mcpNoTools,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final tool in view.tools)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ToolCard(tool: tool),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ServerHeader extends StatelessWidget {
  const _ServerHeader({required this.view});

  final McpServerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final server = view.server;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.hub_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (server.pluginTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          server.pluginTitle!,
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
            const SizedBox(height: 12),
            SelectableText(
              server.url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Tag(label: server.transport.storageValue.toUpperCase()),
                _Tag(label: marketplaceAuthText(l10n, server.authType)),
                if (server.marketplaceName != null)
                  _Tag(label: server.marketplaceName!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.view});

  final McpServerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final server = view.server;
    final checking = view.status == McpConnectionStatus.checking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusDot(status: view.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mcpStatusText(l10n, view.status),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.mcpEnabled),
              value: server.enabled,
              onChanged: checking
                  ? null
                  : (enabled) => ref
                        .read(mcpConnectionsControllerProvider.notifier)
                        .setEnabled(server.id, enabled),
            ),
            if (!server.supportsCurrentTransport) ...[
              const SizedBox(height: 4),
              Text(
                l10n.mcpTransportUnsupported,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (view.error != null) ...[
              const SizedBox(height: 8),
              Text(
                mcpFailureText(l10n, view.error),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              if (view.error!.details != null) ...[
                const SizedBox(height: 4),
                SelectableText(
                  view.error!.details!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            if (server.needsReconsent) ...[
              const SizedBox(height: 8),
              Text(
                l10n.marketplaceNeedsReconsentBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: checking || !server.supportsCurrentTransport
                  ? null
                  : () => ref
                        .read(mcpConnectionsControllerProvider.notifier)
                        .test(server.id),
              icon: checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(checking ? l10n.mcpTesting : l10n.mcpTest),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCard extends ConsumerStatefulWidget {
  const _AuthCard({required this.view});

  final McpServerView view;

  @override
  ConsumerState<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<_AuthCard> {
  final _controllers = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final server = widget.view.server;
    final stored = await ref
        .read(mcpConnectionsControllerProvider.notifier)
        .headersFor(server.id);
    if (!mounted) {
      return;
    }
    final names = <String>{...server.requiredHeaders, ...stored.keys};
    for (final name in names) {
      _controllers[name] = TextEditingController(text: stored[name] ?? '');
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final values = <String, String>{
      for (final entry in _controllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
    try {
      final controller = ref.read(mcpConnectionsControllerProvider.notifier);
      await controller.saveHeaders(widget.view.server.id, values);
      await controller.test(widget.view.server.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.mcpAuthSaved)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final server = widget.view.server;

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    if (server.authType == McpAuthType.oauth && _controllers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.mcpAuthOAuthUnsupported,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mcpAuthHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_controllers.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.mcpAuthOAuthUnsupported,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            for (final entry in _controllers.entries) ...[
              const SizedBox(height: 12),
              TextField(
                controller: entry.value,
                enabled: !_saving,
                obscureText: _isSensitiveHeader(entry.key),
                decoration: InputDecoration(
                  labelText: entry.key,
                  hintText: server.headerTemplates[entry.key],
                  helperText: server.headerTemplates[entry.key],
                ),
              ),
            ],
            if (_controllers.isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_rounded),
                label: Text(l10n.mcpSaveAndConnect),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSensitiveHeader(String name) {
    final lower = name.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('token') ||
        lower.contains('key') ||
        lower.contains('secret');
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final McpTool tool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _Tag(
                  label: tool.needsApproval
                      ? l10n.mcpApprovalRequired
                      : l10n.mcpReadOnlyTool,
                  highlighted: !tool.needsApproval,
                ),
              ],
            ),
            if (tool.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tool.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final McpConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      McpConnectionStatus.connected => Colors.greenAccent,
      McpConnectionStatus.checking => theme.colorScheme.primary,
      McpConnectionStatus.needsAuth => Colors.amber,
      McpConnectionStatus.error => theme.colorScheme.error,
      McpConnectionStatus.disconnected => theme.colorScheme.outline,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlighted = false});

  final String label;
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
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
