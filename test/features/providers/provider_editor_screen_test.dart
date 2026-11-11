import 'package:agentport/domain/entities/ai_provider.dart';
import 'package:agentport/domain/entities/provider_oauth.dart';
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

  testWidgets('offers every account method and pins official endpoints', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/providers/new',
      routes: [
        GoRoute(
          path: '/providers/new',
          builder: (context, state) => const ProviderEditorScreen(),
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

    Finder authDropdown() =>
        find.byType(DropdownButtonFormField<ProviderAuthMethod>);

    TextField field(String key) {
      return tester.widget<TextField>(find.byKey(Key(key)));
    }

    await tester.tap(authDropdown());
    await tester.pumpAndSettle();
    expect(find.text('API key'), findsWidgets);
    expect(find.text('ChatGPT account'), findsWidgets);
    expect(find.text('OpenRouter account'), findsWidgets);

    await tester.tap(find.text('OpenRouter account').last);
    await tester.pumpAndSettle();

    expect(
      field('providerBaseUrlField').controller?.text,
      'https://openrouter.ai/api/v1',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('providerOpenRouterModelField')),
          )
          .controller
          ?.text,
      'openai/gpt-4o-mini',
    );
    expect(find.text('Continue with OpenRouter'), findsOneWidget);
    expect(find.byKey(const Key('providerApiKeyField')), findsNothing);

    await tester.tap(authDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChatGPT account').last);
    await tester.pumpAndSettle();

    expect(
      field('providerBaseUrlField').controller?.text,
      'https://api.openai.com/v1',
    );
    expect(find.text('Continue with ChatGPT'), findsOneWidget);
    expect(find.byKey(const Key('providerOpenRouterModelField')), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byKey(const Key('providerApiKeyField')), findsNothing);
  });
}
