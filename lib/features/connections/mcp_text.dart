import '../../domain/entities/mcp.dart';
import '../../l10n/generated/app_localizations.dart';

String mcpStatusText(AppLocalizations l10n, McpConnectionStatus status) {
  return switch (status) {
    McpConnectionStatus.connected => l10n.mcpConnected,
    McpConnectionStatus.checking => l10n.mcpTesting,
    McpConnectionStatus.needsAuth => l10n.mcpNeedsAuth,
    McpConnectionStatus.error => l10n.mcpConnectionError,
    McpConnectionStatus.disconnected => l10n.mcpDisconnected,
  };
}

String mcpFailureText(AppLocalizations l10n, McpFailure? failure) {
  if (failure == null) {
    return l10n.mcpConnectionError;
  }
  return switch (failure.kind) {
    McpFailureKind.unauthorized => l10n.mcpErrorUnauthorized,
    McpFailureKind.network => l10n.mcpErrorNetwork,
    McpFailureKind.timeout => l10n.mcpErrorTimeout,
    McpFailureKind.protocol => l10n.mcpErrorProtocol,
    McpFailureKind.invalidResponse => l10n.mcpErrorInvalidResponse,
    McpFailureKind.unsupportedTransport => l10n.mcpErrorUnsupportedTransport,
    McpFailureKind.toolError => l10n.mcpErrorTool,
  };
}
