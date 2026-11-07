import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/mcp.dart';
import '../../l10n/generated/app_localizations.dart';
import '../marketplace/marketplace_failure_text.dart';
import '../shared/empty_state.dart';
import 'mcp_connections_controller.dart';
import 'mcp_text.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mcpConnectionsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.connectionsTitle),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(mcpConnectionsControllerProvider),
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
          if (value.servers.isEmpty) {
            return EmptyState(
              icon: Icons.hub_outlined,
              title: l10n.mcpNoServersTitle,
              body: l10n.mcpNoServersBody,
              action: FilledButton.icon(
                onPressed: () => context.go('/marketplace'),
                icon: const Icon(Icons.storefront_rounded),
                label: Text(l10n.mcpOpenMarketplace),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                l10n.mcpServersSection,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              for (final view in value.servers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ServerCard(view: view),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard({required this.view});

  final McpServerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final server = view.server;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push('/connections/${Uri.encodeComponent(server.id)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusIndicator(view: view),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: server.enabled,
                    onChanged: view.status == McpConnectionStatus.checking
                        ? null
                        : (enabled) => ref
                              .read(mcpConnectionsControllerProvider.notifier)
                              .setEnabled(server.id, enabled),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                server.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Tag(label: server.transport.storageValue.toUpperCase()),
                  _Tag(label: marketplaceAuthText(l10n, server.authType)),
                  _Tag(
                    label: l10n.mcpToolsCount(view.tools.length),
                    highlighted: view.tools.isNotEmpty,
                  ),
                  if (!server.enabled) _Tag(label: l10n.mcpServerDisabled),
                  if (server.needsReconsent)
                    _Tag(label: l10n.marketplaceNeedsReconsent),
                ],
              ),
              if (view.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  mcpFailureText(l10n, view.error),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.view});

  final McpServerView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (view.status == McpConnectionStatus.checking) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final color = switch (view.status) {
      McpConnectionStatus.connected => Colors.greenAccent,
      McpConnectionStatus.needsAuth => Colors.amber,
      McpConnectionStatus.error => theme.colorScheme.error,
      McpConnectionStatus.disconnected => theme.colorScheme.outline,
      McpConnectionStatus.checking => theme.colorScheme.primary,
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
