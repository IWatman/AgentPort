import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'update_controller.dart';
import 'update_dialogs.dart';

/// Wraps the shell and runs one automatic update check per day.
class UpdatePromptHost extends ConsumerStatefulWidget {
  const UpdatePromptHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends ConsumerState<UpdatePromptHost> {
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _check();
    });
  }

  Future<void> _check() async {
    if (_started || !mounted) {
      return;
    }
    _started = true;
    final release = await ref
        .read(updateControllerProvider.notifier)
        .checkIfDue();
    if (!mounted || release == null) {
      return;
    }
    await showUpdateDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Settings row that checks for updates on demand.
class UpdateCheckTile extends ConsumerWidget {
  const UpdateCheckTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(updateControllerProvider).value;
    final release = state?.release;
    final phase = state?.phase ?? UpdatePhase.idle;

    final subtitle = switch (phase) {
      UpdatePhase.checking => l10n.updatesChecking,
      UpdatePhase.downloading => l10n.updatesDownloading(
        (state!.progress * 100).round(),
      ),
      UpdatePhase.installing => l10n.updatesInstalling,
      UpdatePhase.idle =>
        release == null
            ? l10n.updatesCurrent(state?.currentVersion ?? '—')
            : l10n.updatesAvailableTitle(release.version),
    };

    return ListTile(
      leading: const Icon(Icons.system_update_rounded),
      title: Text(l10n.updatesTitle),
      subtitle: Text(subtitle),
      trailing:
          phase == UpdatePhase.checking ||
              phase == UpdatePhase.downloading ||
              phase == UpdatePhase.installing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: phase == UpdatePhase.idle
          ? () async {
              if (release != null) {
                await showUpdateDialog(context, ref);
                return;
              }
              final notifier = ref.read(updateControllerProvider.notifier);
              try {
                final found = await notifier.check();
                if (!context.mounted) {
                  return;
                }
                if (found != null) {
                  await showUpdateDialog(context, ref);
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.updatesUpToDate)));
                }
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.updatesCheckFailed),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          : null,
    );
  }
}
