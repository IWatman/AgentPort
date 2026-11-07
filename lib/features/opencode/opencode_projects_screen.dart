import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'opencode_connection_header.dart';
import 'opencode_failure_text.dart';
import 'opencode_projects_controller.dart';

class OpenCodeProjectsScreen extends ConsumerWidget {
  const OpenCodeProjectsScreen({required this.connectionId, super.key});

  final String connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = openCodeProjectsControllerProvider(connectionId);
    final state = ref.watch(provider);
    final connectionName = state.value?.connection.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.openCodeProjectsTitle),
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
          title: l10n.openCodeProjectsError,
          body: openCodeFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (value) {
          final controller = ref.read(provider.notifier);
          if (value.projects.isEmpty) {
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  OpenCodeConnectionHeader(connection: value.connection),
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: l10n.openCodeProjectsEmptyTitle,
                    body: l10n.openCodeProjectsEmptyBody,
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
                OpenCodeConnectionHeader(connection: value.connection),
                const SizedBox(height: 18),
                Text(
                  l10n.openCodeProjectsTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final project in value.projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProjectCard(
                      connectionId: connectionId,
                      project: project,
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.connectionId, required this.project});

  final String connectionId;
  final OpenCodeProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(
          '/opencode/${Uri.encodeComponent(connectionId)}/projects/'
          '${Uri.encodeComponent(project.id)}/sessions',
        ),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          child: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
        ),
        title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          project.directory,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
