import 'package:agentport/domain/entities/ai_provider.dart';
import 'package:agentport/features/providers/provider_editor_screen.dart';
import 'package:agentport/features/providers/providers_controller.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeProvidersController extends ProvidersController {
  @override
  Future<List<AiProvider>> build() async => const [];
}

void main() {
  testWidgets('preset query prefills a new provider', (tester) async {
    final router = GoRouter(
      initialLocation: '/providers/new?preset=groq',
      routes: [
        GoRoute(
          path: '/providers/new',
          builder: (context, state) => ProviderEditorScreen(
            initialPresetId: state.uri.queryParameters['preset'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providersControllerProvider.overrideWith(
            _FakeProvidersController.new,
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextField field(String key) {
      return tester.widget<TextField>(find.byKey(Key(key)));
    }

    expect(field('providerNameField').controller?.text, 'Groq');
    expect(
      field('providerBaseUrlField').controller?.text,
      'https://api.groq.com/openai/v1',
    );
    expect(find.byKey(const Key('providerModelField')), findsNothing);
    expect(find.text('PRESETS'), findsOneWidget);
  });
}
