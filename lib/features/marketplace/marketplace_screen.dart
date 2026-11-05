import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.marketplaceTitle),
          bottom: TabBar(
            dividerColor: Theme.of(context).colorScheme.outlineVariant,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: l10n.marketplacePluginsTab),
              Tab(text: l10n.marketplaceMarketplacesTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EmptyState(
              icon: Icons.extension_outlined,
              title: l10n.marketplaceEmptyTitle,
              body: l10n.marketplaceEmptyBody,
            ),
            EmptyState(
              icon: Icons.storefront_outlined,
              title: l10n.marketplaceMarketplacesEmptyTitle,
              body: l10n.marketplaceMarketplacesEmptyBody,
            ),
          ],
        ),
      ),
    );
  }
}
