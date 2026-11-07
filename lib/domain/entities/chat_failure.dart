enum ChatFailureKind {
  noProvider,
  missingApiKey,
  unauthorized,
  insufficientBalance,
  rateLimited,
  badRequest,
  server,
  network,
  invalidResponse,
  canceled,
  unknown,
}

/// A failure that can be shown to the user with a localized explanation.
class ChatFailure implements Exception {
  const ChatFailure(this.kind, {this.detail, this.statusCode});

  final ChatFailureKind kind;
  final String? detail;
  final int? statusCode;

  @override
  String toString() {
    return detail == null ? kind.name : '${kind.name}: $detail';
  }
}
