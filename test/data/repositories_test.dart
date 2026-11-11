import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/auth/provider_oauth.dart';
import 'package:agentport/data/repositories/conversation_repository.dart';
import 'package:agentport/data/repositories/provider_repository.dart';
import 'package:agentport/domain/entities/ai_provider.dart';
import 'package:agentport/domain/entities/chat_failure.dart';
import 'package:agentport/domain/entities/chat_message.dart';
import 'package:agentport/domain/entities/provider_oauth.dart';
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

class _FakeOAuthFlow extends ProviderOAuthFlow {
  _FakeOAuthFlow(this.refreshed);

  final ProviderOAuthCredential refreshed;
  int refreshCalls = 0;

  @override
  Future<ProviderOAuthCredential> refreshChatGpt(
    ProviderOAuthCredential credential,
  ) async {
    refreshCalls++;
    return refreshed;
  }
}

ProviderOAuthCredential _chatGptCredential({
  String accessToken = 'access-1',
  DateTime? expiresAt,
}) {
  return ProviderOAuthCredential(
    method: ProviderAuthMethod.chatGpt,
    accessToken: accessToken,
    clientId: 'client-1',
    hostId: 'urn:uuid:host-1',
    subject: 'subject-1',
    issuer: ProviderOAuthFlow.openAiIssuer,
    refreshToken: 'refresh-1',
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
  );
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
      final conversation = await conversations.create(providerId: provider.id);

      await providers.delete(provider);

      expect(await providers.list(), isEmpty);
      expect(secureStore.values, isEmpty);
      expect((await conversations.get(conversation.id))?.providerId, isNull);
    });
  });

  group('ProviderRepository accounts', () {
    test('creates an account provider without storing an API key', () async {
      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      expect(provider.usesAccount, isTrue);
      expect(provider.usesResponses, isTrue);
      expect(secureStore.values[provider.apiKeyRef], isNull);
      expect(secureStore.values['${provider.apiKeyRef}.oauth'], isNotNull);
      expect(await providers.apiKeyFor(provider), 'access-1');
      expect(
        (await providers.oauthCredentialFor(provider))?.method,
        ProviderAuthMethod.chatGpt,
      );
    });

    test('requires credentials for account providers', () async {
      await expectLater(
        providers.create(
          name: 'ChatGPT',
          type: AiProviderType.openAiCompatible,
          baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
          model: 'gpt-5',
          apiKey: '',
          authMethod: ProviderAuthMethod.chatGpt,
        ),
        throwsA(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.badRequest,
          ),
        ),
      );
    });

    test('pins account credentials to the official endpoint', () async {
      for (final url in [
        'https://api.openai.com.evil/v1',
        'http://api.openai.com/v1',
        'https://api.openai.com:8443/v1',
        'https://api.openai.com/v1?redirect=1',
        'https://api.openai.com/v1#fragment',
      ]) {
        await expectLater(
          providers.create(
            name: 'ChatGPT',
            type: AiProviderType.openAiCompatible,
            baseUrl: url,
            model: 'gpt-5',
            apiKey: '',
            authMethod: ProviderAuthMethod.chatGpt,
            credential: _chatGptCredential(),
          ),
          throwsA(
            isA<ChatFailure>().having(
              (failure) => failure.kind,
              'kind',
              ChatFailureKind.badRequest,
            ),
          ),
          reason: url,
        );
      }

      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: '${ProviderAuthMethod.chatGpt.baseUrl}/',
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );
      expect(await providers.apiKeyFor(provider), 'access-1');
    });

    test('rejects credentials for a different account type', () async {
      await expectLater(
        providers.create(
          name: 'ChatGPT',
          type: AiProviderType.openAiCompatible,
          baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
          model: 'gpt-5',
          apiKey: '',
          authMethod: ProviderAuthMethod.chatGpt,
          credential: ProviderOAuthCredential(
            method: ProviderAuthMethod.openRouter,
            accessToken: 'openrouter-key',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('refreshes an expired ChatGPT credential once', () async {
      final repository = ProviderRepository(
        database,
        secureStore,
        oauthFlow: _FakeOAuthFlow(_chatGptCredential(accessToken: 'access-2')),
      );
      final provider = await repository.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );

      expect(await repository.apiKeyFor(provider), 'access-2');
      expect(
        (await repository.oauthCredentialFor(provider))?.accessToken,
        'access-2',
      );
    });

    test('switches an API-key provider to an account', () async {
      final provider = await providers.create(
        name: 'OpenAI',
        type: AiProviderType.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'key-1',
      );

      await providers.update(
        provider: provider,
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      final updated = (await providers.get(provider.id))!;
      expect(updated.authMethod, ProviderAuthMethod.chatGpt);
      expect(secureStore.values[provider.apiKeyRef], isNull);
      expect(await providers.apiKeyFor(updated), 'access-1');
    });

    test('does not switch to an account without credentials', () async {
      final provider = await providers.create(
        name: 'OpenAI',
        type: AiProviderType.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'key-1',
      );

      await expectLater(
        providers.update(
          provider: provider,
          name: 'ChatGPT',
          type: AiProviderType.openAiCompatible,
          baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
          model: 'gpt-5',
          authMethod: ProviderAuthMethod.chatGpt,
        ),
        throwsA(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.badRequest,
          ),
        ),
      );
      expect(
        (await providers.get(provider.id))?.authMethod,
        ProviderAuthMethod.apiKey,
      );
      expect(await providers.apiKeyFor(provider), 'key-1');
    });

    test('keeps stored credentials when only metadata changes', () async {
      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      await providers.update(
        provider: provider,
        name: 'My ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5-mini',
      );

      final updated = (await providers.get(provider.id))!;
      expect(updated.name, 'My ChatGPT');
      expect(updated.model, 'gpt-5-mini');
      expect(await providers.apiKeyFor(updated), 'access-1');
    });

    test('requires a new account when switching account types', () async {
      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      await expectLater(
        providers.update(
          provider: provider,
          name: 'OpenRouter',
          type: AiProviderType.openAiCompatible,
          baseUrl: ProviderAuthMethod.openRouter.baseUrl!,
          model: 'openai/gpt-4o-mini',
          authMethod: ProviderAuthMethod.openRouter,
        ),
        throwsA(isA<ChatFailure>()),
      );
      expect(
        (await providers.get(provider.id))?.authMethod,
        ProviderAuthMethod.chatGpt,
      );
    });

    test('switches an account provider back to an API key', () async {
      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      await expectLater(
        providers.update(
          provider: provider,
          name: 'OpenAI',
          type: AiProviderType.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          authMethod: ProviderAuthMethod.apiKey,
        ),
        throwsA(isA<ChatFailure>()),
      );

      await providers.update(
        provider: provider,
        name: 'OpenAI',
        type: AiProviderType.openAiCompatible,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'key-2',
        authMethod: ProviderAuthMethod.apiKey,
      );

      final updated = (await providers.get(provider.id))!;
      expect(updated.authMethod, ProviderAuthMethod.apiKey);
      expect(await providers.apiKeyFor(updated), 'key-2');
      expect(secureStore.values['${provider.apiKeyRef}.oauth'], isNull);
    });

    test('disconnects and deletes account credentials', () async {
      final provider = await providers.create(
        name: 'ChatGPT',
        type: AiProviderType.openAiCompatible,
        baseUrl: ProviderAuthMethod.chatGpt.baseUrl!,
        model: 'gpt-5',
        apiKey: '',
        authMethod: ProviderAuthMethod.chatGpt,
        credential: _chatGptCredential(),
      );

      await providers.disconnectAccount(provider);
      await expectLater(
        providers.apiKeyFor(provider),
        throwsA(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.unauthorized,
          ),
        ),
      );

      await providers.delete(provider);
      expect(secureStore.values, isEmpty);
    });

    test('keeps one installation host id in secure storage', () async {
      final first = await providers.oauthHostId();
      final second = await providers.oauthHostId();
      expect(first, startsWith('urn:uuid:'));
      expect(second, first);
      expect(secureStore.values['agentport.provider.oauth.host'], first);
      expect(first, isNot(contains('@')));
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
      final conversation = await conversations.create(providerId: provider.id);

      await conversations.setProvider(conversation.id, null);
      expect((await conversations.get(conversation.id))?.providerId, isNull);

      await conversations.setProvider(conversation.id, provider.id);
      expect(
        (await conversations.get(conversation.id))?.providerId,
        provider.id,
      );
    });

    test('stores a per-conversation model and message attachments', () async {
      final conversation = await conversations.create();
      await conversations.setModel(conversation.id, 'deepseek-reasoner');
      expect(
        (await conversations.get(conversation.id))?.model,
        'deepseek-reasoner',
      );

      final id = conversations.newMessageId();
      await conversations.insertMessage(
        ChatMessage(
          id: id,
          conversationId: conversation.id,
          role: ChatRole.user,
          content: 'See attached',
          reasoning: null,
          status: ChatMessageStatus.complete,
          createdAt: DateTime(2026),
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
        ),
      );

      final message = (await conversations.messages(conversation.id)).single;
      expect(message.attachments, hasLength(2));
      expect(message.attachments.first.bytesBase64, 'aGVsbG8=');
      expect(message.attachments.last.textContent, 'file body');
    });
  });
}
