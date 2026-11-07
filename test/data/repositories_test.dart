import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/repositories/conversation_repository.dart';
import 'package:agentport/data/repositories/provider_repository.dart';
import 'package:agentport/domain/entities/ai_provider.dart';
import 'package:agentport/domain/entities/chat_message.dart';
import 'package:drift/native.dart';
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

void main() {
  late AppDatabase database;
  late _MemorySecureStore secureStore;
  late ProviderRepository providers;
  late ConversationRepository conversations;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secureStore = _MemorySecureStore();
    providers = ProviderRepository(database, secureStore);
    conversations = ConversationRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ProviderRepository', () {
    test('creates a provider and keeps the key out of the database', () async {
      final provider = await providers.create(
        name: 'DeepSeek',
        type: AiProviderType.deepSeek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'secret',
      );

      expect(provider.apiKeyRef, isNotEmpty);
      expect(secureStore.values[provider.apiKeyRef], 'secret');
      expect(await providers.apiKeyFor(provider), 'secret');

      final listed = await providers.list();
      expect(listed, hasLength(1));
      expect(listed.single.name, 'DeepSeek');
      expect(listed.single.type, AiProviderType.deepSeek);
    });

    test('updates fields and optionally rotates the key', () async {
      final provider = await providers.create(
        name: 'DeepSeek',
        type: AiProviderType.deepSeek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'old',
      );

      await providers.update(
        provider: provider,
        name: 'Proxy',
        type: AiProviderType.openAiCompatible,
        baseUrl: 'https://proxy.example.com/v1',
        model: 'custom-model',
        apiKey: null,
      );

      expect(await providers.apiKeyFor(provider), 'old');
      final updated = await providers.get(provider.id);
      expect(updated?.name, 'Proxy');
      expect(updated?.type, AiProviderType.openAiCompatible);
      expect(updated?.model, 'custom-model');

      await providers.update(
        provider: provider,
        name: 'Proxy',
        type: AiProviderType.openAiCompatible,
        baseUrl: 'https://proxy.example.com/v1',
        model: 'custom-model',
        apiKey: 'new',
      );
      expect(await providers.apiKeyFor(provider), 'new');
    });

    test('deletes the key and clears conversation references', () async {
      final provider = await providers.create(
        name: 'DeepSeek',
        type: AiProviderType.deepSeek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'secret',
      );
      final conversation = await conversations.create(
        providerId: provider.id,
      );

      await providers.delete(provider);

      expect(await providers.list(), isEmpty);
      expect(secureStore.values, isEmpty);
      expect((await conversations.get(conversation.id))?.providerId, isNull);
    });
  });

  group('ConversationRepository', () {
    test('creates, renames, and orders conversations by activity', () async {
      final first = await conversations.create();
      final second = await conversations.create();

      await conversations.rename(first.id, 'First');
      await conversations.touch(first.id);

      final listed = await conversations.list();
      expect(listed.map((item) => item.id), [first.id, second.id]);
      expect(listed.first.title, 'First');
    });

    test('stores messages in chronological order and deletes them', () async {
      final conversation = await conversations.create();
      final now = DateTime.now();
      final user = ChatMessage(
        id: conversations.newMessageId(),
        conversationId: conversation.id,
        role: ChatRole.user,
        content: 'Hello',
        reasoning: null,
        status: ChatMessageStatus.complete,
        createdAt: now,
      );
      final assistant = ChatMessage(
        id: conversations.newMessageId(),
        conversationId: conversation.id,
        role: ChatRole.assistant,
        content: 'Hi',
        reasoning: 'thinking',
        status: ChatMessageStatus.stopped,
        createdAt: now.add(const Duration(seconds: 1)),
      );

      await conversations.insertMessage(assistant);
      await conversations.insertMessage(user);

      final messages = await conversations.messages(conversation.id);
      expect(messages.map((message) => message.content), ['Hello', 'Hi']);
      expect(messages.last.reasoning, 'thinking');
      expect(messages.last.status, ChatMessageStatus.stopped);

      await conversations.deleteMessages([user.id]);
      expect(await conversations.messages(conversation.id), hasLength(1));

      await conversations.delete(conversation.id);
      expect(await conversations.messages(conversation.id), isEmpty);
    });

    test('sets and clears the provider', () async {
      final provider = await providers.create(
        name: 'DeepSeek',
        type: AiProviderType.deepSeek,
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'secret',
      );
      final conversation = await conversations.create(
        providerId: provider.id,
      );

      await conversations.setProvider(conversation.id, null);
      expect((await conversations.get(conversation.id))?.providerId, isNull);

      await conversations.setProvider(conversation.id, provider.id);
      expect(
        (await conversations.get(conversation.id))?.providerId,
        provider.id,
      );
    });
  });
}
