import 'package:agentport/domain/entities/marketplace.dart';
import 'package:agentport/features/marketplace/marketplace_controller.dart';
import 'package:agentport/features/marketplace/marketplace_screen.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController extends MarketplaceController {
  @override
  Future<MarketplaceViewState> build() async {
    return MarketplaceViewState(
      catalog: MarketplaceCatalog(
        marketplaces: [
          Marketplace(
            id: kOfficialMarketplaceId,
            name: 'Official',
            description: 'Official catalog',
            sourceUrl: kOfficialMarketplaceSource,
            manifestUrl: kOfficialMarketplaceManifest,
            builtIn: true,
            enabled: true,
            lastSyncedAt: DateTime(2026),
            createdAt: DateTime(2026),
          ),
        ],
        plugins: const [],
      ),
    );
  }
}

void main() {
  testWidgets('marketplaces tab renders the add form and built-in catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceControllerProvider.overrideWith(_FakeController.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MarketplaceScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plugins'), findsOneWidget);
    await tester.tap(find.text('Marketplaces'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Add'), findsWidgets);
    expect(find.text('Official'), findsOneWidget);
  });
}
