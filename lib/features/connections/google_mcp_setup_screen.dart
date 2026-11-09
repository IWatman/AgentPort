import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/mcp_server_repository.dart';
import '../../domain/entities/google_mcp.dart';
import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';
import '../../l10n/generated/app_localizations.dart';
import 'google_mcp_info_dialog.dart';
import 'google_mcp_text.dart';
import 'mcp_connections_controller.dart';
import 'mcp_text.dart';

class GoogleMcpSetupScreen extends ConsumerStatefulWidget {
  const GoogleMcpSetupScreen({super.key});

  @override
  ConsumerState<GoogleMcpSetupScreen> createState() =>
      _GoogleMcpSetupScreenState();
}

class _GoogleMcpSetupScreenState extends ConsumerState<GoogleMcpSetupScreen> {
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _selected = <String>{'calendar', 'gmail'};
  var _secretVisible = false;
  var _saving = false;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  List<GoogleMcpService> get _selectedServices => [
    for (final service in googleMcpServices)
      if (_selected.contains(service.id)) service,
  ];

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final clientId = _clientId.text.trim();
    final clientSecret = _clientSecret.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.googleMcpClientRequired)));
      return;
    }
    final services = _selectedServices;
    if (services.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.googleMcpServiceRequired)));
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(mcpServerRepositoryProvider);
      for (final service in services) {
        final server = await repository.saveServer(
          id: service.serverId,
          name: service.serverName,
          url: service.url,
          transport: McpTransport.http,
          authType: McpAuthType.oauth,
        );
        await repository.saveOAuthClient(
          server.id,
          googleOAuthClientConfig(
            clientId: clientId,
            clientSecret: clientSecret,
            service: service,
          ),
        );
      }
      await ref.read(mcpConnectionsControllerProvider.notifier).reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.googleMcpCreated)));
      context.go('/connections');
    } on McpFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mcpFailureText(l10n, error))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final allSelected = _selected.length == googleMcpServices.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.googleMcpTitle),
        actions: [
          IconButton(
            onPressed: () =>
                showGoogleMcpInfoDialog(context, services: _selectedServices),
            tooltip: l10n.googleMcpHowTo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.workspaces_outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.googleMcpIntro,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.googleMcpPreviewNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.googleMcpClientCardTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                    enabled: !_saving,
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
                    enabled: !_saving,
                    obscureText: !_secretVisible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l10n.googleMcpClientSecret,
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _secretVisible = !_secretVisible),
                        tooltip: _secretVisible
                            ? l10n.commonHide
                            : l10n.commonShow,
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
                          services: _selectedServices,
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.googleMcpServicesTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        if (allSelected) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(
                              googleMcpServices.map((service) => service.id),
                            );
                        }
                      }),
                child: Text(l10n.googleMcpSelectAll),
              ),
            ],
          ),
          Text(
            l10n.googleMcpServicesHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final service in googleMcpServices)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                value: _selected.contains(service.id),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.add(service.id);
                        } else {
                          _selected.remove(service.id);
                        }
                      }),
                secondary: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  child: Icon(
                    _serviceIcon(service.id),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(googleMcpServiceName(l10n, service)),
                subtitle: Text(googleMcpServiceDescription(l10n, service)),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link_rounded),
            label: Text(l10n.googleMcpCreate),
          ),
        ],
      ),
    );
  }

  IconData _serviceIcon(String id) {
    return switch (id) {
      'gmail' => Icons.mail_outline_rounded,
      'calendar' => Icons.calendar_month_outlined,
      'drive' => Icons.folder_outlined,
      'docs' => Icons.description_outlined,
      'sheets' => Icons.table_chart_outlined,
      'slides' => Icons.slideshow_outlined,
      'chat' => Icons.forum_outlined,
      'people' => Icons.people_outline_rounded,
      'classroom' => Icons.school_outlined,
      _ => Icons.extension_outlined,
    };
  }
}
