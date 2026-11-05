import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Language picker shared by onboarding and settings.
///
/// `null` means "follow the system language".
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({
    required this.localeCode,
    required this.onSelected,
    super.key,
  });

  final String? localeCode;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<String>(
      tooltip: l10n.language,
      initialValue: localeCode ?? 'system',
      onSelected: (value) => onSelected(value == 'system' ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'system', child: Text(l10n.languageSystem)),
        PopupMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
        PopupMenuItem(value: 'ru', child: Text(l10n.languageRussian)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, size: 18),
            const SizedBox(width: 8),
            Text(switch (localeCode) {
              'en' => l10n.languageEnglish,
              'ru' => l10n.languageRussian,
              _ => l10n.languageSystem,
            }, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
