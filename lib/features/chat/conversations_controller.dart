import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../domain/entities/chat_conversation.dart';

final conversationsControllerProvider =
    AsyncNotifierProvider<ConversationsController, List<ChatConversation>>(
      ConversationsController.new,
    );

class ConversationsController extends AsyncNotifier<List<ChatConversation>> {
  @override
  Future<List<ChatConversation>> build() {
    return ref.watch(conversationRepositoryProvider).list();
  }

  Future<ChatConversation> create({String? providerId}) async {
    final conversation = await ref
        .read(conversationRepositoryProvider)
        .create(providerId: providerId);
    state = AsyncData([conversation, ...?state.value]);
    return conversation;
  }

  Future<void> rename(ChatConversation conversation, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await ref
        .read(conversationRepositoryProvider)
        .rename(conversation.id, trimmed);
    _replace(conversation.copyWith(title: trimmed, updatedAt: DateTime.now()));
  }

  Future<void> delete(ChatConversation conversation) async {
    await ref.read(conversationRepositoryProvider).delete(conversation.id);
    final current = state.value ?? const <ChatConversation>[];
    state = AsyncData([
      for (final item in current)
        if (item.id != conversation.id) item,
    ]);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(conversationRepositoryProvider).list(),
    );
  }

  /// Inserts or replaces a conversation and keeps the list sorted by
  /// activity, newest first.
  void upsert(ChatConversation conversation) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final updated = [
      for (final item in current)
        if (item.id != conversation.id) item,
      conversation,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(updated);
  }

  void removeById(String id) {
    final current = state.value ?? const <ChatConversation>[];
    state = AsyncData([
      for (final item in current)
        if (item.id != id) item,
    ]);
  }

  void _replace(ChatConversation conversation) {
    final current = state.value ?? const <ChatConversation>[];
    final updated = [
      for (final item in current)
        if (item.id == conversation.id) conversation else item,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(updated);
  }
}
