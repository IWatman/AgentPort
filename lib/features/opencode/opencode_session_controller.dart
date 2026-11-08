import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/opencode/opencode_client.dart';
import '../../data/repositories/opencode_repository.dart';
import '../../domain/entities/opencode.dart';

const _unset = Object();

/// Identifies one session screen: a connection and a server session id.
typedef OpenCodeSessionKey = ({String connectionId, String sessionId});

enum OpenCodeLinkState { connected, disconnected }

class OpenCodeSessionState {
  const OpenCodeSessionState({
    required this.connection,
    required this.session,
    required this.messages,
    this.streamingText = '',
    this.busy = false,
    this.linkState = OpenCodeLinkState.connected,
    this.error,
    this.activeTool,
    this.agentId,
    this.model,
  });

  final OpenCodeConnection connection;
  final OpenCodeSession session;
  final List<OpenCodeMessage> messages;
  final String streamingText;
  final bool busy;
  final OpenCodeLinkState linkState;
  final OpenCodeFailure? error;
  final String? activeTool;
  final String? agentId;
  final OpenCodeModelRef? model;

  bool get isConnected => linkState == OpenCodeLinkState.connected;

  OpenCodeSessionState copyWith({
    OpenCodeConnection? connection,
    OpenCodeSession? session,
    List<OpenCodeMessage>? messages,
    String? streamingText,
    bool? busy,
    OpenCodeLinkState? linkState,
    Object? error = _unset,
    Object? activeTool = _unset,
    bool clearTool = false,
    Object? agentId = _unset,
    Object? model = _unset,
  }) {
    return OpenCodeSessionState(
      connection: connection ?? this.connection,
      session: session ?? this.session,
      messages: messages ?? this.messages,
      streamingText: streamingText ?? this.streamingText,
      busy: busy ?? this.busy,
      linkState: linkState ?? this.linkState,
      error: identical(error, _unset) ? this.error : error as OpenCodeFailure?,
      activeTool: clearTool
          ? null
          : identical(activeTool, _unset)
          ? this.activeTool
          : activeTool as String?,
      agentId: identical(agentId, _unset) ? this.agentId : agentId as String?,
      model: identical(model, _unset) ? this.model : model as OpenCodeModelRef?,
    );
  }
}

final openCodeSessionControllerProvider =
    AsyncNotifierProvider.family<
      OpenCodeSessionController,
      OpenCodeSessionState,
      OpenCodeSessionKey
    >(OpenCodeSessionController.new, isAutoDispose: true);

/// Owns one OpenCode session: transcript, live event stream, and composer
/// actions.
class OpenCodeSessionController extends AsyncNotifier<OpenCodeSessionState> {
  OpenCodeSessionController(this.key);

  final OpenCodeSessionKey key;

  OpenCodeClient? _client;
  StreamSubscription<OpenCodeEvent>? _subscription;
  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  var _streamGeneration = 0;
  var _reconnectAttempts = 0;
  var _localSequence = 0;
  var _refreshingMessages = false;
  var _refreshPending = false;
  var _refreshAfterReconnect = false;
  var _disposed = false;

  @override
  Future<OpenCodeSessionState> build() async {
    _disposed = false;
    _streamGeneration++;
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    unawaited(_subscription?.cancel());
    _subscription = null;

    final repository = ref.watch(openCodeRepositoryProvider);
    final loaded = await _load(repository);
    _client = loaded.client;

    // Wait one event-loop turn so the provider has committed its data state
    // before the first SSE frame can arrive.
    unawaited(_startEventsSoon());
    ref.onDispose(_handleDispose);

    return loaded.state;
  }

  Future<void> _startEventsSoon() async {
    await Future<void>.delayed(Duration.zero);
    if (!ref.mounted || _disposed) {
      return;
    }
    _startEvents();
  }

  /// Reloads session details and messages, then reconnects the event stream.
  Future<void> reload() async {
    if (!ref.mounted) {
      return;
    }
    final previousMessages = state.value?.messages ?? const <OpenCodeMessage>[];
    state = const AsyncLoading();
    try {
      final repository = ref.read(openCodeRepositoryProvider);
      final loaded = await _load(repository);
      if (!ref.mounted) {
        return;
      }
      _streamGeneration++;
      _refreshTimer?.cancel();
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      await _subscription?.cancel();
      _subscription = null;
      _client = loaded.client;
      final messages = _mergeLocalMessages(
        previousMessages,
        loaded.state.messages,
      );
      state = AsyncData(loaded.state.copyWith(messages: messages));
      _startEvents();
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(_asFailure(error), stackTrace);
      }
    }
  }

  /// Sends a prompt and shows it immediately in the transcript.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final current = state.value;
    final client = _client;
    if (trimmed.isEmpty || current == null || current.busy || client == null) {
      return;
    }

    final message = OpenCodeMessage(
      id: _localId('user'),
      role: 'user',
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _emit(
      current.copyWith(
        messages: [...current.messages, message],
        busy: true,
        streamingText: '',
        error: null,
        clearTool: true,
      ),
    );

    try {
      await client.sendPrompt(key.sessionId, trimmed);
    } catch (error) {
      _setFailure(_asFailure(error), busy: false);
    }
  }

  /// Asks the server to stop the current generation.
  Future<void> stop() async {
    final client = _client;
    if (client == null) {
      return;
    }
    try {
      await client.interrupt(key.sessionId);
    } catch (error) {
      _setFailure(_asFailure(error), busy: false);
    }
  }

  Future<List<OpenCodeAgent>> loadAgents() async {
    final client = _client;
    if (client == null) {
      return const [];
    }
    try {
      return await client.agents();
    } catch (error) {
      final failure = _asFailure(error);
      _setFailure(failure);
      throw failure;
    }
  }

  Future<List<OpenCodeModel>> loadModels() async {
    final client = _client;
    if (client == null) {
      return const [];
    }
    try {
      return await client.models();
    } catch (error) {
      final failure = _asFailure(error);
      _setFailure(failure);
      throw failure;
    }
  }

  /// Switches the agent used by the session.
  Future<void> setAgent(String agentId) async {
    final client = _client;
    final current = state.value;
    final id = agentId.trim();
    if (client == null || current == null || id.isEmpty) {
      return;
    }
    try {
      await client.setAgent(key.sessionId, id);
      final latest = state.value;
      if (ref.mounted && latest != null) {
        _emit(latest.copyWith(agentId: id, error: null));
      }
    } catch (error) {
      final failure = _asFailure(error);
      _setFailure(failure);
      throw failure;
    }
  }

  /// Switches the model used by the session.
  Future<void> setModel(OpenCodeModelRef model) async {
    final client = _client;
    final current = state.value;
    if (client == null || current == null) {
      return;
    }
    try {
      await client.setModel(key.sessionId, model);
      final latest = state.value;
      if (ref.mounted && latest != null) {
        _emit(latest.copyWith(model: model, error: null));
      }
    } catch (error) {
      final failure = _asFailure(error);
      _setFailure(failure);
      throw failure;
    }
  }

  Future<_LoadedSession> _load(OpenCodeRepository repository) async {
    final connection = await repository.connection(key.connectionId);
    if (connection == null) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'The OpenCode connection no longer exists.',
      );
    }

    final client = await repository.clientFor(connection);
    final session = await client.session(key.sessionId);
    final messages = await client.messages(key.sessionId);
    return _LoadedSession(
      client: client,
      state: OpenCodeSessionState(
        connection: connection,
        session: session,
        messages: messages,
      ),
    );
  }

  void _startEvents() {
    final client = _client;
    if (client == null || _disposed || !ref.mounted) {
      return;
    }
    final generation = ++_streamGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = client.events().listen(
      (event) {
        if (generation == _streamGeneration) {
          _handleEvent(event);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation == _streamGeneration) {
          _handleStreamFailure(_asFailure(error));
        }
      },
      onDone: () {
        if (generation == _streamGeneration) {
          _handleStreamFailure(
            const OpenCodeFailure(
              OpenCodeFailureKind.network,
              detail: 'The OpenCode event stream ended.',
            ),
          );
        }
      },
      cancelOnError: true,
    );
  }

  void _handleEvent(OpenCodeEvent event) {
    if (!ref.mounted) {
      return;
    }
    var current = state.value;
    if (current == null) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    if (current.linkState != OpenCodeLinkState.connected ||
        current.error != null) {
      current = current.copyWith(
        linkState: OpenCodeLinkState.connected,
        error: null,
      );
      _emit(current);
    }

    if (_refreshAfterReconnect) {
      _refreshAfterReconnect = false;
      _scheduleMessageRefresh();
    }

    if (event.sessionId != key.sessionId) {
      return;
    }

    final payload = event.payload;
    switch (event.type) {
      case 'session.text.delta':
        final delta = payload['delta'];
        if (delta is String && delta.isNotEmpty) {
          _emit(
            current.copyWith(
              streamingText: '${current.streamingText}$delta',
              busy: true,
              linkState: OpenCodeLinkState.connected,
              error: null,
            ),
          );
        }
      case 'session.execution.started':
        _emit(
          current.copyWith(
            busy: true,
            streamingText: '',
            linkState: OpenCodeLinkState.connected,
            error: null,
            clearTool: true,
          ),
        );
      case 'session.execution.succeeded':
        _complete(current);
      case 'session.execution.failed':
        _complete(
          current,
          failure: OpenCodeFailure(
            OpenCodeFailureKind.server,
            detail: _payloadError(payload),
          ),
        );
      case 'session.execution.interrupted':
        _complete(current);
      case 'session.idle':
        _complete(current);
      case 'session.inbox.delivered':
      case 'session.inbox.enqueued':
      case 'session.inbox.cancelled':
      case 'session.message.content.updated':
        _scheduleMessageRefresh();
      default:
        if (event.type.startsWith('session.tool.')) {
          _handleToolEvent(current, event.type, payload);
        }
    }
  }

  void _handleToolEvent(
    OpenCodeSessionState current,
    String type,
    Map<String, Object?> payload,
  ) {
    final name = payload['name'] ?? payload['tool'];
    final label = name is String && name.trim().isNotEmpty ? name.trim() : null;
    final suffix = type.substring('session.tool.'.length).toLowerCase();
    final finished =
        suffix.contains('success') ||
        suffix.contains('succeed') ||
        suffix.contains('fail') ||
        suffix.contains('complete') ||
        suffix.contains('finish') ||
        suffix.contains('end');
    _emit(
      current.copyWith(
        activeTool: finished ? null : label,
        busy: finished ? current.busy : true,
      ),
    );
  }

  void _complete(OpenCodeSessionState current, {OpenCodeFailure? failure}) {
    var messages = current.messages;
    final text = current.streamingText;
    if (text.trim().isNotEmpty) {
      messages = [
        ...messages,
        OpenCodeMessage(
          id: _localId('assistant'),
          role: 'assistant',
          text: text,
          createdAt: DateTime.now(),
        ),
      ];
    }
    _emit(
      current.copyWith(
        messages: messages,
        streamingText: '',
        busy: false,
        linkState: OpenCodeLinkState.connected,
        error: failure,
        clearTool: true,
      ),
    );
  }

  void _handleStreamFailure(OpenCodeFailure failure) {
    if (!ref.mounted || _disposed) {
      return;
    }
    final current = state.value;
    if (current == null) {
      return;
    }
    var messages = current.messages;
    if (current.streamingText.trim().isNotEmpty) {
      messages = [
        ...messages,
        OpenCodeMessage(
          id: _localId('assistant'),
          role: 'assistant',
          text: current.streamingText,
          createdAt: DateTime.now(),
        ),
      ];
    }
    _emit(
      current.copyWith(
        messages: messages,
        streamingText: '',
        busy: false,
        linkState: OpenCodeLinkState.disconnected,
        error: failure,
        clearTool: true,
      ),
    );
    if (_shouldReconnect(failure)) {
      _scheduleReconnect();
    }
  }

  void _scheduleMessageRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_refreshMessages());
    });
  }

  Future<void> _refreshMessages() async {
    final client = _client;
    final current = state.value;
    if (client == null || current == null || _disposed || !ref.mounted) {
      return;
    }
    if (_refreshingMessages) {
      _refreshPending = true;
      return;
    }

    _refreshingMessages = true;
    try {
      final loaded = await client.messages(key.sessionId);
      if (!ref.mounted || _disposed) {
        return;
      }
      final latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData(
        latest.copyWith(messages: _mergeLocalMessages(latest.messages, loaded)),
      );
    } catch (_) {
      // A quiet refresh must not replace the visible transcript with an error.
    } finally {
      _refreshingMessages = false;
      if (_refreshPending) {
        _refreshPending = false;
        _scheduleMessageRefresh();
      }
    }
  }

  bool _shouldReconnect(OpenCodeFailure failure) {
    return switch (failure.kind) {
      OpenCodeFailureKind.network ||
      OpenCodeFailureKind.timeout ||
      OpenCodeFailureKind.server => true,
      _ => false,
    };
  }

  void _scheduleReconnect() {
    if (_disposed || !ref.mounted) {
      return;
    }
    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempts++;
    final seconds = switch (attempt) {
      0 => 2,
      1 => 5,
      2 => 10,
      3 => 20,
      _ => 30,
    };
    _refreshAfterReconnect = true;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_disposed || !ref.mounted) {
        return;
      }
      _startEvents();
    });
  }

  void _setFailure(OpenCodeFailure failure, {bool? busy}) {
    final current = state.value;
    if (current == null || !ref.mounted) {
      return;
    }
    _emit(current.copyWith(error: failure, busy: busy));
  }

  void _emit(OpenCodeSessionState next) {
    if (!ref.mounted || _disposed) {
      return;
    }
    if (state.hasValue) {
      state = AsyncData(next);
    }
  }

  /// Keeps locally displayed messages that the server transcript does not
  /// contain yet, without duplicating messages the server has accepted.
  List<OpenCodeMessage> _mergeLocalMessages(
    List<OpenCodeMessage> previous,
    List<OpenCodeMessage> loaded,
  ) {
    if (previous.isEmpty) {
      return loaded;
    }
    final known = {for (final message in loaded) _messageKey(message)};
    final pending = [
      for (final message in previous)
        if (message.id.startsWith('local-') &&
            !known.contains(_messageKey(message)))
          message,
    ];
    if (pending.isEmpty) {
      return loaded;
    }
    return [...loaded, ...pending];
  }

  String _messageKey(OpenCodeMessage message) {
    return '${message.role}\u0000${message.text.trim()}';
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

  String? _payloadError(Map<String, Object?> payload) {
    final value = payload['error'] ?? payload['message'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Map) {
      final message = value['message'] ?? value['detail'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  String _localId(String role) {
    _localSequence++;
    return 'local-$role-${DateTime.now().microsecondsSinceEpoch}-'
        '$_localSequence';
  }

  void _handleDispose() {
    _disposed = true;
    _streamGeneration++;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _client = null;
  }
}

class _LoadedSession {
  const _LoadedSession({required this.client, required this.state});

  final OpenCodeClient client;
  final OpenCodeSessionState state;
}
