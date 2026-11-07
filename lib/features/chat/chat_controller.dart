import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/openai_compatible_client.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_failure.dart';
import '../../domain/entities/chat_message.dart';
import 'conversations_controller.dart';

const _unset = Object();

class ChatSessionState {
  const ChatSessionState({
    required this.conversation,
    required this.messages,
    this.streaming = false,
    this.failure,
  });

  final ChatConversation conversation;
  final List<ChatMessage> messages;
  final bool streaming;
  final ChatFailure? failure;

  ChatMessage? get lastUserMessage {
    for (var index = messages.length - 1; index >= 0; index--) {
      if (messages[index].isUser) {
        return messages[index];
      }
    }
    return null;
  }

  bool get canRetry =>
      !streaming &&
      lastUserMessage != null &&
      (failure != null || messages.last.isUser);

  ChatSessionState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? streaming,
    Object? failure = _unset,
  }) {
    return ChatSessionState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      streaming: streaming ?? this.streaming,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as ChatFailure?,
    );
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.family<ChatController, ChatSessionState, String>(
      ChatController.new,
      isAutoDispose: true,
    );

/// Owns one open conversation: message history, streaming response, and
/// provider selection.
class ChatController extends AsyncNotifier<ChatSessionState> {
  ChatController(this.conversationId);

  final String conversationId;

  ConversationRepository? _repository;
  StreamSubscription<ChatDelta>? _subscription;
  Completer<void>? _completer;
  String? _streamingMessageId;
  String _contentBuffer = '';
  String _reasoningBuffer = '';
  bool _cancelRequested = false;
  int _generation = 0;

  @override
  Future<ChatSessionState> build() async {
    final repository = ref.watch(conversationRepositoryProvider);
    _repository = repository;
    ref.onDispose(_handleDispose);

    final conversation = await repository.get(conversationId);
    if (conversation == null) {
      throw StateError('Conversation $conversationId does not exist.');
    }
    final messages = await repository.messages(conversationId);
    return ChatSessionState(conversation: conversation, messages: messages);
  }

  Future<void> send(
    String text, {
    List<ChatMessageAttachment> attachments = const [],
    void Function()? onAccepted,
  }) async {
    final trimmed = text.trim();
    final current = state.value;
    if ((trimmed.isEmpty && attachments.isEmpty) ||
        current == null ||
        current.streaming) {
      return;
    }

    final provider = await _resolveProvider(current.conversation.providerId);
    if (!ref.mounted) {
      return;
    }
    if (provider == null) {
      _setFailure(const ChatFailure(ChatFailureKind.noProvider));
      return;
    }
    if (_effectiveModel(provider).trim().isEmpty) {
      _setFailure(const ChatFailure(ChatFailureKind.noModel));
      return;
    }

    final apiKey = await ref
        .read(providerRepositoryProvider)
        .apiKeyFor(provider);
    if (!ref.mounted) {
      return;
    }
    if (apiKey == null || apiKey.isEmpty) {
      _setFailure(const ChatFailure(ChatFailureKind.missingApiKey));
      return;
    }

    final now = DateTime.now();
    final repository = ref.read(conversationRepositoryProvider);
    final isFirstUserMessage =
        current.conversation.title.trim().isEmpty &&
        !current.messages.any((message) => message.isUser);

    final userMessage = ChatMessage(
      id: repository.newMessageId(),
      conversationId: conversationId,
      role: ChatRole.user,
      content: trimmed,
      reasoning: null,
      status: ChatMessageStatus.complete,
      createdAt: now,
      attachments: attachments,
    );
    final assistantMessage = ChatMessage(
      id: repository.newMessageId(),
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: '',
      reasoning: null,
      status: ChatMessageStatus.complete,
      createdAt: now.add(const Duration(milliseconds: 1)),
    );

    final conversation = isFirstUserMessage
        ? current.conversation.copyWith(
            title: _titleFor(
              trimmed.isEmpty
                  ? (attachments.isEmpty
                        ? 'Attachment'
                        : attachments.first.name)
                  : trimmed,
            ),
            updatedAt: now,
          )
        : current.conversation;

    state = AsyncData(
      ChatSessionState(
        conversation: conversation,
        messages: [...current.messages, userMessage, assistantMessage],
        streaming: true,
      ),
    );

    try {
      await repository.insertMessage(userMessage);
      if (isFirstUserMessage) {
        await repository.rename(conversationId, conversation.title);
      }
    } catch (error) {
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null) {
          state = AsyncData(
            latest.copyWith(
              streaming: false,
              failure: ChatFailure(
                ChatFailureKind.unknown,
                detail: error.toString(),
              ),
            ),
          );
        }
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }
    _notifyList(conversation);
    onAccepted?.call();

    await _generate(
      assistantMessageId: assistantMessage.id,
      provider: provider,
      apiKey: apiKey,
    );
  }

  Future<void> retry() async {
    final current = state.value;
    if (current == null || current.streaming || !current.canRetry) {
      return;
    }

    final lastUserIndex = current.messages.lastIndexWhere(
      (message) => message.isUser,
    );
    if (lastUserIndex < 0) {
      return;
    }

    final provider = await _resolveProvider(current.conversation.providerId);
    if (!ref.mounted) {
      return;
    }
    if (provider == null) {
      _setFailure(const ChatFailure(ChatFailureKind.noProvider));
      return;
    }
    if (_effectiveModel(provider).trim().isEmpty) {
      _setFailure(const ChatFailure(ChatFailureKind.noModel));
      return;
    }

    final apiKey = await ref
        .read(providerRepositoryProvider)
        .apiKeyFor(provider);
    if (!ref.mounted) {
      return;
    }
    if (apiKey == null || apiKey.isEmpty) {
      _setFailure(const ChatFailure(ChatFailureKind.missingApiKey));
      return;
    }

    final repository = ref.read(conversationRepositoryProvider);
    final keptMessages = current.messages.sublist(0, lastUserIndex + 1);
    final removedIds = [
      for (final message in current.messages.sublist(lastUserIndex + 1))
        message.id,
    ];
    final assistantMessage = ChatMessage(
      id: repository.newMessageId(),
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: '',
      reasoning: null,
      status: ChatMessageStatus.complete,
      createdAt: DateTime.now(),
    );

    state = AsyncData(
      current.copyWith(
        messages: [...keptMessages, assistantMessage],
        streaming: true,
        failure: null,
      ),
    );

    try {
      await repository.deleteMessages(removedIds);
    } catch (error) {
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null) {
          state = AsyncData(
            latest.copyWith(
              streaming: false,
              failure: ChatFailure(
                ChatFailureKind.unknown,
                detail: error.toString(),
              ),
            ),
          );
        }
      }
      return;
    }
    if (!ref.mounted) {
      return;
    }

    await _generate(
      assistantMessageId: assistantMessage.id,
      provider: provider,
      apiKey: apiKey,
    );
  }

  Future<void> stop() async {
    if (state.value?.streaming != true) {
      return;
    }
    _cancelRequested = true;
    final completer = _completer;
    await _subscription?.cancel();
    _subscription = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> selectProvider(AiProvider provider) async {
    final current = state.value;
    if (current == null || current.streaming) {
      return;
    }
    final conversation = current.conversation.copyWith(
      providerId: provider.id,
      model: null,
      clearModel: true,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(
      current.copyWith(conversation: conversation, failure: null),
    );
    await ref
        .read(conversationRepositoryProvider)
        .setProvider(conversationId, provider.id);
    await ref
        .read(conversationRepositoryProvider)
        .setModel(conversationId, null);
    if (!ref.mounted) {
      return;
    }
    _notifyList(conversation);
  }

  Future<void> selectModel(String? model) async {
    final current = state.value;
    if (current == null || current.streaming) {
      return;
    }
    final trimmed = model?.trim();
    final conversation = current.conversation.copyWith(
      model: trimmed == null || trimmed.isEmpty ? null : trimmed,
      clearModel: trimmed == null || trimmed.isEmpty,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(current.copyWith(conversation: conversation));
    await ref
        .read(conversationRepositoryProvider)
        .setModel(conversationId, conversation.model);
    if (!ref.mounted) {
      return;
    }
    _notifyList(conversation);
  }

  Future<void> rename(String title) async {
    final trimmed = title.trim();
    final current = state.value;
    if (trimmed.isEmpty || current == null) {
      return;
    }
    final conversation = current.conversation.copyWith(
      title: trimmed,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(current.copyWith(conversation: conversation));
    await ref
        .read(conversationRepositoryProvider)
        .rename(conversationId, trimmed);
    if (!ref.mounted) {
      return;
    }
    _notifyList(conversation);
  }

  Future<void> deleteConversation() async {
    await _cancelStreaming();
    await ref.read(conversationRepositoryProvider).delete(conversationId);
    if (ref.mounted) {
      ref
          .read(conversationsControllerProvider.notifier)
          .removeById(conversationId);
    }
  }

  String _effectiveModel(AiProvider provider) {
    final model = state.value?.conversation.model?.trim();
    return model == null || model.isEmpty ? provider.model : model;
  }

  Future<AiProvider?> _resolveProvider(String? providerId) async {
    final providers = await ref.read(providerRepositoryProvider).list();
    if (providers.isEmpty) {
      return null;
    }
    if (providerId != null) {
      for (final provider in providers) {
        if (provider.id == providerId) {
          return provider;
        }
      }
    }
    return providers.first;
  }

  Future<void> _generate({
    required String assistantMessageId,
    required AiProvider provider,
    required String apiKey,
  }) async {
    final generation = ++_generation;
    _streamingMessageId = assistantMessageId;
    _contentBuffer = '';
    _reasoningBuffer = '';
    _cancelRequested = false;

    final completer = Completer<void>();
    _completer = completer;

    final subscription = ref
        .read(openAiCompatibleClientProvider)
        .streamChat(
          baseUrl: provider.baseUrl,
          apiKey: apiKey,
          model: _effectiveModel(provider),
          messages: _requestMessages(excludingId: assistantMessageId),
        )
        .listen(
          (delta) {
            if (generation != _generation) {
              return;
            }
            _contentBuffer += delta.content;
            _reasoningBuffer += delta.reasoning;
            if (delta.content.isNotEmpty || delta.reasoning.isNotEmpty) {
              _publishStreaming(assistantMessageId);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          cancelOnError: true,
        );
    _subscription = subscription;

    try {
      await completer.future;
    } on ChatFailure catch (failure) {
      if (generation == _generation) {
        await _finishStreaming(
          status: ChatMessageStatus.error,
          failure: failure,
        );
      }
      return;
    } catch (error) {
      if (generation == _generation) {
        await _finishStreaming(
          status: ChatMessageStatus.error,
          failure: ChatFailure(
            ChatFailureKind.unknown,
            detail: error.toString(),
          ),
        );
      }
      return;
    }

    if (generation != _generation || !ref.mounted) {
      return;
    }
    await _finishStreaming(
      status: _cancelRequested
          ? ChatMessageStatus.stopped
          : ChatMessageStatus.complete,
    );
  }

  List<ChatRequestMessage> _requestMessages({required String excludingId}) {
    final current = state.value;
    if (current == null) {
      return const [];
    }

    final result = <ChatRequestMessage>[];
    final systemPrompt = current.conversation.systemPrompt?.trim();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      result.add(ChatRequestMessage(role: 'system', content: systemPrompt));
    }
    for (final message in current.messages) {
      if (message.id == excludingId) {
        continue;
      }
      if (!message.isUser && !message.isAssistant) {
        continue;
      }
      final text = _textWithFiles(message);
      if (text.trim().isEmpty && message.attachments.isEmpty) {
        continue;
      }
      final parts = <Map<String, Object?>>[];
      if (text.trim().isNotEmpty) {
        parts.add({'type': 'text', 'text': text});
      }
      for (final attachment in message.attachments) {
        if (attachment.isImage) {
          parts.add({
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${attachment.mimeType};base64,'
                  '${attachment.bytesBase64}',
            },
          });
        }
      }
      final hasImage = message.attachments.any(
        (attachment) => attachment.isImage,
      );
      result.add(
        ChatRequestMessage(
          role: message.role.storageValue,
          content: text,
          contentParts: parts.isEmpty || (!hasImage && parts.length == 1)
              ? const []
              : parts,
        ),
      );
    }
    return result;
  }

  String _textWithFiles(ChatMessage message) {
    final buffer = StringBuffer(message.content);
    for (final attachment in message.attachments) {
      final text = attachment.textContent;
      if (text == null) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n\n');
      }
      buffer
        ..writeln('--- Attached file: ${attachment.name} ---')
        ..write(text);
    }
    return buffer.toString();
  }

  void _publishStreaming(String messageId) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        messages: [
          for (final message in current.messages)
            if (message.id == messageId)
              ChatMessage(
                id: message.id,
                conversationId: message.conversationId,
                role: message.role,
                content: _contentBuffer,
                reasoning: _reasoningBuffer.isEmpty ? null : _reasoningBuffer,
                status: ChatMessageStatus.complete,
                createdAt: message.createdAt,
              )
            else
              message,
        ],
      ),
    );
  }

  Future<void> _finishStreaming({
    required ChatMessageStatus status,
    ChatFailure? failure,
  }) async {
    if (!ref.mounted) {
      return;
    }
    final current = state.value;
    final messageId = _streamingMessageId;
    if (current == null || messageId == null) {
      return;
    }

    final content = _contentBuffer;
    final reasoning = _reasoningBuffer;
    final hasContent = content.isNotEmpty || reasoning.isNotEmpty;
    final now = DateTime.now();
    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: content,
      reasoning: reasoning.isEmpty ? null : reasoning,
      status: status,
      createdAt: now,
    );

    _streamingMessageId = null;
    _subscription = null;
    _completer = null;
    _contentBuffer = '';
    _reasoningBuffer = '';

    final conversation = current.conversation.copyWith(updatedAt: now);
    final messages = <ChatMessage>[
      for (final item in current.messages)
        if (item.id != messageId) item else if (hasContent) message,
    ];

    state = AsyncData(
      current.copyWith(
        conversation: conversation,
        messages: messages,
        streaming: false,
        failure: failure,
      ),
    );

    final repository = ref.read(conversationRepositoryProvider);
    if (hasContent) {
      await repository.insertMessage(message);
    }
    await repository.touch(conversationId);
    if (!ref.mounted) {
      return;
    }
    _notifyList(conversation);
  }

  Future<void> _cancelStreaming() async {
    _generation++;
    _cancelRequested = true;
    final completer = _completer;
    await _subscription?.cancel();
    _subscription = null;
    _completer = null;
    _streamingMessageId = null;
    _contentBuffer = '';
    _reasoningBuffer = '';
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _setFailure(ChatFailure failure) {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(failure: failure));
  }

  void _notifyList(ChatConversation conversation) {
    if (!ref.mounted) {
      return;
    }
    ref.read(conversationsControllerProvider.notifier).upsert(conversation);
  }

  String _titleFor(String message) {
    final singleLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 60) {
      return singleLine;
    }
    return '${singleLine.substring(0, 57).trimRight()}…';
  }

  void _handleDispose() {
    _generation++;
    _subscription?.cancel();
    _subscription = null;

    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    final messageId = _streamingMessageId;
    final content = _contentBuffer;
    final reasoning = _reasoningBuffer;
    final repository = _repository;
    _streamingMessageId = null;
    _contentBuffer = '';
    _reasoningBuffer = '';

    if (messageId == null ||
        repository == null ||
        (content.isEmpty && reasoning.isEmpty)) {
      return;
    }

    unawaited(
      repository.insertMessage(
        ChatMessage(
          id: messageId,
          conversationId: conversationId,
          role: ChatRole.assistant,
          content: content,
          reasoning: reasoning.isEmpty ? null : reasoning,
          status: ChatMessageStatus.stopped,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }
}
