import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatsTitle)),
      body: EmptyState(
        icon: Icons.forum_outlined,
        title: l10n.chatsEmptyTitle,
        body: l10n.chatsEmptyBody,
        action: FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.newChatComingSoon)));
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.newChat),
        ),
      ),
    );
  }
}
