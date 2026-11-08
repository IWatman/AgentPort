import 'dart:async';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/opencode/opencode_client.dart';
import 'package:agentport/data/repositories/opencode_repository.dart';
import 'package:agentport/domain/entities/opencode.dart';
import 'package:agentport/features/opencode/opencode_projects_controller.dart';
import 'package:agentport/features/opencode/opencode_session_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStore extends SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeOpenCodeClient extends OpenCodeClient {
  _FakeOpenCodeClient() : super(baseUrl: 'https://example.com', token: 'token');

  final StreamController<OpenCodeEvent> eventsController =
      StreamController<OpenCodeEvent>.broadcast();
  final List<String> sentPrompts = [];
  final List<String> interruptedSessions = [];
  final List<OpenCodeModelRef> selectedModels = [];
  final List<String> selectedAgents = [];
  final List<(String, String)> sentCommands = [];
  final List<(String, String)> searchedFiles = [];
  final List<String> renamedSessions = [];
  final List<String> deletedSessions = [];
  final List<OpenCodeAgent> agentList = const [
    OpenCodeAgent(id: 'build', name: 'Build'),
    OpenCodeAgent(id: 'plan', name: 'Plan'),
  ];
  final List<OpenCodeModel> modelList = const [
    OpenCodeModel(
      id: 'deepseek-chat',
      providerId: 'deepseek',
      name: 'DeepSeek Chat',
    ),
    OpenCodeModel(id: 'fast', providerId: 'local', name: 'Fast'),
  ];
  List<OpenCodeMessage> history = [];
  final List<String> createdDirectories = [];
  final List<OpenCodeProject> projectList = const [
    OpenCodeProject(
      id: 'project-1',
      directory: r'C:\Users\dushc\Desktop\AgentPort',
      vcs: 'git',
    ),
  ];

  @override
  Stream<OpenCodeEvent> events() => eventsController.stream;

  @override
  Future<List<OpenCodeProject>> projects() async => projectList;

  @override
  Future<List<OpenCodeSession>> sessions({String? projectId}) async => [
    OpenCodeSession(
      id: 'session-1',
      title: 'Session',
      project: projectId ?? 'project-1',
      updatedAt: DateTime(2026, 1, 2, 3, 4),
    ),
  ];

  @override
  Future<OpenCodeSession> createSession({
    required String directory,
    String? title,
  }) async {
    createdDirectories.add(directory);
    return OpenCodeSession(
      id: 'session-new',
      title: title ?? 'Untitled session',
      project: 'project-1',
      updatedAt: DateTime(2026, 1, 2, 3, 5),
    );
  }

  @override
  Future<OpenCodeSession> session(String id) async {
    return OpenCodeSession(
      id: id,
      title: 'Session',
      project: 'agentport',
      directory: r'C:\repo',
      updatedAt: DateTime(2026, 1, 2, 3, 4),
    );
  }

  @override
  Future<List<OpenCodeCommand>> commands({String? directory}) async => const [
    OpenCodeCommand(name: 'review', description: 'Review changes'),
    OpenCodeCommand(name: 'goal'),
  ];

  @override
  Future<List<OpenCodeFileEntry>> findFiles(
    String query, {
    required String directory,
    int limit = 20,
  }) async {
    searchedFiles.add((query, directory));
    return const [OpenCodeFileEntry(path: 'lib/main.dart')];
  }

  @override
  Future<void> sendCommand(
    String id,
    String name, {
    String arguments = '',
  }) async {
    sentCommands.add((name, arguments));
  }

  @override
  Future<void> renameSession(String id, String title) async {
    renamedSessions.add(title);
  }

  @override
  Future<void> deleteSession(String id) async {
    deletedSessions.add(id);
  }

  @override
  Future<List<OpenCodeMessage>> messages(String id, {int pages = 1}) async =>
      List.of(history);

  @override
  Future<OpenCodeTranscript> transcript(String id, {int pages = 1}) async =>
      OpenCodeTranscript(messages: List.of(history));

  List<OpenCodePermissionRequest> permissionList = [];
  final List<(String, String)> permissionReplies = [];

  @override
  Future<List<OpenCodePermissionRequest>> permissions(String sessionId) async =>
      List.of(permissionList);

  @override
  Future<void> replyPermission({
    required String sessionId,
    required String requestId,
    required String decision,
  }) async {
    permissionReplies.add((requestId, decision));
    permissionList = permissionList
        .where((request) => request.id != requestId)
        .toList(growable: false);
  }

  @override
  Future<void> sendPrompt(String id, String prompt) async {
    sentPrompts.add(prompt);
  }

  @override
  Future<void> interrupt(String id) async {
    interruptedSessions.add(id);
  }

  @override
  Future<List<OpenCodeAgent>> agents({String? directory}) async => agentList;

  @override
  Future<List<OpenCodeModel>> models({String? directory}) async => modelList;

  @override
  Future<void> setAgent(String id, String agent) async {
    selectedAgents.add(agent);
  }

  @override
  Future<void> setModel(String id, OpenCodeModelRef model) async {
    selectedModels.add(model);
  }

  Future<void> close() => eventsController.close();
}

class _FakeOpenCodeRepository extends OpenCodeRepository {
  // The super parameters are private, so they cannot be forwarded with the
  // `super.` shorthand.
  // ignore: use_super_parameters
  _FakeOpenCodeRepository(
    AppDatabase database,
    SecureStore secureStore,
    this.client,
  ) : super(database, secureStore);

  final OpenCodeClient client;
  final OpenCodeConnection savedConnection = const OpenCodeConnection(
    id: 'connection-1',
    name: 'Home PC',
    baseUrl: 'https://example.com',
    tokenRef: 'token',
  );

  @override
  Future<OpenCodeConnection?> connection(String id) async {
    return id == savedConnection.id ? savedConnection : null;
  }

  @override
  Future<OpenCodeClient> clientFor(OpenCodeConnection connection) async {
    return client;
  }

  @override
  Future<void> touch(OpenCodeConnection connection) async {}
}

const _key = (connectionId: 'connection-1', sessionId: 'session-1');

void main() {
  late AppDatabase database;
  late _FakeOpenCodeClient client;
  late _FakeOpenCodeRepository repository;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    client = _FakeOpenCodeClient();
    repository = _FakeOpenCodeRepository(
      database,
      _MemorySecureStore(),
      client,
    );
    container = ProviderContainer(
      overrides: [openCodeRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    await client.close();
    await database.close();
  });

  Future<void> open() async {
    final provider = openCodeSessionControllerProvider(_key);
    final subscription = container.listen(
      provider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);
    // Let the controller start listening to the SSE stream.
    await pumpEventQueue();
  }

  OpenCodeSessionState state() =>
      container.read(openCodeSessionControllerProvider(_key)).value!;

  OpenCodeSessionController notifier() =>
      container.read(openCodeSessionControllerProvider(_key).notifier);

  Future<void> emit(OpenCodeEvent event) async {
    client.eventsController.add(event);
    await pumpEventQueue();
  }

  OpenCodeEvent event(String type, {Map<String, Object?> extra = const {}}) {
    return OpenCodeEvent(
      type: type,
      data: {'sessionID': 'session-1', ...extra},
    );
  }

  test('projects controller loads the server project list', () async {
    final provider = openCodeProjectsControllerProvider('connection-1');
    final subscription = container.listen(
      provider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final value = await container.read(provider.future);

    expect(value.connection.name, 'Home PC');
    expect(value.projects.single.name, 'AgentPort');
    expect(
      value.projects.single.directory,
      r'C:\Users\dushc\Desktop\AgentPort',
    );
  });

  test(
    'project sessions are filtered and new sessions use the directory',
    () async {
      const key = (connectionId: 'connection-1', projectId: 'project-1');
      final provider = openCodeProjectSessionsControllerProvider(key);
      final subscription = container.listen(
        provider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final value = await container.read(provider.future);
      expect(value.project.id, 'project-1');
      expect(value.sessions.single.id, 'session-1');

      final created = await container
          .read(provider.notifier)
          .createSession(title: 'Fresh');

      expect(created.id, 'session-new');
      expect(client.createdDirectories, [r'C:\Users\dushc\Desktop\AgentPort']);
      expect(container.read(provider).value!.sessions.first.id, 'session-new');
    },
  );

  test('refreshes the transcript when another client sends a prompt', () async {
    await open();
    client.history = [
      ...client.history,
      OpenCodeMessage(
        id: 'history-2',
        role: 'user',
        text: 'Sent from the web UI',
        createdAt: DateTime(2026, 1, 2, 3, 5),
      ),
    ];

    await emit(event('session.inbox.delivered'));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(state().messages.last.text, 'Sent from the web UI');
  });

  test('runs slash commands and searches files', () async {
    await open();

    final commands = await notifier().loadCommands();
    expect(commands.map((command) => command.name), ['review', 'goal']);

    await notifier().sendCommand('review', 'main');
    expect(client.sentCommands.single, ('review', 'main'));
    expect(state().messages.last.text, '/review main');

    final files = await notifier().searchFiles('main');
    expect(files.single.path, 'lib/main.dart');
    expect(client.searchedFiles.single, ('main', r'C:\repo'));
  });

  test('renames and deletes the current session', () async {
    await open();

    await notifier().rename('New title');
    expect(state().session.title, 'New title');
    expect(client.renamedSessions, ['New title']);

    await notifier().deleteSession();
    expect(client.deletedSessions, ['session-1']);
  });

  test('loads session details and history', () async {
    client.history = [
      OpenCodeMessage(
        id: 'history-1',
        role: 'user',
        text: 'Earlier',
        createdAt: DateTime(2026),
      ),
    ];

    await open();

    expect(state().session.title, 'Session');
    expect(state().connection.name, 'Home PC');
    expect(state().messages.single.text, 'Earlier');
    expect(state().busy, isFalse);
  });

  test('appends a sent prompt and folds streamed text on success', () async {
    await open();

    await notifier().send('Hello');

    var current = state();
    expect(client.sentPrompts, ['Hello']);
    expect(current.busy, isTrue);
    expect(current.messages.last.role, 'user');
    expect(current.messages.last.text, 'Hello');

    await emit(event('session.execution.started'));
    await emit(event('session.text.delta', extra: {'delta': 'Hi'}));
    await emit(event('session.text.delta', extra: {'delta': ' there'}));

    current = state();
    expect(current.busy, isTrue);
    expect(current.streamingText, 'Hi there');

    await emit(event('session.execution.succeeded'));

    current = state();
    expect(current.busy, isFalse);
    expect(current.streamingText, isEmpty);
    expect(current.messages, hasLength(2));
    expect(current.messages.last.role, 'assistant');
    expect(current.messages.last.text, 'Hi there');
  });

  test('ignores events from other sessions', () async {
    await open();
    await notifier().send('Hello');

    client.eventsController.add(
      const OpenCodeEvent(
        type: 'session.text.delta',
        data: {'sessionID': 'another', 'delta': 'wrong'},
      ),
    );
    await pumpEventQueue();

    expect(state().streamingText, isEmpty);
  });

  test('idle completes the turn and folds partial text', () async {
    await open();
    await notifier().send('Hello');
    await emit(event('session.text.delta', extra: {'delta': 'Partial'}));

    await emit(event('session.idle'));

    expect(state().busy, isFalse);
    expect(state().messages.last.text, 'Partial');
    expect(state().streamingText, isEmpty);
  });

  test('a failed execution reports an error', () async {
    await open();
    await notifier().send('Hello');
    await emit(event('session.text.delta', extra: {'delta': 'Half'}));

    await emit(
      event(
        'session.execution.failed',
        extra: {
          'error': {'message': 'model crashed'},
        },
      ),
    );

    final current = state();
    expect(current.busy, isFalse);
    expect(current.error?.kind, OpenCodeFailureKind.server);
    expect(current.messages.last.text, 'Half');
  });

  test('stop interrupts the session', () async {
    await open();
    await notifier().send('Hello');

    await notifier().stop();

    expect(client.interruptedSessions, ['session-1']);
  });

  test('tool events drive the active tool indicator', () async {
    await open();

    await emit(event('session.tool.started', extra: {'name': 'read_file'}));
    expect(state().activeTool, 'read_file');

    await emit(event('session.tool.succeeded', extra: {'name': 'read_file'}));
    expect(state().activeTool, isNull);
  });

  test('loads agents and models and switches the session', () async {
    await open();

    final agents = await notifier().loadAgents();
    final models = await notifier().loadModels();
    expect(agents, hasLength(2));
    expect(models, hasLength(2));

    await notifier().setAgent('plan');
    await notifier().setModel(models.last.ref);

    expect(client.selectedAgents, ['plan']);
    expect(client.selectedModels.single.id, 'fast');
    expect(state().agentId, 'plan');
    expect(state().model?.providerId, 'local');
  });

  test(
    'reload keeps pending local prompts without duplicating history',
    () async {
      await open();
      await notifier().send('Hello');

      client.history = [];
      await notifier().reload();
      await pumpEventQueue();

      expect(
        state().messages.where(
          (message) => message.isUser && message.text == 'Hello',
        ),
        hasLength(1),
      );

      client.history = [
        OpenCodeMessage(
          id: 'server-user',
          role: 'user',
          text: 'Hello',
          createdAt: DateTime(2026),
        ),
        OpenCodeMessage(
          id: 'server-assistant',
          role: 'assistant',
          text: 'Hi',
          createdAt: DateTime(2026),
        ),
      ];
      await notifier().reload();
      await pumpEventQueue();

      expect(state().messages, hasLength(2));
      expect(
        state().messages.where((message) => message.text == 'Hello'),
        hasLength(1),
      );
      expect(
        state().messages.where((message) => message.text == 'Hi'),
        hasLength(1),
      );
    },
  );

  test('loads and replies to permission requests', () async {
    client.permissionList = const [
      OpenCodePermissionRequest(
        id: 'per-1',
        sessionId: 'session-1',
        action: 'shell',
        resources: ['git push'],
        message: 'The agent wants to run a command.',
      ),
    ];

    await open();

    expect(state().permissions, hasLength(1));
    expect(state().permissions.single.action, 'shell');

    await notifier().replyPermission('per-1', 'once');
    await pumpEventQueue();

    expect(client.permissionReplies, [('per-1', 'once')]);
    expect(state().permissions, isEmpty);
  });

  test('permission events refresh the pending request list', () async {
    await open();
    expect(state().permissions, isEmpty);

    client.permissionList = const [
      OpenCodePermissionRequest(
        id: 'per-2',
        sessionId: 'session-1',
        action: 'edit',
        resources: ['lib/main.dart'],
      ),
    ];
    await emit(event('permission.asked'));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(state().permissions.single.id, 'per-2');
  });

  test('a dropped event stream marks the connection lost', () async {
    await open();

    await client.eventsController.close();
    await pumpEventQueue();

    expect(state().linkState, OpenCodeLinkState.disconnected);
    expect(state().error, isNotNull);
  });
}
