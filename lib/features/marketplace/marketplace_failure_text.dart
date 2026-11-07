import '../../domain/entities/marketplace.dart';
import '../../l10n/generated/app_localizations.dart';

String marketplaceFailureText(AppLocalizations l10n, Object error) {
  if (error is! MarketplaceFailure) {
    return l10n.marketplaceErrorUnknown;
  }
  return marketplaceFailureTextForKind(l10n, error.kind);
}

String marketplaceFailureTextForKind(
  AppLocalizations l10n,
  MarketplaceFailureKind kind,
) {
  return switch (kind) {
    MarketplaceFailureKind.invalidInput => l10n.marketplaceErrorInvalidInput,
    MarketplaceFailureKind.network => l10n.marketplaceErrorNetwork,
    MarketplaceFailureKind.notFound => l10n.marketplaceErrorNotFound,
    MarketplaceFailureKind.invalidManifest =>
      l10n.marketplaceErrorInvalidManifest,
    MarketplaceFailureKind.noRemoteMcp => l10n.marketplaceErrorNoRemoteMcp,
    MarketplaceFailureKind.unsupportedSource =>
      l10n.marketplaceErrorUnsupportedSource,
    MarketplaceFailureKind.unsupportedPlatform =>
      l10n.marketplaceErrorUnsupportedPlatform,
    MarketplaceFailureKind.duplicate => l10n.marketplaceErrorDuplicate,
    MarketplaceFailureKind.needsReconsent => l10n.marketplaceNeedsReconsentBody,
    MarketplaceFailureKind.storage => l10n.marketplaceErrorStorage,
  };
}

String marketplaceStatusText(AppLocalizations l10n, PluginMcpStatus status) {
  return switch (status) {
    PluginMcpStatus.remote => l10n.marketplaceMcpRemote,
    PluginMcpStatus.mixed => l10n.marketplaceMcpMixed,
    PluginMcpStatus.none => l10n.marketplaceMcpNone,
    PluginMcpStatus.stdio => l10n.marketplaceMcpStdio,
    PluginMcpStatus.unsupported => l10n.marketplaceMcpUnsupported,
    PluginMcpStatus.error => l10n.marketplaceMcpError,
    PluginMcpStatus.unknown => l10n.marketplaceMcpUnknown,
  };
}

String marketplaceTrustText(AppLocalizations l10n, TrustLevel trust) {
  return switch (trust) {
    TrustLevel.anthropic => l10n.marketplaceTrustAnthropic,
    TrustLevel.verifiedPartner => l10n.marketplaceTrustPartner,
    TrustLevel.community => l10n.marketplaceTrustCommunity,
  };
}

String marketplaceStoredErrorText(AppLocalizations l10n, String? code) {
  if (code == null || code.isEmpty) {
    return l10n.marketplaceErrorUnknown;
  }
  for (final kind in MarketplaceFailureKind.values) {
    if (kind.name == code) {
      return marketplaceFailureTextForKind(l10n, kind);
    }
  }
  return l10n.marketplaceErrorUnknown;
}

String marketplaceAuthText(AppLocalizations l10n, McpAuthType auth) {
  return switch (auth) {
    McpAuthType.oauth => l10n.marketplaceAuthOAuth,
    McpAuthType.apiKey => l10n.marketplaceAuthApiKey,
    McpAuthType.none => l10n.marketplaceAuthNone,
    McpAuthType.unknown => l10n.marketplaceAuthUnknown,
  };
}
