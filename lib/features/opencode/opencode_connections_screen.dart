import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'opencode_connections_controller.dart';
import 'opencode_failure_text.dart';
import 'opencode_format.dart';

class OpenCodeConnectionsScreen extends ConsumerWidget {
  const OpenCodeConnectionsScreen({this.embedded = false, super.key});

  /// When embedded in the Chats tab, the parent supplies the app bar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(openCodeConnectionsControllerProvider);

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: Text(l10n.openCodeTitle),
              actions: [
                IconButton(
                  onPressed: () =>
                      ref.invalidate(openCodeConnectionsControllerProvider),
                  tooltip: l10n.commonRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/opencode/pair'),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(l10n.openCodePair),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.openCodeConnectionsError,
          body: openCodeFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () =>
                ref.invalidate(openCodeConnectionsControllerProvider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (connections) {
          if (connections.isEmpty) {
            return EmptyState(
              icon: Icons.terminal_rounded,
              title: l10n.openCodeNoConnectionsTitle,
              body: l10n.openCodeNoConnectionsBody,
              action: FilledButton.icon(
                onPressed: () => context.push('/opencode/pair'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l10n.openCodePair),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final connection in connections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ConnectionCard(connection: connection),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.connection});

  final OpenCodeConnection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lastSeen = connection.lastSeen;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/opencode/${Uri.encodeComponent(connection.id)}/projects',
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.terminal_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connection.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastSeen == null
                          ? l10n.openCodeNeverSeen
                          : l10n.openCodeLastSeen(
                              openCodeDateText(context, lastSeen),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ConnectionAction>(
                tooltip: l10n.openCodeConnectionMenu,
                onSelected: (action) {
                  switch (action) {
                    case _ConnectionAction.delete:
                      _delete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _ConnectionAction.delete,
                    child: Text(l10n.commonDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.openCodeDeleteTitle),
        content: Text(l10n.openCodeDeleteBody(connection.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(openCodeConnectionsControllerProvider.notifier)
          .delete(connection.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(openCodeFailureText(l10n, error))),
        );
      }
    }
  }
}

enum _ConnectionAction { delete }
