import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';

/// Returns a localized, user-presentable message for an OpenCode error.
String openCodeFailureText(AppLocalizations l10n, Object error) {
  if (error is! OpenCodeFailure) {
    return l10n.openCodeFailureUnknown;
  }
  return switch (error.kind) {
    OpenCodeFailureKind.invalidPayload => l10n.openCodeFailureInvalidPayload,
    OpenCodeFailureKind.network => l10n.openCodeFailureNetwork,
    OpenCodeFailureKind.timeout => l10n.openCodeFailureTimeout,
    OpenCodeFailureKind.unauthorized => l10n.openCodeFailureUnauthorized,
    OpenCodeFailureKind.unsupportedVersion =>
      l10n.openCodeFailureUnsupportedVersion,
    OpenCodeFailureKind.server => l10n.openCodeFailureServer,
    OpenCodeFailureKind.invalidResponse => l10n.openCodeFailureInvalidResponse,
  };
}
