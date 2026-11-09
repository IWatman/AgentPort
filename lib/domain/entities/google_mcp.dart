import 'mcp_oauth.dart';

/// The loopback callback used by Google OAuth clients.
///
/// Google requires an exact redirect URI for Web application clients. Desktop
/// app clients accept any loopback port, so the same URI works for both.
const googleMcpRedirectUri = 'http://127.0.0.1:53682/callback';

const googleCloudConsoleUrl =
    'https://console.cloud.google.com/auth/clients/create';
const googleCloudApisUrl = 'https://console.cloud.google.com/apis/library';
const googleWorkspacePreviewUrl =
    'https://developers.google.com/workspace/preview';
const googleMcpSetupDocsUrl =
    'https://developers.google.com/workspace/guides/configure-mcp-servers';

/// One Google Workspace product exposed as an official remote MCP server.
class GoogleMcpService {
  const GoogleMcpService({
    required this.id,
    required this.name,
    required this.url,
    required this.scopes,
    required this.apiHost,
    required this.mcpHost,
  });

  final String id;
  final String name;
  final String url;
  final List<String> scopes;

  /// Google API that must be enabled for this product.
  final String apiHost;

  /// MCP service that must be enabled for this product.
  final String mcpHost;

  String get serverId => 'google-$id';
  String get serverName => 'Google $name';
}

const googleMcpServices = [
  GoogleMcpService(
    id: 'calendar',
    name: 'Calendar',
    url: 'https://calendarmcp.googleapis.com/mcp/v1',
    scopes: ['https://www.googleapis.com/auth/calendar'],
    apiHost: 'calendar-json.googleapis.com',
    mcpHost: 'calendarmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'gmail',
    name: 'Gmail',
    url: 'https://gmailmcp.googleapis.com/mcp/v1',
    scopes: ['https://www.googleapis.com/auth/gmail.modify'],
    apiHost: 'gmail.googleapis.com',
    mcpHost: 'gmailmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'drive',
    name: 'Drive',
    url: 'https://drivemcp.googleapis.com/mcp/v1',
    scopes: ['https://www.googleapis.com/auth/drive'],
    apiHost: 'drive.googleapis.com',
    mcpHost: 'drivemcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'docs',
    name: 'Docs',
    url: 'https://docsmcp.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/documents',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
    apiHost: 'docs.googleapis.com',
    mcpHost: 'docsmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'sheets',
    name: 'Sheets',
    url: 'https://sheetsmcp.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
    apiHost: 'sheets.googleapis.com',
    mcpHost: 'sheetsmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'slides',
    name: 'Slides',
    url: 'https://slidesmcp.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/presentations',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
    apiHost: 'slides.googleapis.com',
    mcpHost: 'slidesmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'chat',
    name: 'Chat',
    url: 'https://chatmcp.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/chat.spaces',
      'https://www.googleapis.com/auth/chat.messages',
      'https://www.googleapis.com/auth/chat.memberships.readonly',
    ],
    apiHost: 'chat.googleapis.com',
    mcpHost: 'chatmcp.googleapis.com',
  ),
  GoogleMcpService(
    id: 'people',
    name: 'People',
    url: 'https://people.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/contacts.readonly',
      'https://www.googleapis.com/auth/directory.readonly',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
    apiHost: 'people.googleapis.com',
    mcpHost: 'people.googleapis.com',
  ),
  GoogleMcpService(
    id: 'classroom',
    name: 'Classroom',
    url: 'https://classroommcp.googleapis.com/mcp/v1',
    scopes: [
      'https://www.googleapis.com/auth/classroom.courses',
      'https://www.googleapis.com/auth/classroom.coursework.me',
      'https://www.googleapis.com/auth/classroom.coursework.students',
      'https://www.googleapis.com/auth/classroom.rosters.readonly',
      'https://www.googleapis.com/auth/classroom.announcements.readonly',
      'https://www.googleapis.com/auth/classroom.topics.readonly',
      'https://www.googleapis.com/auth/classroom.profile.emails',
    ],
    apiHost: 'classroom.googleapis.com',
    mcpHost: 'classroommcp.googleapis.com',
  ),
];

GoogleMcpService? googleMcpServiceForId(String id) {
  for (final service in googleMcpServices) {
    if (service.id == id) {
      return service;
    }
  }
  return null;
}

GoogleMcpService? googleMcpServiceForUrl(String url) {
  final normalized = url.trim().replaceFirst(RegExp(r'/+$'), '');
  for (final service in googleMcpServices) {
    if (service.url == normalized) {
      return service;
    }
  }
  return null;
}

/// Builds the stored OAuth client configuration for one Google service.
McpOAuthClientConfig googleOAuthClientConfig({
  required String clientId,
  required String clientSecret,
  required GoogleMcpService service,
}) {
  return McpOAuthClientConfig(
    clientId: clientId,
    clientSecret: clientSecret,
    redirectUri: googleMcpRedirectUri,
    scopes: service.scopes,
    authorizationParams: const {'access_type': 'offline', 'prompt': 'consent'},
  );
}
