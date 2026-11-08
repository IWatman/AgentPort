import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import 'opencode_failure_text.dart';
import 'opencode_format.dart';
import 'opencode_insights_controller.dart';

Future<void> showOpenCodeContextSheet(
  BuildContext context, {
  required String connectionId,
  required OpenCodeSession session,
  required List<OpenCodeMessage> messages,
  required List<String> systemPrompts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _ContextSheet(
      connectionId: connectionId,
      session: session,
      messages: messages,
      systemPrompts: systemPrompts,
    ),
  );
}

Future<void> showOpenCodeExtensionsSheet(
  BuildContext context, {
  required String connectionId,
  required String? directory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _ExtensionsSheet(connectionId: connectionId, directory: directory),
  );
}

class _ContextSheet extends ConsumerWidget {
  const _ContextSheet({
    required this.connectionId,
    required this.session,
    required this.messages,
    required this.systemPrompts,
  });

  final String connectionId;
  final OpenCodeSession session;
  final List<OpenCodeMessage> messages;
  final List<String> systemPrompts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final insights = ref.watch(
      openCodeSessionInsightsProvider((
        connectionId: connectionId,
        sessionId: session.id,
        directory: session.directory,
        modelId: session.modelId,
        modelProviderId: session.modelProviderId,
      )),
    );
    final value = insights.value;
    final current = value?.session ?? session;
    final userMessages = messages.where((message) => message.isUser).length;
    final assistantMessages = messages.length - userMessages;
    final totalTokens = current.tokensTotal;
    OpenCodeMessage? latestAssistant;
    for (final message in messages.reversed) {
      if (!message.isUser && message.contextTokens != null) {
        latestAssistant = message;
        break;
      }
    }
    final currentContextTokens = latestAssistant?.contextTokens;
    final contextLimit = value?.contextLimit;
    final usage =
        contextLimit == null ||
            contextLimit <= 0 ||
            currentContextTokens == null
        ? null
        : (currentContextTokens / contextLimit).clamp(0.0, 1.0);
    final modelTitle =
        value?.modelName ?? current.modelId ?? l10n.openCodeContextUnknown;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            l10n.openCodeContextTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            children: [
              _InfoRow(label: l10n.openCodeContextSession, value: current.id),
              _InfoRow(
                label: l10n.openCodeContextProject,
                value: current.directory ?? current.project ?? '-',
              ),
              _InfoRow(
                label: l10n.openCodeContextProvider,
                value: current.modelProviderId ?? l10n.openCodeContextUnknown,
              ),
              _InfoRow(label: l10n.openCodeContextModel, value: modelTitle),
              _InfoRow(
                label: l10n.openCodeContextAgent,
                value: current.agentId ?? l10n.openCodeContextUnknown,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            children: [
              Text(
                l10n.openCodeContextUsage,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (usage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: usage,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.openCodeContextTokensUsed(_formatCount(currentContextTokens!), _formatCount(contextLimit!))}'
                  ' · ${(usage * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (currentContextTokens != null)
                Text(
                  l10n.openCodeContextTokensTotal(
                    _formatCount(currentContextTokens),
                  ),
                  style: theme.textTheme.bodyMedium,
                )
              else
                Text(
                  l10n.openCodeContextNotReported,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: l10n.openCodeContextSessionTotals,
            children: [
              _InfoRow(
                label: l10n.openCodeContextInput,
                value: _formatCount(current.tokensInput ?? 0),
              ),
              _InfoRow(
                label: l10n.openCodeContextOutput,
                value: _formatCount(current.tokensOutput ?? 0),
              ),
              _InfoRow(
                label: l10n.openCodeContextReasoning,
                value: _formatCount(current.tokensReasoning ?? 0),
              ),
              _InfoRow(
                label: l10n.openCodeContextCacheRead,
                value: _formatCount(current.tokensCacheRead ?? 0),
              ),
              _InfoRow(
                label: l10n.openCodeContextCacheWrite,
                value: _formatCount(current.tokensCacheWrite ?? 0),
              ),
              const Divider(height: 18),
              _InfoRow(
                label: l10n.openCodeContextTotal,
                value: _formatCount(totalTokens),
                emphasize: true,
              ),
              if (current.cost != null)
                _InfoRow(
                  label: l10n.openCodeContextCost,
                  value: '\$${current.cost!.toStringAsFixed(2)}',
                ),
              if (value != null &&
                  value.totalCost != null &&
                  value.totalCost! > (current.cost ?? 0) + 0.0001)
                _InfoRow(
                  label: l10n.openCodeContextCostWithSubagents,
                  value: '\$${value.totalCost!.toStringAsFixed(2)}',
                  emphasize: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: l10n.openCodeContextMessages,
            children: [
              _InfoRow(
                label: l10n.openCodeContextAllMessages,
                value: _formatCount(messages.length),
              ),
              _InfoRow(
                label: l10n.openCodeContextUserMessages,
                value: _formatCount(userMessages),
              ),
              _InfoRow(
                label: l10n.openCodeContextAssistantMessages,
                value: _formatCount(assistantMessages),
              ),
              if (value != null && value.contextMessageCount > 0)
                _InfoRow(
                  label: l10n.openCodeContextWindowMessages,
                  value: _formatCount(value.contextMessageCount),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: l10n.openCodeContextDates,
            children: [
              if (current.createdAt != null)
                _InfoRow(
                  label: l10n.openCodeContextCreated,
                  value: openCodeDateText(context, current.createdAt!),
                ),
              if (current.updatedAt != null)
                _InfoRow(
                  label: l10n.openCodeContextUpdated,
                  value: openCodeDateText(context, current.updatedAt!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            title: l10n.openCodeContextSystemPrompt,
            children: [
              if (systemPrompts.isNotEmpty)
                for (final prompt in systemPrompts) _SystemPrompt(text: prompt)
              else if (insights.isLoading && value == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (value == null)
                _RetryContext(
                  message: insights.hasError
                      ? openCodeFailureText(l10n, insights.error!)
                      : l10n.openCodeContextSystemPromptEmpty,
                  onRetry: () => ref.invalidate(
                    openCodeSessionInsightsProvider((
                      connectionId: connectionId,
                      sessionId: session.id,
                      directory: session.directory,
                      modelId: session.modelId,
                      modelProviderId: session.modelProviderId,
                    )),
                  ),
                )
              else
                Text(
                  l10n.openCodeContextSystemPromptEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtensionsSheet extends ConsumerWidget {
  const _ExtensionsSheet({required this.connectionId, required this.directory});

  final String connectionId;
  final String? directory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final key = (connectionId: connectionId, directory: directory);
    final mcp = ref.watch(openCodeMcpServersProvider(key));
    final plugins = ref.watch(openCodePluginsProvider(key));
    final skills = ref.watch(openCodeSkillsProvider(key));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Text(
            l10n.openCodeExtensionsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (directory != null && directory!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              directory!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ExtensionCard<OpenCodeMcpServer>(
            icon: Icons.dns_outlined,
            title: l10n.openCodeExtensionsMcp,
            loadable: mcp,
            builder: (servers) => _McpList(servers: servers),
            onRetry: () => ref.invalidate(openCodeMcpServersProvider(key)),
          ),
          const SizedBox(height: 12),
          _ExtensionCard<OpenCodePlugin>(
            icon: Icons.extension_outlined,
            title: l10n.openCodeExtensionsPlugins,
            loadable: plugins,
            builder: (items) => _PluginList(plugins: items),
            onRetry: () => ref.invalidate(openCodePluginsProvider(key)),
          ),
          const SizedBox(height: 12),
          _SkillsSection(keyValue: key, loadable: skills),
          const SizedBox(height: 12),
          _InfoCard(
            title: l10n.openCodeExtensionsLsp,
            children: [
              Text(
                l10n.openCodeExtensionsLspUnavailable,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillsSection extends ConsumerStatefulWidget {
  const _SkillsSection({required this.keyValue, required this.loadable});

  final OpenCodeExtensionKey keyValue;
  final AsyncValue<List<OpenCodeSkill>> loadable;

  @override
  ConsumerState<_SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends ConsumerState<_SkillsSection> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skills = widget.loadable.value ?? const <OpenCodeSkill>[];
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? skills
        : skills
              .where(
                (skill) =>
                    skill.name.toLowerCase().contains(query) ||
                    skill.description.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final visible = filtered.take(80).toList(growable: false);

    return _InfoCard(
      title: l10n.openCodeExtensionsSkills,
      children: [
        if (widget.loadable.isLoading && skills.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.loadable.hasError)
          _RetryContext(
            message: openCodeFailureText(l10n, widget.loadable.error!),
            onRetry: () =>
                ref.invalidate(openCodeSkillsProvider(widget.keyValue)),
          )
        else ...[
          Text(
            l10n.openCodeExtensionsSkillsCount(_formatCount(skills.length)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: l10n.openCodeExtensionsSearchSkills,
            ),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            Text(
              l10n.openCodeExtensionsNoSkills,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final skill in visible)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(skill.name),
                subtitle: skill.description.isEmpty
                    ? null
                    : Text(
                        skill.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
          if (filtered.length > visible.length)
            Text(
              l10n.openCodeExtensionsMoreSkills(
                filtered.length - visible.length,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _McpList extends StatelessWidget {
  const _McpList({required this.servers});

  final List<OpenCodeMcpServer> servers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (servers.isEmpty) {
      return Text(
        l10n.openCodeExtensionsNoMcp,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      children: [
        for (final server in servers)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              server.isConnected
                  ? Icons.check_circle_outline_rounded
                  : server.hasFailed
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_empty_rounded,
              size: 20,
              color: server.isConnected
                  ? theme.colorScheme.secondary
                  : server.hasFailed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(server.displayName),
            subtitle: server.error == null || server.error!.isEmpty
                ? Text(_mcpStatusText(l10n, server.status))
                : Text(
                    _cleanMcpError(server.error!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
      ],
    );
  }
}

class _PluginList extends StatelessWidget {
  const _PluginList({required this.plugins});

  final List<OpenCodePlugin> plugins;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final external = plugins
        .where((plugin) => !plugin.isBuiltin)
        .toList(growable: false);
    final builtinCount = plugins.length - external.length;
    if (plugins.isEmpty) {
      return Text(
        l10n.openCodeExtensionsNoPlugins,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (external.isEmpty)
          Text(
            l10n.openCodeExtensionsNoExternalPlugins,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final plugin in external)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                plugin.hasFailed
                    ? Icons.error_outline_rounded
                    : Icons.extension_rounded,
                size: 20,
                color: plugin.hasFailed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(plugin.displayName),
              subtitle: Text(
                plugin.hasFailed
                    ? (plugin.error ?? l10n.openCodeExtensionsFailed)
                    : (plugin.version ?? plugin.sourceType),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        if (builtinCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            l10n.openCodeExtensionsBuiltinPlugins(_formatCount(builtinCount)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExtensionCard<T> extends StatelessWidget {
  const _ExtensionCard({
    required this.icon,
    required this.title,
    required this.loadable,
    required this.builder,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final AsyncValue<List<T>> loadable;
  final Widget Function(List<T>) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _InfoCard(
      title: title,
      leading: Icon(icon, size: 20),
      trailing: loadable.value == null
          ? null
          : Text(
              _formatCount(loadable.value!.length),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      children: [
        if (loadable.isLoading && loadable.value == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (loadable.hasError && loadable.value == null)
          _RetryContext(
            message: openCodeFailureText(l10n, loadable.error!),
            onRetry: onRetry,
          )
        else
          builder(loadable.value ?? const []),
      ],
    );
  }
}

String _cleanMcpError(String error) {
  final replacement = error.indexOf('\uFFFD');
  if (replacement < 0) {
    return error;
  }
  return error
      .substring(0, replacement)
      .trim()
      .replaceAll(RegExp(r'[:\-]\s*$'), '');
}

String _mcpStatusText(AppLocalizations l10n, String status) {
  return switch (status) {
    'connected' => l10n.openCodeExtensionsConnected,
    'failed' => l10n.openCodeExtensionsFailed,
    'needs-auth' => l10n.openCodeExtensionsNeedsAuth,
    'pending' => l10n.openCodeExtensionsPending,
    'disabled' => l10n.openCodeExtensionsDisabled,
    _ => status,
  };
}

class _SystemPrompt extends StatelessWidget {
  const _SystemPrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            code: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    this.title,
    this.leading,
    this.trailing,
    required this.children,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              style: emphasize
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryContext extends StatelessWidget {
  const _RetryContext({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).commonRetry),
        ),
      ],
    );
  }
}

String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[index]);
  }
  return buffer.toString();
}
