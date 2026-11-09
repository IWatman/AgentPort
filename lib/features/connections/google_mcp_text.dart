import '../../domain/entities/google_mcp.dart';
import '../../domain/entities/mcp.dart';
import '../../l10n/generated/app_localizations.dart';

String googleMcpServiceName(AppLocalizations l10n, GoogleMcpService service) {
  return switch (service.id) {
    'gmail' => l10n.googleMcpServiceGmail,
    'calendar' => l10n.googleMcpServiceCalendar,
    'drive' => l10n.googleMcpServiceDrive,
    'docs' => l10n.googleMcpServiceDocs,
    'sheets' => l10n.googleMcpServiceSheets,
    'slides' => l10n.googleMcpServiceSlides,
    'chat' => l10n.googleMcpServiceChat,
    'people' => l10n.googleMcpServicePeople,
    'classroom' => l10n.googleMcpServiceClassroom,
    _ => service.name,
  };
}

String googleMcpServiceDescription(
  AppLocalizations l10n,
  GoogleMcpService service,
) {
  return switch (service.id) {
    'gmail' => l10n.googleMcpServiceGmailDescription,
    'calendar' => l10n.googleMcpServiceCalendarDescription,
    'drive' => l10n.googleMcpServiceDriveDescription,
    'docs' => l10n.googleMcpServiceDocsDescription,
    'sheets' => l10n.googleMcpServiceSheetsDescription,
    'slides' => l10n.googleMcpServiceSlidesDescription,
    'chat' => l10n.googleMcpServiceChatDescription,
    'people' => l10n.googleMcpServicePeopleDescription,
    'classroom' => l10n.googleMcpServiceClassroomDescription,
    _ => '',
  };
}

String mcpServerDisplayName(AppLocalizations l10n, McpServer server) {
  final service = server.googleService;
  if (service == null) {
    return server.displayName;
  }
  return googleMcpServiceName(l10n, service);
}
