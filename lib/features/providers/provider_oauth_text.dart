import '../../data/auth/provider_oauth.dart';
import '../../l10n/generated/app_localizations.dart';

/// Localized, action-oriented text for provider sign-in failures.
String providerOAuthErrorText(
  AppLocalizations l10n,
  ProviderOAuthException error,
) {
  return switch (error.code) {
    ProviderOAuthError.busy => l10n.providerOAuthBusy,
    ProviderOAuthError.cancelled => l10n.providerOAuthCancelled,
    ProviderOAuthError.timeout => l10n.providerOAuthTimeout,
    ProviderOAuthError.browserUnavailable =>
      l10n.providerOAuthBrowserUnavailable,
    ProviderOAuthError.invalidState => l10n.providerOAuthInvalidState,
    ProviderOAuthError.accessDenied => l10n.providerOAuthAccessDenied,
    ProviderOAuthError.registrationMismatch =>
      l10n.providerOAuthRegistrationMismatch,
    ProviderOAuthError.identityMismatch => l10n.providerOAuthIdentityMismatch,
    ProviderOAuthError.incompleteRegistration =>
      l10n.providerOAuthIncompleteRegistration,
    ProviderOAuthError.invalidToken => l10n.providerOAuthInvalidToken,
    ProviderOAuthError.planPermissionRequired =>
      l10n.providerOAuthPlanPermissionRequired,
    ProviderOAuthError.reauthorizationRequired =>
      l10n.providerOAuthReauthorizationRequired,
    ProviderOAuthError.network => l10n.providerOAuthNetwork,
    ProviderOAuthError.tls => l10n.providerOAuthTls,
    ProviderOAuthError.invalidResponse => l10n.providerOAuthInvalidResponse,
    ProviderOAuthError.unsupportedRegion => l10n.providerOAuthUnsupportedRegion,
    ProviderOAuthError.authorizationFailed =>
      l10n.providerOAuthAuthorizationFailed,
  };
}
