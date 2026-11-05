import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectionsTitle)),
      body: EmptyState(
        icon: Icons.qr_code_scanner_rounded,
        title: l10n.connectionsEmptyTitle,
        body: l10n.connectionsEmptyBody,
        action: FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.connectionsComingSoon)));
          },
          icon: const Icon(Icons.link_rounded),
          label: Text(l10n.connectionsPair),
        ),
      ),
    );
  }
}
