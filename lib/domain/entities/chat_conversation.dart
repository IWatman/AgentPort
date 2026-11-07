class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.providerId,
    required this.systemPrompt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Empty until the first user message arrives.
  final String title;

  final String? providerId;
  final String? systemPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatConversation copyWith({
    String? title,
    String? providerId,
    bool clearProvider = false,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      providerId: clearProvider ? null : (providerId ?? this.providerId),
      systemPrompt: systemPrompt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
