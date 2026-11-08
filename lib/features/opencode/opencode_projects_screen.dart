import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../data/repositories/opencode_repository.dart';
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
            onPressed: () => _searchSessions(context, ref, connectionId),
            tooltip: l10n.openCodeSearchSessions,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: () => _addProject(context, ref, connectionId),
            tooltip: l10n.openCodeNewProject,
            icon: const Icon(Icons.create_new_folder_rounded),
          ),
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

Future<void> _searchSessions(
  BuildContext context,
  WidgetRef ref,
  String connectionId,
) async {
  final session = await showDialog<OpenCodeSession>(
    context: context,
    builder: (dialogContext) =>
        _SessionSearchDialog(connectionId: connectionId),
  );
  if (session == null || !context.mounted) {
    return;
  }
  context.push(
    '/opencode/${Uri.encodeComponent(connectionId)}/sessions/'
    '${Uri.encodeComponent(session.id)}',
  );
}

Future<void> _addProject(
  BuildContext context,
  WidgetRef ref,
  String connectionId,
) async {
  final l10n = AppLocalizations.of(context);
  final current = ref
      .read(openCodeProjectsControllerProvider(connectionId))
      .value;
  if (current == null || current.projects.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.openCodeProjectNoBaseProject)));
    return;
  }
  final base = current.projects.firstWhere(
    (project) =>
        !project.directory.toLowerCase().contains(r'\appdata\local\temp\'),
    orElse: () => current.projects.first,
  );
  final location = base.directory;
  final parent = p.windows.dirname(location);
  final roots = <String>{
    for (final project in current.projects)
      if (p.windows.rootPrefix(project.directory).isNotEmpty)
        p.windows.rootPrefix(project.directory),
  }.toList()..sort();
  final directory = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _ProjectDirectoryDialog(
      connectionId: connectionId,
      locationDirectory: location,
      startPath: parent.isEmpty ? location : parent,
      roots: roots,
    ),
  );
  if (directory == null || !context.mounted) {
    return;
  }
  try {
    final project = await ref
        .read(openCodeProjectsControllerProvider(connectionId).notifier)
        .addProject(directory);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openCodeProjectAdded(project.name))),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(openCodeFailureText(l10n, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _SessionSearchDialog extends ConsumerStatefulWidget {
  const _SessionSearchDialog({required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<_SessionSearchDialog> createState() =>
      _SessionSearchDialogState();
}

class _SessionSearchDialogState extends ConsumerState<_SessionSearchDialog> {
  List<OpenCodeSession> _sessions = const [];
  var _loading = true;
  String? _error;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(openCodeRepositoryProvider);
      final connection = await repository.connection(widget.connectionId);
      if (connection == null) {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidPayload,
          detail: 'The OpenCode connection no longer exists.',
        );
      }
      final client = await repository.clientFor(connection);
      final sessions = await client.sessions();
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = openCodeFailureText(AppLocalizations.of(context), error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _sessions
        : _sessions
              .where(
                (session) =>
                    session.title.toLowerCase().contains(query) ||
                    session.id.toLowerCase().contains(query) ||
                    (session.directory?.toLowerCase().contains(query) ?? false),
              )
              .toList(growable: false);

    return AlertDialog(
      title: Text(l10n.openCodeSearchSessions),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.openCodeSearchSessionsHint,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: Text(l10n.commonRetry),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.openCodeNoSessionsFound,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      primary: false,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.forum_outlined),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            session.directory ?? session.project ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(session),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _ProjectDirectoryDialog extends ConsumerStatefulWidget {
  const _ProjectDirectoryDialog({
    required this.connectionId,
    required this.locationDirectory,
    required this.startPath,
    required this.roots,
  });

  final String connectionId;
  final String locationDirectory;
  final String startPath;
  final List<String> roots;

  @override
  ConsumerState<_ProjectDirectoryDialog> createState() =>
      _ProjectDirectoryDialogState();
}

class _ProjectDirectoryDialogState
    extends ConsumerState<_ProjectDirectoryDialog> {
  late String _path = widget.startPath;
  List<OpenCodeDirectoryEntry> _entries = const [];
  var _loading = true;
  String? _error;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    _load(widget.startPath);
  }

  Future<void> _load(String path) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(openCodeRepositoryProvider);
      final connection = await repository.connection(widget.connectionId);
      if (connection == null) {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidPayload,
          detail: 'The OpenCode connection no longer exists.',
        );
      }
      final client = await repository.clientFor(connection);
      final entries = await client.listDirectories(
        locationDirectory: widget.locationDirectory,
        path: path,
      );
      if (!mounted || request != _request) {
        return;
      }
      final normalized = p.windows.normalize(path);
      setState(() {
        _path = normalized;
        _entries = entries
            .where((entry) => entry.path != normalized)
            .toList(growable: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _loading = false;
        _error = openCodeFailureText(AppLocalizations.of(context), error);
      });
    }
  }

  void _goUp() {
    final parent = p.windows.dirname(_path);
    if (parent == _path || parent.isEmpty) {
      return;
    }
    _load(parent);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final root = p.windows.rootPrefix(_path);
    final canUp = p.windows.dirname(_path) != _path;

    return AlertDialog(
      title: Text(l10n.openCodeNewProjectTitle),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.openCodeChooseFolderHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: canUp && !_loading ? _goUp : null,
                  tooltip: l10n.openCodeFolderUp,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                Expanded(
                  child: SelectableText(
                    _path,
                    maxLines: 2,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : () => _load(_path),
                  tooltip: l10n.commonRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (widget.roots.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.storage_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: widget.roots.contains(root) ? root : null,
                    hint: Text(l10n.openCodeDrive),
                    items: [
                      for (final drive in widget.roots)
                        DropdownMenuItem(value: drive, child: Text(drive)),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value != null) {
                              _load(value);
                            }
                          },
                  ),
                ],
              ),
            const Divider(height: 12),
            Expanded(child: _buildBody(l10n, theme)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _loading || _error != null
              ? null
              : () => Navigator.of(context).pop(_path),
          child: Text(l10n.openCodeSelectFolder),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _load(_path),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          l10n.openCodeFolderEmpty,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      primary: false,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.folder_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _loading ? null : () => _load(entry.path),
        );
      },
    );
  }
}
