import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mcp_server_repository.dart';
import '../../domain/entities/mcp.dart';

class McpServerView {
  const McpServerView({
    required this.server,
    this.tools = const [],
    this.status = McpConnectionStatus.disconnected,
    this.error,
  });

  final McpServer server;
  final List<McpTool> tools;
  final McpConnectionStatus status;
  final McpFailure? error;

  McpServerView copyWith({
    McpServer? server,
    List<McpTool>? tools,
    McpConnectionStatus? status,
    McpFailure? error,
    bool clearError = false,
  }) {
    return McpServerView(
      server: server ?? this.server,
      tools: tools ?? this.tools,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
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
    for (final server in servers) {
      final tools = await ref
          .read(mcpServerRepositoryProvider)
          .toolsFor(server.id);
      views.add(McpServerView(server: server, tools: tools));
    }
    return McpConnectionsState(servers: views);
  }

  Future<void> reload() async {
    final servers = await ref.read(mcpServerRepositoryProvider).listServers();
    final views = <McpServerView>[];
    for (final server in servers) {
      final tools = await ref
          .read(mcpServerRepositoryProvider)
          .toolsFor(server.id);
      views.add(McpServerView(server: server, tools: tools));
    }
    state = AsyncData(McpConnectionsState(servers: views));
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

  Future<void> saveHeaders(String serverId, Map<String, String> headers) async {
    await ref.read(mcpServerRepositoryProvider).saveHeaders(serverId, headers);
    _update(
      serverId,
      (view) => view.copyWith(
        status: McpConnectionStatus.disconnected,
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
