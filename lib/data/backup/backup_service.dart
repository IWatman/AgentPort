import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/security/secure_store.dart';

class BackupImportResult {
  const BackupImportResult({
    required this.conversations,
    required this.messages,
    required this.providers,
  });

  final int conversations;
  final int messages;
  final int providers;
}

/// Exports and imports chats and providers without any secret values.
class BackupService {
  BackupService(this._database, this._secureStore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const format = 'agentport.backup';
  static const version = 1;

  final AppDatabase _database;
  final SecureStore _secureStore;
  final Uuid _uuid;

  Future<String> exportJson() async {
    final providers = await _database.select(_database.providerEntries).get();
    final conversations = await _database.select(_database.conversations).get();
    final messages = await _database.select(_database.messages).get();

    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'providers': [
        for (final provider in providers)
          {
            'id': provider.id,
            'name': provider.name,
            'type': provider.type,
            'base_url': provider.baseUrl,
            'model': provider.model,
            'auth_method': provider.authMethod,
          },
      ],
      'conversations': [
        for (final conversation in conversations)
          {
            'id': conversation.id,
            'title': conversation.title,
            'provider_id': conversation.providerId,
            'model': conversation.model,
            'system_prompt': conversation.systemPrompt,
            'archived': conversation.archived,
            'created_at': conversation.createdAt,
            'updated_at': conversation.updatedAt,
          },
      ],
      'messages': [
        for (final message in messages)
          {
            'id': message.id,
            'conversation_id': message.conversationId,
            'role': message.role,
            'content': message.content,
            'reasoning': message.reasoning,
            'tool_calls': message.toolCallsJson,
            'attachments': message.attachmentsJson,
            'tool_call_id': message.toolCallId,
            'status': message.status,
            'created_at': message.createdAt,
          },
      ],
    });
  }

  Future<BackupImportResult> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('The backup is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('The backup root must be an object.');
    }
    final root = Map<String, Object?>.from(decoded);
    if (root['format'] != format || root['version'] != version) {
      throw const FormatException('This backup format is not supported.');
    }

    final providers = _objects(root['providers']);
    final conversations = _objects(root['conversations']);
    final messages = _objects(root['messages']);

    var importedProviders = 0;
    var importedConversations = 0;
    var importedMessages = 0;

    await _database.transaction(() async {
      final providerMap = <String, String>{};
      for (final item in providers) {
        final oldId = _string(item['id']);
        final name = _string(item['name']);
        final type = _string(item['type']);
        final baseUrl = _string(item['base_url']);
        final model = _string(item['model']);
        if (oldId == null ||
            name == null ||
            type == null ||
            baseUrl == null ||
            model == null) {
          continue;
        }
        final existing = await (_database.select(
          _database.providerEntries,
        )..where((table) => table.id.equals(oldId))).getSingleOrNull();
        if (existing != null) {
          providerMap[oldId] = existing.id;
          continue;
        }
        final id = _uuid.v4();
        final apiKeyRef = 'agentport.provider.$id.key';
        await _database
            .into(_database.providerEntries)
            .insert(
              ProviderEntriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                baseUrl: baseUrl,
                model: model,
                apiKeyRef: apiKeyRef,
                authMethod: Value(_string(item['auth_method']) ?? 'api_key'),
                createdAt:
                    _int(item['created_at']) ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
            );
        await _secureStore.delete(apiKeyRef);
        providerMap[oldId] = id;
        importedProviders++;
      }

      final conversationMap = <String, String>{};
      for (final item in conversations) {
        final oldId = _string(item['id']);
        if (oldId == null) {
          continue;
        }
        final id = _uuid.v4();
        final oldProviderId = _string(item['provider_id']);
        final providerId = oldProviderId == null
            ? null
            : providerMap[oldProviderId];
        final now = DateTime.now().millisecondsSinceEpoch;
        await _database
            .into(_database.conversations)
            .insert(
              ConversationsCompanion.insert(
                id: id,
                title: Value(_string(item['title']) ?? ''),
                providerId: Value(providerId),
                model: Value(_string(item['model'])),
                systemPrompt: Value(_string(item['system_prompt'])),
                archived: Value(item['archived'] == true),
                createdAt: _int(item['created_at']) ?? now,
                updatedAt: _int(item['updated_at']) ?? now,
              ),
            );
        conversationMap[oldId] = id;
        importedConversations++;
      }

      for (final item in messages) {
        final oldConversationId = _string(item['conversation_id']);
        final role = _string(item['role']);
        if (oldConversationId == null || role == null) {
          continue;
        }
        final conversationId = conversationMap[oldConversationId];
        if (conversationId == null) {
          continue;
        }
        await _database
            .into(_database.messages)
            .insert(
              MessagesCompanion.insert(
                id: _uuid.v4(),
                conversationId: conversationId,
                role: role,
                content: Value(_string(item['content']) ?? ''),
                reasoning: Value(_string(item['reasoning'])),
                toolCallsJson: Value(_string(item['tool_calls'])),
                attachmentsJson: Value(_string(item['attachments'])),
                toolCallId: Value(_string(item['tool_call_id'])),
                status: Value(_string(item['status']) ?? 'complete'),
                createdAt:
                    _int(item['created_at']) ??
                    DateTime.now().millisecondsSinceEpoch,
              ),
            );
        importedMessages++;
      }
    });

    return BackupImportResult(
      conversations: importedConversations,
      messages: importedMessages,
      providers: importedProviders,
    );
  }

  List<Map<String, Object?>> _objects(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is Map) Map<String, Object?>.from(item),
    ];
  }

  String? _string(Object? value) {
    if (value is! String) {
      return null;
    }
    return value;
  }

  int? _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStoreProvider),
  );
});
