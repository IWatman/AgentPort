import '../../domain/entities/chat_failure.dart';
import '../../l10n/generated/app_localizations.dart';

/// Localized, user-facing explanation for a failed provider request.
String chatFailureText(AppLocalizations l10n, ChatFailure failure) {
  return switch (failure.kind) {
    ChatFailureKind.noProvider => l10n.chatErrorNoProvider,
    ChatFailureKind.missingApiKey => l10n.chatErrorMissingApiKey,
    ChatFailureKind.unauthorized => l10n.chatErrorUnauthorized,
    ChatFailureKind.insufficientBalance => l10n.chatErrorInsufficientBalance,
    ChatFailureKind.rateLimited => l10n.chatErrorRateLimited,
    ChatFailureKind.badRequest => l10n.chatErrorBadRequest,
    ChatFailureKind.server => l10n.chatErrorServer,
    ChatFailureKind.network => l10n.chatErrorNetwork,
    ChatFailureKind.invalidResponse => l10n.chatErrorInvalidResponse,
    ChatFailureKind.canceled => l10n.chatErrorCanceled,
    ChatFailureKind.unknown => l10n.chatErrorUnknown,
  };
}
