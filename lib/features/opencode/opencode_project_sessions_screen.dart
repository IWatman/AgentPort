import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'opencode_failure_text.dart';
import 'opencode_format.dart';
import 'opencode_projects_controller.dart';

class OpenCodeProjectSessionsScreen extends ConsumerStatefulWidget {
  const OpenCodeProjectSessionsScreen({
    required this.connectionId,
    required this.projectId,
    super.key,
  });

  final String connectionId;
  final String projectId;

  @override
  ConsumerState<OpenCodeProjectSessionsScreen> createState() =>
      _OpenCodeProjectSessionsScreenState();
}

class _OpenCodeProjectSessionsScreenState
    extends ConsumerState<OpenCodeProjectSessionsScreen> {
  var _creating = false;

  OpenCodeProjectKey get _key =>
      (connectionId: widget.connectionId, projectId: widget.projectId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = openCodeProjectSessionsControllerProvider(_key);
    final state = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.value?.project.name ?? l10n.openCodeSessionsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (state.value != null) ...[
              const SizedBox(height: 2),
              Text(
                state.value!.project.directory,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : () => unawaited(_createSession()),
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          _creating ? l10n.openCodeCreatingSession : l10n.openCodeNewSession,
        ),
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
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 96),
                children: [
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final session in value.sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionCard(
                      connectionId: widget.connectionId,
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

  Future<void> _createSession() async {
    final l10n = AppLocalizations.of(context);
    final provider = openCodeProjectSessionsControllerProvider(_key);
    setState(() => _creating = true);
    try {
      final session = await ref
          .read(provider.notifier)
          .createSession(title: l10n.openCodeNewSession);
      if (!mounted) {
        return;
      }
      await context.push(
        '/opencode/${Uri.encodeComponent(widget.connectionId)}/sessions/'
        '${Uri.encodeComponent(session.id)}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(openCodeFailureText(l10n, error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.connectionId, required this.session});

  final String connectionId;
  final OpenCodeSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = session.updatedAt;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(
          '/opencode/${Uri.encodeComponent(connectionId)}/sessions/'
          '${Uri.encodeComponent(session.id)}',
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: updated == null
            ? null
            : Text(
                openCodeDateText(context, updated),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
