import 'package:agentport/domain/entities/marketplace.dart';
import 'package:agentport/features/marketplace/marketplace_controller.dart';
import 'package:agentport/features/marketplace/marketplace_screen.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeController extends MarketplaceController {
  _FakeController(this.plugins, {this.view});

  final List<MarketplacePlugin> plugins;
  final MarketplaceViewState? view;

  @override
  Future<MarketplaceViewState> build() async {
    if (view != null) {
      return view!;
    }
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
        plugins: plugins,
      ),
    );
  }
}

MarketplacePlugin _plugin({
  required String name,
  required PluginMcpStatus status,
  bool installed = false,
}) {
  return MarketplacePlugin(
    id: name,
    marketplaceId: kOfficialMarketplaceId,
    marketplaceName: 'Official',
    name: name,
    description: 'Description for $name',
    source: const PluginSource(
      kind: MarketplaceSourceKind.path,
      rawJson: '"./plugin"',
    ),
    installed: installed,
    enabled: true,
    mcpStatus: status,
    lastSeenAt: DateTime(2026),
  );
}

void main() {
  testWidgets('marketplaces tab renders the add form and built-in catalog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceControllerProvider.overrideWith(
            () => _FakeController(const []),
          ),
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

    expect(find.text('Plugins'), findsWidgets);
    await tester.tap(find.text('Marketplaces'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Add'), findsWidgets);
    expect(find.text('Official'), findsOneWidget);
  });

  testWidgets('plugins tab hides plugins that cannot run on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceControllerProvider.overrideWith(
            () => _FakeController([
              _plugin(name: 'Remote plugin', status: PluginMcpStatus.remote),
              _plugin(name: 'Local plugin', status: PluginMcpStatus.stdio),
              _plugin(name: 'No MCP plugin', status: PluginMcpStatus.none),
              _plugin(name: 'Unknown plugin', status: PluginMcpStatus.unknown),
              _plugin(
                name: 'Installed legacy',
                status: PluginMcpStatus.none,
                installed: true,
              ),
            ]),
          ),
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

    expect(find.text('Remote plugin'), findsOneWidget);
    expect(find.text('Installed legacy'), findsOneWidget);
    expect(find.text('Local plugin'), findsNothing);
    expect(find.text('No MCP plugin'), findsNothing);
    expect(find.text('Unknown plugin'), findsNothing);
  });

  testWidgets('plugins tab shows compatibility progress while scanning', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketplaceControllerProvider.overrideWith(
            () => _FakeController(
              const [],
              view: MarketplaceViewState(
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
                  plugins: [
                    _plugin(
                      name: 'Remote plugin',
                      status: PluginMcpStatus.remote,
                    ),
                  ],
                ),
                scanningCompatibility: true,
                scanTotal: 10,
                scanDone: 2,
              ),
            ),
          ),
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

    expect(find.text('Checked 2 of 10 plugins'), findsOneWidget);
  });
}
