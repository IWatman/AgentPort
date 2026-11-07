import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/opencode_repository.dart';
import '../../domain/entities/opencode.dart';

class OpenCodeSessionsState {
  const OpenCodeSessionsState({
    required this.connection,
    required this.sessions,
  });

  final OpenCodeConnection connection;
  final List<OpenCodeSession> sessions;
}

final openCodeSessionsControllerProvider =
    AsyncNotifierProvider.family<
      OpenCodeSessionsController,
      OpenCodeSessionsState,
      String
    >(OpenCodeSessionsController.new, isAutoDispose: true);

/// Loads the sessions exposed by one OpenCode server.
class OpenCodeSessionsController extends AsyncNotifier<OpenCodeSessionsState> {
  OpenCodeSessionsController(this.connectionId);

  final String connectionId;

  @override
  Future<OpenCodeSessionsState> build() {
    return _load(ref.watch(openCodeRepositoryProvider));
  }

  /// Reloads the session list, keeping failures in the provider state.
  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    state = const AsyncLoading();
    try {
      final value = await _load(ref.read(openCodeRepositoryProvider));
      if (ref.mounted) {
        state = AsyncData(value);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(_asFailure(error), stackTrace);
      }
    }
  }

  Future<OpenCodeSessionsState> _load(OpenCodeRepository repository) async {
    final connection = await repository.connection(connectionId);
    if (connection == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The OpenCode connection no longer exists.',
      );
    }

    final client = await repository.clientFor(connection);
    final sessions = await client.sessions();
    try {
      await repository.touch(connection);
    } catch (_) {
      // A stale last-seen timestamp must not hide a working session list.
    }

    return OpenCodeSessionsState(connection: connection, sessions: sessions);
  }

  OpenCodeFailure _asFailure(Object error) {
    if (error is OpenCodeFailure) {
      return error;
    }
    return OpenCodeFailure(
      OpenCodeFailureKind.invalidResponse,
      detail: error.toString(),
    );
  }
}
