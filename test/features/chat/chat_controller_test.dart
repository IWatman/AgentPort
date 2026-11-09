import 'dart:async';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/api/openai_compatible_client.dart';
import 'package:agentport/data/mcp/mcp_credentials.dart';
import 'package:agentport/data/repositories/conversation_repository.dart';
import 'package:agentport/data/repositories/mcp_server_repository.dart';
import 'package:agentport/data/repositories/provider_repository.dart';
import 'package:agentport/domain/entities/ai_provider.dart';
import 'package:agentport/domain/entities/chat_failure.dart';
import 'package:agentport/domain/entities/chat_message.dart';
import 'package:agentport/domain/entities/mcp.dart';
import 'package:agentport/features/chat/chat_controller.dart';
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

class _FakeClient extends OpenAiCompatibleClient {
  _FakeClient({this.deltas = const [], this.hold = false, this.error});

  final List<ChatDelta> deltas;
  final bool hold;
  final Object? error;
  int calls = 0;
  final List<List<ChatRequestMessage>> requests = [];
  final List<String> models = [];

  @override
  Stream<ChatDelta> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatRequestMessage> messages,
    List<ChatToolDefinition> tools = const [],
  }) {
    calls++;
    requests.add(List.of(messages));
    models.add(model);
    if (error != null) {
      return Stream.error(error!);
    }
    if (!hold) {
      return Stream.fromIterable(deltas);
    }
    final controller = StreamController<ChatDelta>();
    controller.onListen = () async {
      for (final delta in deltas) {
        controller.add(delta);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    };
    return controller.stream;
  }
}

class _ControlledClient extends OpenAiCompatibleClient {
  final controller = StreamController<ChatDelta>();
  int calls = 0;

  @override
  Stream<ChatDelta> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatRequestMessage> messages,
    List<ChatToolDefinition> tools = const [],
  }) {
    calls++;
    return controller.stream;
  }
}

class _ToolFakeClient extends OpenAiCompatibleClient {
  int calls = 0;
  final List<List<ChatRequestMessage>> requests = [];
  final String toolName;

  _ToolFakeClient({required this.toolName});

  @override
  Stream<ChatDelta> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatRequestMessage> messages,
    List<ChatToolDefinition> tools = const [],
  }) {
    calls++;
    requests.add(List.of(messages));
    if (calls == 1) {
      return Stream.fromIterable([
        ChatDelta(
          toolCalls: [
            ChatToolCallDelta(
              index: 0,
              id: 'call-1',
              name: toolName,
              arguments: '{"query":"flutter"}',
            ),
          ],
          finishReason: 'tool_calls',
        ),
      ]);
    }
    return Stream.fromIterable(const [
      ChatDelta(content: 'Tool finished.', finishReason: 'stop'),
    ]);
  }
}

class _FakeMcpRepository extends McpServerRepository {
  _FakeMcpRepository(AppDatabase database, SecureStore secureStore, this.tools)
    : super(database, McpCredentialStore(secureStore));

  final List<McpTool> tools;
  final List<({String serverId, String toolName, Map<String, Object?> args})>
  calls = [];

  @override
  Future<Map<String, List<McpTool>>> allTools() async => {'server': tools};

  @override
  Future<McpToolResult> callTool({
    required String serverId,
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    calls.add((serverId: serverId, toolName: toolName, args: arguments));
    return const McpToolResult(content: 'doc result');
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not met in time.');
}

void main() {
  late AppDatabase database;
  late _MemorySecureStore secureStore;
  late ProviderRepository providers;
  late ConversationRepository conversations;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secureStore = _MemorySecureStore();
    providers = ProviderRepository(database, secureStore);
    conversations = ConversationRepository(database);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<AiProvider> createProvider() {
    return providers.create(
      name: 'DeepSeek',
      type: AiProviderType.deepSeek,
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
      apiKey: 'secret',
    );
  }

  ProviderContainer createContainer(
    OpenAiCompatibleClient client, {
    McpServerRepository? mcpRepository,
  }) {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(secureStore),
        openAiCompatibleClientProvider.overrideWithValue(client),
        if (mcpRepository != null)
          mcpServerRepositoryProvider.overrideWithValue(mcpRepository),
      ],
    );
    return container;
  }

  Future<ChatSessionState> openChat(
    ProviderContainer container,
    String conversationId,
  ) async {
    final subscription = container.listen(
      chatControllerProvider(conversationId),
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    return container.read(chatControllerProvider(conversationId).future);
  }

  test('streams an assistant reply and persists it', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _FakeClient(
      deltas: const [
        ChatDelta(reasoning: 'thinking'),
        ChatDelta(content: 'Hel'),
        ChatDelta(content: 'lo', finishReason: 'stop'),
      ],
    );
    container = createContainer(client);
    await openChat(container, conversation.id);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    await notifier.send('Hello there');

    final state = container
        .read(chatControllerProvider(conversation.id))
        .value!;
    expect(client.calls, 1);
    expect(state.streaming, isFalse);
    expect(state.failure, isNull);
    expect(state.messages, hasLength(2));
    expect(state.messages.first.role, ChatRole.user);
    expect(state.messages.last.content, 'Hello');
    expect(state.messages.last.reasoning, 'thinking');
    expect(state.messages.last.status, ChatMessageStatus.complete);
    expect(state.conversation.title, 'Hello there');

    final stored = await conversations.messages(conversation.id);
    expect(stored, hasLength(2));
    expect(stored.last.content, 'Hello');
  });

  test('sends image and text attachments to the model', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _FakeClient(deltas: const [ChatDelta(content: 'ok')]);
    container = createContainer(client);
    await openChat(container, conversation.id);

    await container
        .read(chatControllerProvider(conversation.id).notifier)
        .send(
          'Describe this',
          attachments: const [
            ChatMessageAttachment(
              name: 'photo.jpg',
              mimeType: 'image/jpeg',
              bytesBase64: 'aGVsbG8=',
            ),
            ChatMessageAttachment(
              name: 'notes.txt',
              mimeType: 'text/plain',
              textContent: 'file body',
            ),
          ],
        );

    final messages = client.requests.single;
    final user = messages.lastWhere((message) => message.role == 'user');
    expect(user.content, contains('file body'));
    expect(user.contentParts, hasLength(2));
    expect(user.contentParts.first['type'], 'text');
    expect(user.contentParts.last['type'], 'image_url');
    expect(
      (user.contentParts.last['image_url'] as Map)['url'],
      'data:image/jpeg;base64,aGVsbG8=',
    );

    final stored = await conversations.messages(conversation.id);
    expect(stored.first.attachments, hasLength(2));
  });

  test('sends an image without a caption', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _FakeClient(deltas: const [ChatDelta(content: 'ok')]);
    container = createContainer(client);
    await openChat(container, conversation.id);

    await container
        .read(chatControllerProvider(conversation.id).notifier)
        .send(
          '',
          attachments: const [
            ChatMessageAttachment(
              name: 'photo.png',
              mimeType: 'image/png',
              bytesBase64: 'aW1hZ2U=',
            ),
          ],
        );

    final user = client.requests.single.lastWhere(
      (message) => message.role == 'user',
    );
    expect(user.content, isEmpty);
    expect(user.contentParts, hasLength(1));
    expect(user.contentParts.single['type'], 'image_url');
  });

  test('uses a per-conversation model override', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _FakeClient(deltas: const [ChatDelta(content: 'ok')]);
    container = createContainer(client);
    await openChat(container, conversation.id);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    await notifier.selectModel('deepseek-reasoner');
    await notifier.send('Hello');

    expect(client.models.single, 'deepseek-reasoner');
    expect(
      (await conversations.get(conversation.id))?.model,
      'deepseek-reasoner',
    );

    await notifier.selectProvider(provider);
    expect((await conversations.get(conversation.id))?.model, isNull);

    await notifier.selectModel(null);
    await notifier.send('Again');
    expect(client.models.last, provider.model);
  });

  test('stop keeps the partial reply as stopped', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _FakeClient(
      hold: true,
      deltas: const [ChatDelta(content: 'Partial answer')],
    );
    container = createContainer(client);
    await openChat(container, conversation.id);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    final sendFuture = notifier.send('Hello');
    await _waitUntil(() {
      final messages = container
          .read(chatControllerProvider(conversation.id))
          .value
          ?.messages;
      return messages != null &&
          messages.isNotEmpty &&
          messages.last.content == 'Partial answer';
    });

    await notifier.stop();
    await sendFuture;

    final state = container
        .read(chatControllerProvider(conversation.id))
        .value!;
    expect(state.streaming, isFalse);
    expect(state.messages.last.status, ChatMessageStatus.stopped);
    expect(state.messages.last.content, 'Partial answer');

    final stored = await conversations.messages(conversation.id);
    expect(stored.last.status, ChatMessageStatus.stopped);
  });

  test('reports a missing API key without adding messages', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    secureStore.values.remove(provider.apiKeyRef);
    final client = _FakeClient(deltas: const [ChatDelta(content: 'unused')]);
    container = createContainer(client);
    await openChat(container, conversation.id);

    await container
        .read(chatControllerProvider(conversation.id).notifier)
        .send('Hello');

    final state = container
        .read(chatControllerProvider(conversation.id))
        .value!;
    expect(client.calls, 0);
    expect(state.messages, isEmpty);
    expect(state.failure?.kind, ChatFailureKind.missingApiKey);
    expect(state.streaming, isFalse);
  });

  test('invokes a read-only MCP tool and sends the result back', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final mcp = _FakeMcpRepository(database, secureStore, const [
      McpTool(
        serverId: 'server',
        name: 'search_docs',
        description: 'Search docs',
        inputSchema: {'type': 'object'},
        needsApproval: false,
      ),
    ]);
    final client = _ToolFakeClient(toolName: 'mcp__server__search_docs');
    container = createContainer(client, mcpRepository: mcp);
    await openChat(container, conversation.id);

    await container
        .read(chatControllerProvider(conversation.id).notifier)
        .send('Find docs');

    expect(client.calls, 2);
    expect(mcp.calls, hasLength(1));
    expect(mcp.calls.single.serverId, 'server');
    expect(mcp.calls.single.toolName, 'search_docs');
    expect(mcp.calls.single.args['query'], 'flutter');

    final secondRequest = client.requests[1];
    final toolMessage = secondRequest.lastWhere(
      (message) => message.role == 'tool',
    );
    expect(toolMessage.toolCallId, 'call-1');
    expect(toolMessage.content, 'doc result');

    final state = container
        .read(chatControllerProvider(conversation.id))
        .value!;
    expect(state.messages.last.content, 'Tool finished.');
  });

  test('asks for approval before running a write tool', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final mcp = _FakeMcpRepository(database, secureStore, const [
      McpTool(
        serverId: 'server',
        name: 'write_file',
        description: 'Write a file',
        inputSchema: {'type': 'object'},
        needsApproval: true,
      ),
    ]);
    final client = _ToolFakeClient(toolName: 'mcp__server__write_file');
    container = createContainer(client, mcpRepository: mcp);
    await openChat(container, conversation.id);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    final sendFuture = notifier.send('Write a file');
    await _waitUntil(
      () =>
          container
              .read(chatControllerProvider(conversation.id))
              .value
              ?.pendingApproval !=
          null,
    );
    final pending = container
        .read(chatControllerProvider(conversation.id))
        .value!
        .pendingApproval!;
    expect(pending.toolName, 'write_file');
    expect(pending.arguments, contains('flutter'));

    await notifier.resolveToolApproval(false);
    await sendFuture;

    expect(mcp.calls, isEmpty);
    final secondRequest = client.requests[1];
    final toolMessage = secondRequest.lastWhere(
      (message) => message.role == 'tool',
    );
    expect(toolMessage.content, contains('permission denied'));
  });

  test('keeps generating after the chat screen is closed', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final client = _ControlledClient();
    container = createContainer(client);

    final subscription = container.listen(
      chatControllerProvider(conversation.id),
      (previous, next) {},
      fireImmediately: true,
    );
    await container.read(chatControllerProvider(conversation.id).future);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    final sendFuture = notifier.send('Hello');
    await _waitUntil(() => client.calls == 1 && client.controller.hasListener);

    subscription.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(client.controller.hasListener, isTrue);

    client.controller.add(const ChatDelta(content: 'Background answer'));
    await client.controller.close();
    await sendFuture;

    final stored = await conversations.messages(conversation.id);
    expect(stored, hasLength(2));
    expect(stored.last.content, 'Background answer');
    expect(stored.last.status, ChatMessageStatus.complete);
  });

  test('retry removes the failed assistant reply and streams again', () async {
    final provider = await createProvider();
    final conversation = await conversations.create(providerId: provider.id);
    final failingClient = _FakeClient(
      error: const ChatFailure(ChatFailureKind.server),
    );
    container = createContainer(failingClient);
    await openChat(container, conversation.id);

    final notifier = container.read(
      chatControllerProvider(conversation.id).notifier,
    );
    await notifier.send('Hello');

    var state = container.read(chatControllerProvider(conversation.id)).value!;
    expect(state.failure?.kind, ChatFailureKind.server);
    expect(state.messages.single.isUser, isTrue);

    final retryClient = _FakeClient(
      deltas: const [ChatDelta(content: 'Recovered')],
    );
    container.dispose();
    container = createContainer(retryClient);
    await openChat(container, conversation.id);
    await container
        .read(chatControllerProvider(conversation.id).notifier)
        .retry();

    state = container.read(chatControllerProvider(conversation.id)).value!;
    expect(state.failure, isNull);
    expect(state.messages, hasLength(2));
    expect(state.messages.last.content, 'Recovered');

    final stored = await conversations.messages(conversation.id);
    expect(stored, hasLength(2));
    expect(stored.last.content, 'Recovered');
  });
}
