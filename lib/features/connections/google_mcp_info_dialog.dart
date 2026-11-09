import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/google_mcp.dart';
import '../../l10n/generated/app_localizations.dart';

Future<void> showGoogleMcpInfoDialog(
  BuildContext context, {
  List<GoogleMcpService> services = const [],
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => GoogleMcpInfoDialog(services: services),
  );
}

class GoogleMcpInfoDialog extends StatelessWidget {
  const GoogleMcpInfoDialog({this.services = const [], super.key});

  final List<GoogleMcpService> services;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visibleServices = services.isEmpty ? googleMcpServices : services;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.googleMcpInstructionsTitle)),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.googleMcpInstructionsIntro),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.googleMcpPreviewNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _open(context, googleWorkspacePreviewUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(l10n.googleMcpOpenPreview),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Step(number: 1, text: l10n.googleMcpStepPreview),
              _Step(number: 2, text: l10n.googleMcpStepProject),
              _Step(number: 3, text: l10n.googleMcpStepApis),
              Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _open(context, googleCloudApisUrl),
                    icon: const Icon(Icons.api_rounded, size: 16),
                    label: Text(l10n.googleMcpOpenApis),
                  ),
                ),
              ),
              _Step(number: 4, text: l10n.googleMcpStepConsent),
              _Step(number: 5, text: l10n.googleMcpStepClient),
              _Step(number: 6, text: l10n.googleMcpStepRedirect),
              _Step(number: 7, text: l10n.googleMcpStepAgent),
              _Step(number: 8, text: l10n.googleMcpStepPaste),
              const SizedBox(height: 12),
              Text(
                l10n.googleMcpServicesTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final service in visibleServices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    '${service.apiHost}  ·  ${service.mcpHost}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.googleMcpRedirectUri,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const GoogleMcpRedirectUriBox(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _open(context, googleMcpSetupDocsUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(l10n.googleMcpOpenDocs),
        ),
        TextButton.icon(
          onPressed: () => _open(context, googleCloudConsoleUrl),
          icon: const Icon(Icons.cloud_outlined, size: 18),
          label: Text(l10n.googleMcpOpenConsole),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonDone),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).googleMcpOpenLinkFailed),
        ),
      );
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class GoogleMcpRedirectUriBox extends StatelessWidget {
  const GoogleMcpRedirectUriBox({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              googleMcpRedirectUri,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: googleMcpRedirectUri),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.googleMcpCopied)));
              }
            },
            tooltip: l10n.googleMcpCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
