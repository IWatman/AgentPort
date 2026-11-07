import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../updates/update_prompt_host.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(text: l10n.settingsSectionApp),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(l10n.language),
                  subtitle: Text(_languageLabel(l10n, settings.localeCode)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context, ref, settings.localeCode),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_rounded),
                  title: Text(l10n.settingsAutoUpdate),
                  subtitle: Text(l10n.settingsAutoUpdateSubtitle),
                  value: settings.autoUpdateCheck,
                  onChanged: (value) => ref
                      .read(settingsControllerProvider.notifier)
                      .setAutoUpdateCheck(value),
                ),
                const Divider(indent: 16, endIndent: 16),
                const UpdateCheckTile(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(text: l10n.settingsSectionAi),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: Text(l10n.providersTitle),
                  subtitle: Text(l10n.settingsProvidersSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/providers'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.terminal_rounded),
                  title: Text(l10n.openCodeTitle),
                  subtitle: Text(l10n.settingsOpenCodeSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/opencode'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(text: l10n.settingsSectionAbout),
          Card(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = _version(snapshot);
                return ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.settingsAbout),
                  subtitle: Text(l10n.settingsVersion(version)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/about'),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              l10n.aboutMadeWith,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _languageLabel(AppLocalizations l10n, String? code) {
    return switch (code) {
      'en' => l10n.languageEnglish,
      'ru' => l10n.languageRussian,
      _ => l10n.languageSystem,
    };
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        Widget option(String value, String label) {
          final checked = (current ?? 'system') == value;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(value),
            child: Row(
              children: [
                Icon(
                  checked
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(label),
              ],
            ),
          );
        }

        return SimpleDialog(
          title: Text(l10n.language),
          children: [
            option('system', l10n.languageSystem),
            option('en', l10n.languageEnglish),
            option('ru', l10n.languageRussian),
          ],
        );
      },
    );

    if (selected == null) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setLocale(selected == 'system' ? null : selected);
  }

  String _version(AsyncSnapshot<PackageInfo> snapshot) {
    if (!snapshot.hasData) {
      return '—';
    }
    final info = snapshot.data!;
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
