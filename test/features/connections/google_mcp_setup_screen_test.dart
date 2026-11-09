import 'package:agentport/domain/entities/marketplace.dart';
import 'package:agentport/domain/entities/mcp.dart';
import 'package:agentport/domain/entities/mcp_oauth.dart';
import 'package:agentport/features/connections/google_mcp_setup_screen.dart';
import 'package:agentport/features/connections/mcp_connections_controller.dart';
import 'package:agentport/features/connections/mcp_server_screen.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectionsController extends McpConnectionsController {
  _FakeConnectionsController(this.value);

  final McpConnectionsState value;

  @override
  Future<McpConnectionsState> build() async => value;

  @override
  Future<McpOAuthClientConfig?> oauthClientFor(String serverId) async => null;
}

Widget _app(Widget home) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  testWidgets('Google setup screen shows the client fields and services', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const GoogleMcpSetupScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Google Workspace'), findsOneWidget);
    expect(find.text('Google OAuth client'), findsOneWidget);
    expect(find.text('OAuth client ID'), findsOneWidget);
    expect(find.text('OAuth client secret'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Google Workspace MCP setup'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Redirect URI'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Redirect URI'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Calendar'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
  });

  testWidgets('Google server screen asks for an OAuth client first', (
    tester,
  ) async {
    const server = McpServer(
      id: 'google-calendar',
      name: 'Google Calendar',
      url: 'https://calendarmcp.googleapis.com/mcp/v1',
      transport: McpTransport.http,
      authType: McpAuthType.oauth,
      enabled: true,
      headerNames: [],
      headerTemplates: {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpConnectionsControllerProvider.overrideWith(
            () => _FakeConnectionsController(
              const McpConnectionsState(
                servers: [
                  McpServerView(
                    server: server,
                    status: McpConnectionStatus.disconnected,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const McpServerScreen(serverId: 'google-calendar'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Add your Google OAuth client to connect this service.'),
      findsOneWidget,
    );
    expect(find.text('Configure OAuth client'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
  });
}
