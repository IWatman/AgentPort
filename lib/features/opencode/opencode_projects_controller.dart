import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/opencode_repository.dart';
import '../../domain/entities/opencode.dart';

class OpenCodeProjectsState {
  const OpenCodeProjectsState({
    required this.connection,
    required this.projects,
  });

  final OpenCodeConnection connection;
  final List<OpenCodeProject> projects;
}

final openCodeProjectsControllerProvider =
    AsyncNotifierProvider.family<
      OpenCodeProjectsController,
      OpenCodeProjectsState,
      String
    >(OpenCodeProjectsController.new, isAutoDispose: true);

/// Loads the project list for one OpenCode connection.
class OpenCodeProjectsController extends AsyncNotifier<OpenCodeProjectsState> {
  OpenCodeProjectsController(this.connectionId);

  final String connectionId;

  @override
  Future<OpenCodeProjectsState> build() async {
    return _load(ref.watch(openCodeRepositoryProvider));
  }

  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    state = const AsyncLoading();
    try {
      final loaded = await _load(ref.read(openCodeRepositoryProvider));
      if (ref.mounted) {
        state = AsyncData(loaded);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  /// Registers a server directory as a project and adds it to the list.
  Future<OpenCodeProject> addProject(String directory) async {
    final current = state.value;
    if (current == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The project list is not loaded yet.',
      );
    }
    final client = await ref
        .read(openCodeRepositoryProvider)
        .clientFor(current.connection);
    final registered = await client.registerProject(directory);
    if (ref.mounted) {
      final projects = [...current.projects];
      final index = projects.indexWhere(
        (project) => project.id == registered.project.id,
      );
      if (index >= 0) {
        projects[index] = registered.project;
      } else {
        projects.insert(0, registered.project);
      }
      state = AsyncData(
        OpenCodeProjectsState(
          connection: current.connection,
          projects: projects,
        ),
      );
    }
    return registered.project;
  }

  Future<OpenCodeProjectsState> _load(OpenCodeRepository repository) async {
    final connection = await repository.connection(connectionId);
    if (connection == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The OpenCode connection no longer exists.',
      );
    }
    final client = await repository.clientFor(connection);
    final projects = await client.projects();
    return OpenCodeProjectsState(connection: connection, projects: projects);
  }
}

typedef OpenCodeProjectKey = ({String connectionId, String projectId});

class OpenCodeProjectSessionsState {
  const OpenCodeProjectSessionsState({
    required this.connection,
    required this.project,
    required this.sessions,
  });

  final OpenCodeConnection connection;
  final OpenCodeProject project;
  final List<OpenCodeSession> sessions;

  OpenCodeProjectSessionsState copyWith({List<OpenCodeSession>? sessions}) {
    return OpenCodeProjectSessionsState(
      connection: connection,
      project: project,
      sessions: sessions ?? this.sessions,
    );
  }
}

final openCodeProjectSessionsControllerProvider =
    AsyncNotifierProvider.family<
      OpenCodeProjectSessionsController,
      OpenCodeProjectSessionsState,
      OpenCodeProjectKey
    >(OpenCodeProjectSessionsController.new, isAutoDispose: true);

/// Loads the sessions that belong to one project.
class OpenCodeProjectSessionsController
    extends AsyncNotifier<OpenCodeProjectSessionsState> {
  OpenCodeProjectSessionsController(this.key);

  final OpenCodeProjectKey key;

  @override
  Future<OpenCodeProjectSessionsState> build() async {
    return _load(ref.watch(openCodeRepositoryProvider));
  }

  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    state = const AsyncLoading();
    try {
      final loaded = await _load(ref.read(openCodeRepositoryProvider));
      if (ref.mounted) {
        state = AsyncData(loaded);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  /// Creates a session in the current project and refreshes the list.
  Future<OpenCodeSession> createSession({String? title}) async {
    final current = state.value;
    if (current == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The project is not loaded yet.',
      );
    }
    final client = await ref
        .read(openCodeRepositoryProvider)
        .clientFor(current.connection);
    final created = await client.createSession(
      directory: current.project.directory,
      title: title,
    );
    if (ref.mounted) {
      state = AsyncData(
        current.copyWith(sessions: [created, ...current.sessions]),
      );
    }
    return created;
  }

  Future<OpenCodeProjectSessionsState> _load(
    OpenCodeRepository repository,
  ) async {
    final connection = await repository.connection(key.connectionId);
    if (connection == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The OpenCode connection no longer exists.',
      );
    }
    final client = await repository.clientFor(connection);
    final projects = await client.projects();
    final project = projects
        .where((candidate) => candidate.id == key.projectId)
        .firstOrNull;
    if (project == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The OpenCode project no longer exists.',
      );
    }
    final sessions = await client.sessions(projectId: key.projectId);
    return OpenCodeProjectSessionsState(
      connection: connection,
      project: project,
      sessions: sessions,
    );
  }
}
