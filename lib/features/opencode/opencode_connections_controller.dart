import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/opencode_repository.dart';
import '../../domain/entities/opencode.dart';

/// Whether a connection name should be sent to the repository.
String? _cleanName(String? name) {
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

final openCodeConnectionsControllerProvider =
    AsyncNotifierProvider<
      OpenCodeConnectionsController,
      List<OpenCodeConnection>
    >(OpenCodeConnectionsController.new);

/// Owns the saved OpenCode connections.
class OpenCodeConnectionsController
    extends AsyncNotifier<List<OpenCodeConnection>> {
  @override
  Future<List<OpenCodeConnection>> build() {
    return ref.watch(openCodeRepositoryProvider).connections();
  }

  /// Redeems a pairing payload and refreshes the saved list.
  Future<OpenCodeConnection> pair(
    OpenCodePairing pairing, {
    String? name,
  }) async {
    return _run(() async {
      final connection = await ref
          .read(openCodeRepositoryProvider)
          .pair(pairing, name: _cleanName(name));
      await _reload();
      return connection;
    });
  }

  /// Connects with a server URL and the service password.
  Future<OpenCodeConnection> connectManual({
    required String baseUrl,
    required String password,
    String? name,
  }) async {
    return _run(() async {
      final connection = await ref
          .read(openCodeRepositoryProvider)
          .connectManual(
            baseUrl: baseUrl,
            password: password,
            name: _cleanName(name),
          );
      await _reload();
      return connection;
    });
  }

  /// Deletes a saved connection and its token.
  Future<void> delete(String id) async {
    await _run(() async {
      await ref.read(openCodeRepositoryProvider).delete(id);
      final current = state.value;
      if (current != null && ref.mounted) {
        state = AsyncData([
          for (final connection in current)
            if (connection.id != id) connection,
        ]);
      }
    });
  }

  /// Reloads the list and surfaces failures in the provider state.
  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    state = const AsyncLoading();
    try {
      final connections = await ref
          .read(openCodeRepositoryProvider)
          .connections();
      if (ref.mounted) {
        state = AsyncData(connections);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(_asFailure(error), stackTrace);
      }
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on OpenCodeFailure {
      rethrow;
    } catch (error) {
      throw _asFailure(error);
    }
  }

  Future<void> _reload() async {
    final connections = await ref
        .read(openCodeRepositoryProvider)
        .connections();
    if (ref.mounted) {
      state = AsyncData(connections);
    }
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
