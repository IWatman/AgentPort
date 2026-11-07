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
    this.attachments = const [],
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final String? reasoning;
  final ChatMessageStatus status;
  final DateTime createdAt;
  final List<ChatMessageAttachment> attachments;

  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
}

/// An image or text file attached to a user message.
class ChatMessageAttachment {
  const ChatMessageAttachment({
    required this.name,
    required this.mimeType,
    this.bytesBase64,
    this.textContent,
  });

  final String name;
  final String mimeType;

  /// Base64 bytes for images.
  final String? bytesBase64;

  /// Extracted UTF-8 text for text files.
  final String? textContent;

  bool get isImage => bytesBase64 != null && mimeType.startsWith('image/');
  bool get isText => textContent != null;

  Map<String, Object?> toJson() => {
    'name': name,
    'mimeType': mimeType,
    if (bytesBase64 != null) 'bytesBase64': bytesBase64,
    if (textContent != null) 'textContent': textContent,
  };

  static ChatMessageAttachment? fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final mimeType = json['mimeType'];
    if (name is! String || mimeType is! String) {
      return null;
    }
    final bytes = json['bytesBase64'];
    final text = json['textContent'];
    return ChatMessageAttachment(
      name: name,
      mimeType: mimeType,
      bytesBase64: bytes is String ? bytes : null,
      textContent: text is String ? text : null,
    );
  }
}
