import 'package:agentport/domain/entities/marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

MarketplacePlugin _plugin({required String marketplaceId, String? author}) {
  return MarketplacePlugin(
    id: '$marketplaceId/plugin',
    marketplaceId: marketplaceId,
    marketplaceName: 'Marketplace',
    name: 'plugin',
    description: '',
    author: author,
    source: const PluginSource(
      kind: MarketplaceSourceKind.path,
      rawJson: '"./plugin"',
      path: './plugin',
    ),
    installed: false,
    enabled: true,
    mcpStatus: PluginMcpStatus.remote,
    lastSeenAt: DateTime(2026),
  );
}

void main() {
  group('MarketplacePlugin.trustLevel', () {
    test('trusts only the official marketplace and Anthropic author', () {
      expect(
        _plugin(
          marketplaceId: kOfficialMarketplaceId,
          author: 'Anthropic',
        ).trustLevel,
        TrustLevel.anthropic,
      );
      expect(
        _plugin(
          marketplaceId: kOfficialMarketplaceId,
          author: 'Not Anthropic',
        ).trustLevel,
        TrustLevel.verifiedPartner,
      );
    });

    test('never trusts plugins from custom marketplaces', () {
      expect(
        _plugin(marketplaceId: 'custom', author: 'Anthropic').trustLevel,
        TrustLevel.community,
      );
    });
  });
}
