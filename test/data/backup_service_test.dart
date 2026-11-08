import 'dart:convert';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/backup/backup_service.dart';
import 'package:drift/drift.dart' show Value;
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
  test(
    'exports chats and providers without secrets and imports them',
    () async {
      final source = AppDatabase(NativeDatabase.memory());
      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      final secureStore = _MemorySecureStore();
      final now = DateTime(2026, 1, 2, 3, 4).millisecondsSinceEpoch;

      await source
          .into(source.providerEntries)
          .insert(
            ProviderEntriesCompanion.insert(
              id: 'provider-1',
              name: 'DeepSeek',
              type: 'deepseek',
              baseUrl: 'https://api.deepseek.com',
              model: 'deepseek-flash',
              apiKeyRef: 'secret-provider-ref',
              createdAt: now,
            ),
          );
      await source
          .into(source.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'conversation-1',
              title: const Value('Imported chat'),
              providerId: const Value('provider-1'),
              model: const Value('deepseek-flash'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await source
          .into(source.messages)
          .insert(
            MessagesCompanion.insert(
              id: 'message-1',
              conversationId: 'conversation-1',
              role: 'user',
              content: const Value('Hello'),
              attachmentsJson: const Value('[{"type":"text","name":"a.txt"}]'),
              createdAt: now,
            ),
          );

      final json = await BackupService(source, secureStore).exportJson();
      expect(json, contains('agentport.backup'));
      expect(json, isNot(contains('apiKeyRef')));
      expect(json, isNot(contains('secret-provider-ref')));
      expect(json, isNot(contains('apiKey')));

      final result = await BackupService(target, secureStore).importJson(json);

      expect(result.providers, 1);
      expect(result.conversations, 1);
      expect(result.messages, 1);
      final providers = await target.select(target.providerEntries).get();
      final conversations = await target.select(target.conversations).get();
      final messages = await target.select(target.messages).get();
      expect(providers.single.name, 'DeepSeek');
      expect(providers.single.id, isNot('provider-1'));
      expect(conversations.single.title, 'Imported chat');
      expect(conversations.single.providerId, providers.single.id);
      expect(messages.single.content, 'Hello');
      expect(messages.single.attachmentsJson, isNotNull);
    },
  );

  test('rejects malformed and unsupported backups', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = BackupService(database, _MemorySecureStore());

    await expectLater(service.importJson('{nope'), throwsFormatException);
    await expectLater(
      service.importJson(jsonEncode({'format': 'other', 'version': 1})),
      throwsFormatException,
    );
  });
}
