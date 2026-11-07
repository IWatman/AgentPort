import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'opencode_failure_text.dart';
import 'opencode_format.dart';
import 'opencode_sessions_controller.dart';

class OpenCodeSessionsScreen extends ConsumerWidget {
  const OpenCodeSessionsScreen({required this.connectionId, super.key});

  final String connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = openCodeSessionsControllerProvider(connectionId);
    final state = ref.watch(provider);
    final connectionName = state.value?.connection.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.openCodeSessionsTitle),
            if (connectionName != null) ...[
              const SizedBox(height: 2),
              Text(
                connectionName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(provider),
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.openCodeSessionsError,
          body: openCodeFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (value) {
          final controller = ref.read(provider.notifier);
          if (value.sessions.isEmpty) {
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _ConnectionHeader(connection: value.connection),
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: l10n.openCodeSessionsEmptyTitle,
                    body: l10n.openCodeSessionsEmptyBody,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _ConnectionHeader(connection: value.connection),
                const SizedBox(height: 18),
                Text(
                  l10n.openCodeSessionsTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final session in value.sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionCard(
                      connectionId: connectionId,
                      session: session,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConnectionHeader extends StatelessWidget {
  const _ConnectionHeader({required this.connection});

  final OpenCodeConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(Icons.terminal_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
                  Text(
                    connection.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: l10n.openCodeConnected,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.connectionId, required this.session});

  final String connectionId;
  final OpenCodeSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final updated = session.updatedAt;
    final subtitle = <String>[
      if (session.project != null && session.project!.trim().isNotEmpty)
        session.project!.trim(),
      if (updated != null)
        l10n.openCodeSessionUpdated(openCodeDateText(context, updated)),
    ].join('\n');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
        title: Text(
          session.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(
          '/opencode/${Uri.encodeComponent(connectionId)}/sessions/'
          '${Uri.encodeComponent(session.id)}',
        ),
      ),
    );
  }
}
