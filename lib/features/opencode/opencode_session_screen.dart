import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'opencode_failure_text.dart';
import 'opencode_session_controller.dart';

class OpenCodeSessionScreen extends ConsumerStatefulWidget {
  const OpenCodeSessionScreen({
    required this.connectionId,
    required this.sessionId,
    super.key,
  });

  final String connectionId;
  final String sessionId;

  @override
  ConsumerState<OpenCodeSessionScreen> createState() =>
      _OpenCodeSessionScreenState();
}

class _OpenCodeSessionScreenState extends ConsumerState<OpenCodeSessionScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  String? _lastScrollSignature;

  OpenCodeSessionKey get _key =>
      (connectionId: widget.connectionId, sessionId: widget.sessionId);

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = openCodeSessionControllerProvider(_key);
    final state = ref.watch(provider);
    final value = state.value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value?.session.title ?? l10n.openCodeSessionsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (value != null) ...[
              const SizedBox(height: 2),
              Text(
                value.connection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (value != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: value.isConnected
                    ? l10n.openCodeConnected
                    : l10n.openCodeConnectionLost,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: value.isConnected
                        ? Colors.greenAccent
                        : theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          PopupMenuButton<_SessionMenuAction>(
            enabled: value != null,
            onSelected: (action) => _onMenu(action, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _SessionMenuAction.agent,
                child: Text(l10n.openCodeAgentMenu),
              ),
              PopupMenuItem(
                value: _SessionMenuAction.model,
                child: Text(l10n.openCodeModelMenu),
              ),
            ],
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.openCodeSessionError,
          body: openCodeFailureText(l10n, error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (current) {
          _scheduleScroll(current);
          return Column(
            children: [
              Expanded(
                child:
                    current.messages.isEmpty &&
                        current.streamingText.isEmpty &&
                        !current.busy
                    ? EmptyState(
                        icon: Icons.forum_outlined,
                        title: l10n.openCodeSessionEmptyTitle,
                        body: l10n.openCodeSessionEmptyBody,
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount:
                            current.messages.length +
                            (current.streamingText.isNotEmpty || current.busy
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index < current.messages.length) {
                            return _MessageBubble(
                              message: current.messages[index],
                            );
                          }
                          return _StreamingBubble(
                            text: current.streamingText,
                            busy: current.busy,
                          );
                        },
                      ),
              ),
              if (current.error != null)
                _ErrorBanner(
                  message: openCodeFailureText(l10n, current.error!),
                  retryLabel: l10n.openCodeReconnect,
                  onRetry: () =>
                      unawaited(ref.read(provider.notifier).reload()),
                ),
              if (current.activeTool != null)
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.openCodeToolRunning(current.activeTool!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _Composer(
                controller: _composer,
                busy: current.busy,
                onSend: _send,
                onStop: () => unawaited(ref.read(provider.notifier).stop()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) {
      return;
    }
    _composer.clear();
    unawaited(
      ref.read(openCodeSessionControllerProvider(_key).notifier).send(text),
    );
  }

  void _onMenu(_SessionMenuAction action, OpenCodeSessionState? current) {
    if (current == null) {
      return;
    }
    switch (action) {
      case _SessionMenuAction.agent:
        unawaited(_pickAgent());
      case _SessionMenuAction.model:
        unawaited(_pickModel());
    }
  }

  Future<void> _pickAgent() async {
    final l10n = AppLocalizations.of(context);
    final provider = openCodeSessionControllerProvider(_key);
    final notifier = ref.read(provider.notifier);
    try {
      final agents = await notifier.loadAgents();
      if (!mounted) {
        return;
      }
      if (agents.isEmpty) {
        _snack(l10n.openCodeAgentsEmpty);
        return;
      }
      final currentAgent = ref.read(provider).value?.agentId;
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              _SheetHeader(title: l10n.openCodeAgentMenu),
              for (final agent in agents)
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(agent.name),
                  subtitle: agent.id == agent.name ? null : Text(agent.id),
                  trailing: currentAgent == agent.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(agent.id),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      await notifier.setAgent(selected);
    } catch (error) {
      if (mounted) {
        _snack(openCodeFailureText(l10n, error));
      }
    }
  }

  Future<void> _pickModel() async {
    final l10n = AppLocalizations.of(context);
    final provider = openCodeSessionControllerProvider(_key);
    final notifier = ref.read(provider.notifier);
    try {
      final models = await notifier.loadModels();
      if (!mounted) {
        return;
      }
      if (models.isEmpty) {
        _snack(l10n.openCodeModelsEmpty);
        return;
      }
      final currentModel = ref.read(provider).value?.model;
      final selected = await showModalBottomSheet<OpenCodeModel>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              _SheetHeader(title: l10n.openCodeModelMenu),
              for (final model in models)
                ListTile(
                  leading: const Icon(Icons.memory_rounded),
                  title: Text(model.name),
                  subtitle: Text('${model.providerId} · ${model.id}'),
                  trailing:
                      currentModel?.id == model.id &&
                          currentModel?.providerId == model.providerId
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(model),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      await notifier.setModel(selected.ref);
    } catch (error) {
      if (mounted) {
        _snack(openCodeFailureText(l10n, error));
      }
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleScroll(OpenCodeSessionState state) {
    final last = state.messages.isEmpty ? null : state.messages.last;
    final signature =
        '${state.messages.length}:${last?.text.length ?? 0}:'
        '${state.streamingText.length}:${state.busy}:'
        '${state.activeTool}:${state.error != null}';
    if (signature == _lastScrollSignature) {
      return;
    }
    _lastScrollSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }
}

enum _SessionMenuAction { agent, model }

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final OpenCodeMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: MarkdownBody(
        data: message.text,
        selectable: true,
        styleSheet: _markdownStyle(context),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (text.isEmpty && busy) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.openCodeThinking,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: MarkdownBody(
        data: text,
        selectable: false,
        styleSheet: _markdownStyle(context),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: l10n.openCodeSessionInputHint,
                  filled: true,
                  fillColor: scheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (busy)
              IconButton.filled(
                tooltip: l10n.chatStop,
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) => IconButton.filled(
                  tooltip: l10n.chatSend,
                  onPressed: value.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final base = MarkdownStyleSheet.fromTheme(theme);

  return base.copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.4,
      color: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: scheme.outlineVariant),
    ),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
    h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    a: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
    listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
  );
}
