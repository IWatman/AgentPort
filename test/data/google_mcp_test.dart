import 'package:agentport/domain/entities/google_mcp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google MCP catalog resolves every official service URL', () {
    expect(googleMcpServices.map((service) => service.id).toSet(), {
      'calendar',
      'gmail',
      'drive',
      'docs',
      'sheets',
      'slides',
      'chat',
      'people',
      'classroom',
    });
    for (final service in googleMcpServices) {
      expect(googleMcpServiceForUrl(service.url)?.id, service.id);
      expect(googleMcpServiceForUrl('${service.url}/')?.id, service.id);
      expect(service.scopes, isNotEmpty);
      expect(service.apiHost, isNotEmpty);
      expect(service.mcpHost, isNotEmpty);
    }
  });

  test('Google OAuth config requests offline access and consent', () {
    final service = googleMcpServiceForId('calendar')!;
    final config = googleOAuthClientConfig(
      clientId: 'client-id',
      clientSecret: 'client-secret',
      service: service,
    );

    expect(config.clientId, 'client-id');
    expect(config.clientSecret, 'client-secret');
    expect(config.redirectUri, googleMcpRedirectUri);
    expect(config.scopes, service.scopes);
    expect(config.authorizationParams['access_type'], 'offline');
    expect(config.authorizationParams['prompt'], 'consent');
  });
}
