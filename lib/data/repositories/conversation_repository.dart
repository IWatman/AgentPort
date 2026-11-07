import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

class ConversationRepository {
  ConversationRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<List<ChatConversation>> list() async {
    final rows = await (_database.select(
      _database.conversations,
    )..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<ChatConversation?> get(String id) async {
    final row = await (_database.select(
      _database.conversations,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<ChatConversation> create({String? providerId}) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _database
        .into(_database.conversations)
        .insert(
          ConversationsCompanion.insert(
            id: id,
            providerId: Value(providerId),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    return ChatConversation(
      id: id,
      title: '',
      providerId: providerId,
      systemPrompt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> rename(String id, String title) async {
    await _update(
      id,
      ConversationsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setProvider(String id, String? providerId) async {
    await _update(
      id,
      ConversationsCompanion(
        providerId: Value(providerId),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setModel(String id, String? model) async {
    await _update(
      id,
      ConversationsCompanion(
        model: Value(model),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> touch(String id) async {
    await _update(
      id,
      ConversationsCompanion(
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_database.delete(
      _database.conversations,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows =
        await (_database.select(_database.messages)
              ..where((table) => table.conversationId.equals(conversationId))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    return rows.map(_messageToDomain).toList(growable: false);
  }

  Future<void> insertMessage(ChatMessage message) {
    return _database
        .into(_database.messages)
        .insert(
          MessagesCompanion.insert(
            id: message.id,
            conversationId: message.conversationId,
            role: message.role.storageValue,
            content: Value(message.content),
            reasoning: Value(message.reasoning),
            attachmentsJson: message.attachments.isEmpty
                ? const Value.absent()
                : Value(
                    jsonEncode(
                      message.attachments
                          .map((attachment) => attachment.toJson())
                          .toList(),
                    ),
                  ),
            status: Value(message.status.storageValue),
            createdAt: message.createdAt.millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> deleteMessages(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) {
      return;
    }
    await (_database.delete(
      _database.messages,
    )..where((table) => table.id.isIn(list))).go();
  }

  String newMessageId() => _uuid.v4();

  Future<void> _update(String id, ConversationsCompanion companion) {
    return (_database.update(
      _database.conversations,
    )..where((table) => table.id.equals(id))).write(companion);
  }

  ChatConversation _toDomain(Conversation row) {
    return ChatConversation(
      id: row.id,
      title: row.title,
      providerId: row.providerId,
      systemPrompt: row.systemPrompt,
      model: row.model,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  ChatMessage _messageToDomain(Message row) {
    return ChatMessage(
      id: row.id,
      conversationId: row.conversationId,
      role: ChatRole.fromStorage(row.role),
      content: row.content,
      reasoning: row.reasoning,
      status: ChatMessageStatus.fromStorage(row.status),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      attachments: _attachmentsFromJson(row.attachmentsJson),
    );
  }

  List<ChatMessageAttachment> _attachmentsFromJson(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ChatMessageAttachment.fromJson(Map<String, Object?>.from(item)),
          )
          .whereType<ChatMessageAttachment>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(appDatabaseProvider));
});
