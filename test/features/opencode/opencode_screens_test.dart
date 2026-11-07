import 'package:agentport/domain/entities/opencode.dart';
import 'package:agentport/features/opencode/opencode_connections_controller.dart';
import 'package:agentport/features/opencode/opencode_connections_screen.dart';
import 'package:agentport/features/opencode/opencode_pair_screen.dart';
import 'package:agentport/features/opencode/opencode_project_sessions_screen.dart';
import 'package:agentport/features/opencode/opencode_projects_controller.dart';
import 'package:agentport/features/opencode/opencode_projects_screen.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectionsController extends OpenCodeConnectionsController {
  _FakeConnectionsController(this.connections);

  final List<OpenCodeConnection> connections;
  var manualCalls = 0;

  @override
  Future<List<OpenCodeConnection>> build() async => connections;

  @override
  Future<OpenCodeConnection> connectManual({
    required String baseUrl,
    required String password,
    String? name,
  }) async {
    manualCalls++;
    return OpenCodeConnection(
      id: 'manual',
      name: name ?? baseUrl,
      baseUrl: baseUrl,
      tokenRef: 'token',
    );
  }
}

class _FakeProjectsController extends OpenCodeProjectsController {
  _FakeProjectsController(this.value) : super('connection-1');

  final OpenCodeProjectsState value;

  @override
  Future<OpenCodeProjectsState> build() async => value;
}

class _FakeProjectSessionsController extends OpenCodeProjectSessionsController {
  _FakeProjectSessionsController(this.value)
    : super((connectionId: 'connection-1', projectId: 'project-1'));

  final OpenCodeProjectSessionsState value;

  @override
  Future<OpenCodeProjectSessionsState> build() async => value;
}

const _connection = OpenCodeConnection(
  id: 'connection-1',
  name: 'Home PC',
  baseUrl: 'http://192.168.1.10:4096',
  tokenRef: 'token',
);

const _project = OpenCodeProject(
  id: 'project-1',
  directory: r'C:\Users\dushc\Desktop\AgentPort',
  vcs: 'git',
);

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(useMaterial3: true),
    home: child,
  );
}

void main() {
  testWidgets('connections screen shows an empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeConnectionsControllerProvider.overrideWith(
            () => _FakeConnectionsController(const []),
          ),
        ],
        child: _app(const OpenCodeConnectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No OpenCode connections'), findsOneWidget);
    expect(find.text('Pair'), findsWidgets);
  });

  testWidgets('connections screen renders a saved connection', (tester) async {
    final connection = OpenCodeConnection(
      id: 'connection-1',
      name: 'Home PC',
      baseUrl: 'http://192.168.1.10:4096',
      tokenRef: 'token',
      lastSeen: DateTime(2026, 1, 2, 3, 4),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeConnectionsControllerProvider.overrideWith(
            () => _FakeConnectionsController([connection]),
          ),
        ],
        child: _app(const OpenCodeConnectionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home PC'), findsOneWidget);
    expect(find.text('http://192.168.1.10:4096'), findsOneWidget);
    expect(find.textContaining('Last seen'), findsOneWidget);
    expect(find.text('No OpenCode connections'), findsNothing);
  });

  testWidgets('projects screen lists projects and opens a project', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeProjectsControllerProvider('connection-1').overrideWith(
            () => _FakeProjectsController(
              const OpenCodeProjectsState(
                connection: _connection,
                projects: [_project],
              ),
            ),
          ),
        ],
        child: _app(const OpenCodeProjectsScreen(connectionId: 'connection-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('AgentPort'), findsOneWidget);
    expect(find.text(r'C:\Users\dushc\Desktop\AgentPort'), findsOneWidget);
  });

  testWidgets('project sessions screen shows the create button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeProjectSessionsControllerProvider((
            connectionId: 'connection-1',
            projectId: 'project-1',
          )).overrideWith(
            () => _FakeProjectSessionsController(
              const OpenCodeProjectSessionsState(
                connection: _connection,
                project: _project,
                sessions: [OpenCodeSession(id: 'ses_1', title: 'Fix tests')],
              ),
            ),
          ),
        ],
        child: _app(
          const OpenCodeProjectSessionsScreen(
            connectionId: 'connection-1',
            projectId: 'project-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fix tests'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
  });

  testWidgets('manual pairing form validates the URL and password', (
    tester,
  ) async {
    final controller = _FakeConnectionsController(const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openCodeConnectionsControllerProvider.overrideWith(() => controller),
        ],
        child: _app(
          const OpenCodePairScreen(initialMode: OpenCodePairMode.manual),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final connectButton = find.byKey(const Key('openCodeConnectButton'));
    await tester.ensureVisible(connectButton);
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(find.text('Enter the server URL.'), findsOneWidget);
    expect(find.text('Enter the service password.'), findsOneWidget);
    expect(controller.manualCalls, 0);

    await tester.enterText(
      find.byKey(const Key('openCodeUrlField')),
      'ftp://example.com',
    );
    await tester.enterText(
      find.byKey(const Key('openCodePasswordField')),
      'secret',
    );
    await tester.ensureVisible(connectButton);
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(find.text('Use an http:// or https:// URL.'), findsOneWidget);
    expect(controller.manualCalls, 0);
  });
}
