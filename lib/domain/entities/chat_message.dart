enum ChatRole {
  system('system'),
  user('user'),
  assistant('assistant'),
  tool('tool');

  const ChatRole(this.storageValue);

  final String storageValue;

  static ChatRole fromStorage(String value) {
    return switch (value) {
      'system' => ChatRole.system,
      'assistant' => ChatRole.assistant,
      'tool' => ChatRole.tool,
      _ => ChatRole.user,
    };
  }
}

enum ChatMessageStatus {
  complete('complete'),
  stopped('stopped'),
  error('error');

  const ChatMessageStatus(this.storageValue);

  final String storageValue;

  static ChatMessageStatus fromStorage(String value) {
    return switch (value) {
      'stopped' => ChatMessageStatus.stopped,
      'error' => ChatMessageStatus.error,
      _ => ChatMessageStatus.complete,
    };
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.reasoning,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final String? reasoning;
  final ChatMessageStatus status;
  final DateTime createdAt;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
}
