import 'package:flutter/material.dart';

import '../../domain/entities/google_mcp.dart';
import '../../domain/entities/mcp_oauth.dart';
import '../../l10n/generated/app_localizations.dart';
import 'google_mcp_info_dialog.dart';

Future<McpOAuthClientConfig?> showGoogleMcpClientDialog(
  BuildContext context, {
  required GoogleMcpService service,
  McpOAuthClientConfig? initial,
}) {
  return showDialog<McpOAuthClientConfig>(
    context: context,
    builder: (context) =>
        _GoogleMcpClientDialog(service: service, initial: initial),
  );
}

class _GoogleMcpClientDialog extends StatefulWidget {
  const _GoogleMcpClientDialog({required this.service, this.initial});

  final GoogleMcpService service;
  final McpOAuthClientConfig? initial;

  @override
  State<_GoogleMcpClientDialog> createState() => _GoogleMcpClientDialogState();
}

class _GoogleMcpClientDialogState extends State<_GoogleMcpClientDialog> {
  late final _clientId = TextEditingController(
    text: widget.initial?.clientId ?? '',
  );
  late final _clientSecret = TextEditingController(
    text: widget.initial?.clientSecret ?? '',
  );
  var _secretVisible = false;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final clientId = _clientId.text.trim();
    final clientSecret = _clientSecret.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.googleMcpClientRequired)));
      return;
    }
    Navigator.of(context).pop(
      googleOAuthClientConfig(
        clientId: clientId,
        clientSecret: clientSecret,
        service: widget.service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.googleMcpConfigure),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.googleMcpClientCardHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientId,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.googleMcpClientId,
                  hintText: l10n.googleMcpClientIdHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientSecret,
                obscureText: !_secretVisible,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.googleMcpClientSecret,
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _secretVisible = !_secretVisible),
                    tooltip: _secretVisible ? l10n.commonHide : l10n.commonShow,
                    icon: Icon(
                      _secretVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.googleMcpRedirectUri,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showGoogleMcpInfoDialog(
                      context,
                      services: [widget.service],
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: Text(l10n.googleMcpHowTo),
                  ),
                ],
              ),
              const GoogleMcpRedirectUriBox(),
              const SizedBox(height: 6),
              Text(
                l10n.googleMcpRedirectHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
