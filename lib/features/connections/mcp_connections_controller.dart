import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mcp/mcp_oauth.dart';
import '../../data/repositories/mcp_server_repository.dart';
import '../../domain/entities/mcp.dart';
import '../../domain/entities/mcp_oauth.dart';

class McpServerView {
  const McpServerView({
    required this.server,
    this.tools = const [],
    this.status = McpConnectionStatus.disconnected,
    this.error,
    this.oauthConnected = false,
  });

  final McpServer server;
  final List<McpTool> tools;
  final McpConnectionStatus status;
  final McpFailure? error;
  final bool oauthConnected;

  McpServerView copyWith({
    McpServer? server,
    List<McpTool>? tools,
    McpConnectionStatus? status,
    McpFailure? error,
    bool clearError = false,
    bool? oauthConnected,
  }) {
    return McpServerView(
      server: server ?? this.server,
      tools: tools ?? this.tools,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      oauthConnected: oauthConnected ?? this.oauthConnected,
    );
  }
}

class McpConnectionsState {
  const McpConnectionsState({required this.servers});

  final List<McpServerView> servers;

  McpServerView? byId(String id) {
    for (final server in servers) {
      if (server.server.id == id) {
        return server;
      }
    }
    return null;
  }

  McpConnectionsState copyWith({List<McpServerView>? servers}) {
    return McpConnectionsState(servers: servers ?? this.servers);
  }
}

final mcpConnectionsControllerProvider =
    AsyncNotifierProvider<McpConnectionsController, McpConnectionsState>(
      McpConnectionsController.new,
    );

class McpConnectionsController extends AsyncNotifier<McpConnectionsState> {
  @override
  Future<McpConnectionsState> build() async {
    final servers = await ref.read(mcpServerRepositoryProvider).listServers();
    final views = <McpServerView>[];
    final repository = ref.read(mcpServerRepositoryProvider);
    for (final server in servers) {
      final tools = await repository.toolsFor(server.id);
      views.add(
        McpServerView(
          server: server,
          tools: tools,
          oauthConnected: await repository.hasOAuthToken(server.id),
        ),
      );
    }
    return McpConnectionsState(servers: views);
  }

  Future<void> reload() async {
    final servers = await ref.read(mcpServerRepositoryProvider).listServers();
    final views = <McpServerView>[];
    final repository = ref.read(mcpServerRepositoryProvider);
    for (final server in servers) {
      final tools = await repository.toolsFor(server.id);
      views.add(
        McpServerView(
          server: server,
          tools: tools,
          oauthConnected: await repository.hasOAuthToken(server.id),
        ),
      );
    }
    state = AsyncData(McpConnectionsState(servers: views));
  }

  /// Opens the browser OAuth flow and caches discovered tools.
  Future<void> connectOAuth(String serverId) async {
    _update(
      serverId,
      (view) =>
          view.copyWith(status: McpConnectionStatus.checking, clearError: true),
    );
    try {
      final tools = await ref
          .read(mcpServerRepositoryProvider)
          .authorizeOAuth(serverId);
      _update(
        serverId,
        (view) => view.copyWith(
          tools: tools,
          status: McpConnectionStatus.connected,
          oauthConnected: true,
          clearError: true,
        ),
      );
    } on McpOAuthException catch (error) {
      _update(
        serverId,
        (view) => view.copyWith(
          status: McpConnectionStatus.needsAuth,
          error: McpFailure(McpFailureKind.unauthorized, error.message),
        ),
      );
      rethrow;
    } on McpFailure catch (error) {
      _update(
        serverId,
        (view) => view.copyWith(
          status: error.kind == McpFailureKind.unauthorized
              ? McpConnectionStatus.needsAuth
              : McpConnectionStatus.error,
          error: error,
        ),
      );
      rethrow;
    } catch (error) {
      final failure = McpFailure(McpFailureKind.protocol, error.toString());
      _update(
        serverId,
        (view) =>
            view.copyWith(status: McpConnectionStatus.error, error: failure),
      );
      throw failure;
    }
  }

  /// Removes the browser OAuth token for a server.
  Future<void> disconnectOAuth(String serverId) async {
    await ref.read(mcpServerRepositoryProvider).clearOAuth(serverId);
    _update(
      serverId,
      (view) => view.copyWith(
        oauthConnected: false,
        status: McpConnectionStatus.disconnected,
        clearError: true,
      ),
    );
  }

  Future<void> test(String serverId) async {
    _update(
      serverId,
      (view) =>
          view.copyWith(status: McpConnectionStatus.checking, clearError: true),
    );
    try {
      final tools = await ref
          .read(mcpServerRepositoryProvider)
          .refreshTools(serverId);
      _update(
        serverId,
        (view) => view.copyWith(
          tools: tools,
          status: McpConnectionStatus.connected,
          clearError: true,
        ),
      );
    } on McpFailure catch (error) {
      _update(
        serverId,
        (view) => view.copyWith(
          status: error.kind == McpFailureKind.unauthorized
              ? McpConnectionStatus.needsAuth
              : McpConnectionStatus.error,
          error: error,
        ),
      );
    } catch (error) {
      _update(
        serverId,
        (view) => view.copyWith(
          status: McpConnectionStatus.error,
          error: McpFailure(McpFailureKind.protocol, error.toString()),
        ),
      );
    }
  }

  Future<void> setEnabled(String serverId, bool enabled) async {
    await ref.read(mcpServerRepositoryProvider).setEnabled(serverId, enabled);
    _update(
      serverId,
      (view) => view.copyWith(
        server: view.server.copyWith(enabled: enabled),
        status: enabled ? view.status : McpConnectionStatus.disconnected,
        clearError: !enabled,
      ),
    );
  }

  Future<Map<String, String>> headersFor(String serverId) {
    return ref.read(mcpServerRepositoryProvider).headersFor(serverId);
  }

  Future<McpOAuthClientConfig?> oauthClientFor(String serverId) {
    return ref.read(mcpServerRepositoryProvider).oauthClientFor(serverId);
  }

  Future<void> saveOAuthClient(
    String serverId,
    McpOAuthClientConfig config,
  ) async {
    await ref
        .read(mcpServerRepositoryProvider)
        .saveOAuthClient(serverId, config);
    _update(
      serverId,
      (view) => view.copyWith(
        oauthConnected: false,
        status: McpConnectionStatus.disconnected,
        clearError: true,
      ),
    );
  }

  Future<void> clearOAuthClient(String serverId) async {
    await ref.read(mcpServerRepositoryProvider).clearOAuthClient(serverId);
    _update(
      serverId,
      (view) => view.copyWith(
        oauthConnected: false,
        status: McpConnectionStatus.disconnected,
        clearError: true,
      ),
    );
  }

  Future<void> saveHeaders(String serverId, Map<String, String> headers) async {
    await ref.read(mcpServerRepositoryProvider).saveHeaders(serverId, headers);
    _update(
      serverId,
      (view) => view.copyWith(
        status: McpConnectionStatus.disconnected,
        oauthConnected: false,
        clearError: true,
      ),
    );
  }

  void _update(String serverId, McpServerView Function(McpServerView) update) {
    if (!ref.mounted) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        servers: [
          for (final view in current.servers)
            if (view.server.id == serverId) update(view) else view,
        ],
      ),
    );
  }
}
