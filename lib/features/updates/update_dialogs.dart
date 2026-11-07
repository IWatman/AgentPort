import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'update_controller.dart';

/// Shows the release notes and starts the download/install flow.
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref) async {
  final release = ref.read(updateControllerProvider).value?.release;
  if (release == null) {
    return;
  }

  final l10n = AppLocalizations.of(context);
  final download = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.updatesAvailableTitle(release.version)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (release.name.isNotEmpty && release.name != release.tagName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      release.name,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                if (release.notes.trim().isEmpty)
                  Text(l10n.updatesNoNotes)
                else ...[
                  Text(
                    l10n.updatesNotesTitle,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: release.notes,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme)
                        .copyWith(p: theme.textTheme.bodySmall),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.updatesLater),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.updatesDownload),
          ),
        ],
      );
    },
  );

  if (download != true) {
    ref.read(updateControllerProvider.notifier).dismiss();
    return;
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _UpdateProgressDialog(),
  );
}

class _UpdateProgressDialog extends ConsumerStatefulWidget {
  const _UpdateProgressDialog();

  @override
  ConsumerState<_UpdateProgressDialog> createState() =>
      _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends ConsumerState<_UpdateProgressDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  Future<void> _start() async {
    final notifier = ref.read(updateControllerProvider.notifier);
    try {
      await notifier.downloadAndInstall();
    } catch (_) {
      // The controller stores the failure for the dialog below.
    }
    if (!mounted) {
      return;
    }
    final state = ref.read(updateControllerProvider).value;
    if (state != null &&
        state.error == null &&
        !state.permissionNeeded &&
        state.phase == UpdatePhase.idle) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(updateControllerProvider).value;

    if (state?.permissionNeeded == true) {
      return AlertDialog(
        title: Text(l10n.updatesPermissionTitle),
        content: Text(l10n.updatesPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.updatesClose),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(updateControllerProvider.notifier)
                  .openInstallSettings();
            },
            child: Text(l10n.updatesOpenSettings),
          ),
        ],
      );
    }

    final error = state?.error;
    if (error != null) {
      return AlertDialog(
        title: Text(l10n.updatesFailedTitle),
        content: Text(error.detail ?? error.kind.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.updatesClose),
          ),
          FilledButton(
            onPressed: () {
              ref.read(updateControllerProvider.notifier).clearError();
              _start();
            },
            child: Text(l10n.updatesRetry),
          ),
        ],
      );
    }

    final phase = state?.phase ?? UpdatePhase.downloading;
    final progress = state?.progress ?? 0;
    final percent = (progress * 100).round();
    final total = state?.totalBytes;

    return AlertDialog(
      title: Text(
        phase == UpdatePhase.installing
            ? l10n.updatesInstalling
            : l10n.updatesDownloading(percent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total == null ? null : progress),
          const SizedBox(height: 12),
          Text(
            phase == UpdatePhase.installing
                ? l10n.updatesInstallerHint
                : l10n.updatesDoNotClose,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
