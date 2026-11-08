import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/opencode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import '../shared/scroll_to_bottom.dart';
import 'opencode_failure_text.dart';
import 'opencode_session_controller.dart';
import 'opencode_transcript.dart';

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
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  String? _lastScrollSignature;
  var _stickToBottom = true;
  var _didInitialScroll = false;
  var _showScrollDown = false;

  OpenCodeSessionKey get _key =>
      (connectionId: widget.connectionId, sessionId: widget.sessionId);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final position = _scroll.position;
    final distance = position.maxScrollExtent - position.pixels;
    _stickToBottom = distance < 240;
    final show = distance > 400;
    if (show != _showScrollDown) {
      setState(() => _showScrollDown = show);
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) {
      return;
    }
    _stickToBottom = true;
    if (_showScrollDown) {
      setState(() => _showScrollDown = false);
    }
    settleScrollToBottom(_scroll);
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });
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
                value: _SessionMenuAction.rename,
                child: Text(l10n.openCodeRenameTitle),
              ),
              PopupMenuItem(
                value: _SessionMenuAction.info,
                child: Text(l10n.openCodeSessionInfoTitle),
              ),
              PopupMenuItem(
                value: _SessionMenuAction.delete,
                child: Text(l10n.openCodeDeleteSession),
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
          final turns = groupOpenCodeMessages(current.messages);
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
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
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              itemCount:
                                  turns.length +
                                  (current.streamingText.isNotEmpty ||
                                          current.busy
                                      ? 1
                                      : 0),
                              itemBuilder: (context, index) {
                                if (index < turns.length) {
                                  final turn = turns[index];
                                  return switch (turn) {
                                    OpenCodeUserTurn(:final message) =>
                                      _MessageBubble(message: message),
                                    OpenCodeAssistantTurn() =>
                                      _AssistantTurnView(turn: turn),
                                  };
                                }
                                return _StreamingBubble(
                                  text: current.streamingText,
                                  busy: current.busy,
                                );
                              },
                            ),
                    ),
                    if (_showScrollDown)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          tooltip: l10n.chatScrollToBottom,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ),
                  ],
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
                focusNode: _composerFocus,
                busy: current.busy,
                modelLabel: _modelLabel(current),
                agentLabel: current.agentId,
                onSend: _send,
                onStop: () => unawaited(ref.read(provider.notifier).stop()),
                onCommand: () => unawaited(_pickCommand()),
                onMention: () => unawaited(_pickMention()),
                onModel: () => unawaited(_pickModel()),
                onAgent: () => unawaited(_pickAgent()),
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
    final notifier = ref.read(openCodeSessionControllerProvider(_key).notifier);
    final command = RegExp(r'^/([A-Za-z0-9_-]+)(?:\s+([\s\S]*))?$')
        .firstMatch(text);
    if (command != null) {
      unawaited(
        notifier.sendCommand(command.group(1)!, command.group(2) ?? ''),
      );
      _scrollToBottomSoon();
      return;
    }
    unawaited(notifier.send(text));
    _scrollToBottomSoon();
  }

  String? _modelLabel(OpenCodeSessionState state) {
    final model = state.model;
    if (model == null) {
      return state.modelName;
    }
    final base = state.modelName ?? model.id;
    return model.variant == null ? base : '$base · ${model.variant}';
  }

  void _onMenu(_SessionMenuAction action, OpenCodeSessionState? current) {
    if (current == null) {
      return;
    }
    switch (action) {
      case _SessionMenuAction.rename:
        unawaited(_renameSession(current));
      case _SessionMenuAction.info:
        unawaited(_showSessionInfo(current));
      case _SessionMenuAction.delete:
        unawaited(_deleteSession(current));
    }
  }

  Future<void> _pickCommand() async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(openCodeSessionControllerProvider(_key).notifier);
    try {
      final commands = await notifier.loadCommands();
      if (!mounted) {
        return;
      }
      if (commands.isEmpty) {
        _snack(l10n.openCodeCommandsEmpty);
        return;
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                _SheetHeader(title: l10n.openCodeCommandsTitle),
                for (final command in commands)
                  ListTile(
                    leading: const Icon(Icons.terminal_rounded),
                    title: Text(command.displayName),
                    subtitle: command.description.isEmpty
                        ? null
                        : Text(
                            command.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => Navigator.of(sheetContext).pop(command.name),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && mounted) {
        _insertText('/$selected ');
      }
    } catch (error) {
      if (mounted) {
        _snack(openCodeFailureText(l10n, error));
      }
    }
  }

  Future<void> _pickMention() async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(openCodeSessionControllerProvider(_key).notifier);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _MentionSheet(
        title: l10n.openCodeMentionsTitle,
        hint: l10n.openCodeMentionHint,
        empty: l10n.openCodeMentionsEmpty,
        search: notifier.searchFiles,
        failureText: (error) => openCodeFailureText(l10n, error),
      ),
    );
    if (selected != null && mounted) {
      _insertText('@$selected ');
    }
  }

  Future<void> _renameSession(OpenCodeSessionState current) async {
    final l10n = AppLocalizations.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameSessionDialog(
        initialTitle: current.session.title,
        title: l10n.openCodeRenameTitle,
        hint: l10n.openCodeRenameHint,
        cancel: l10n.commonCancel,
        save: l10n.commonSave,
      ),
    );
    if (title == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(openCodeSessionControllerProvider(_key).notifier)
          .rename(title);
    } catch (error) {
      if (mounted) {
        _snack(openCodeFailureText(l10n, error));
      }
    }
  }

  Future<void> _deleteSession(OpenCodeSessionState current) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.openCodeDeleteSession),
        content: Text(l10n.openCodeDeleteSessionBody(current.session.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(openCodeSessionControllerProvider(_key).notifier)
          .deleteSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _snack(openCodeFailureText(l10n, error));
      }
    }
  }

  Future<void> _showSessionInfo(OpenCodeSessionState current) async {
    final l10n = AppLocalizations.of(context);
    final session = current.session;
    final cost = session.cost;
    final tokensInput = session.tokensInput ?? 0;
    final tokensOutput = session.tokensOutput ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _SheetHeader(title: l10n.openCodeSessionInfoTitle),
            ListTile(
              title: Text(l10n.openCodeSessionInfoId),
              subtitle: SelectableText(session.id),
            ),
            ListTile(
              title: Text(l10n.openCodeSessionInfoProject),
              subtitle: SelectableText(
                session.directory ?? session.project ?? '—',
              ),
            ),
            if (session.updatedAt != null)
              ListTile(
                title: Text(l10n.openCodeSessionInfoUpdated),
                subtitle: Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(session.updatedAt!),
                ),
              ),
            ListTile(
              title: Text(l10n.openCodeSessionInfoTokens),
              subtitle: Text('$tokensInput / $tokensOutput'),
            ),
            if (cost != null)
              ListTile(
                title: Text(l10n.openCodeSessionInfoCost),
                subtitle: Text('\$${cost.toStringAsFixed(4)}'),
              ),
          ],
        ),
      ),
    );
  }

  void _insertText(String text) {
    final value = _composer.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final updated = value.text.replaceRange(start, end, text);
    _composer.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _composerFocus.requestFocus();
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
      final selected = await showModalBottomSheet<_ModelSelection>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => _ModelSheet(
          title: l10n.openCodeModelMenu,
          hint: l10n.openCodeModelSearchHint,
          empty: l10n.openCodeModelsEmpty,
          variantTitle: l10n.openCodeVariantTitle,
          defaultVariant: l10n.openCodeVariantDefault,
          models: models,
          current: currentModel,
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      await notifier.setModel(
        OpenCodeModelRef(
          id: selected.model.id,
          providerId: selected.model.providerId,
          variant: selected.variant,
        ),
        name: selected.model.name,
      );
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
    if (_didInitialScroll && !_stickToBottom) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _didInitialScroll = true;
      settleScrollToBottom(_scroll);
    });
  }
}

enum _SessionMenuAction { rename, info, delete }

class _AssistantTurnView extends StatelessWidget {
  const _AssistantTurnView({required this.turn});

  final OpenCodeAssistantTurn turn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasReasoning = turn.reasoning.trim().isNotEmpty;
    final toolNames = turn.tools.toSet().toList(growable: false);
    final shownNames = toolNames.take(3).join(', ');
    final names = toolNames.length > 3 ? '$shownNames…' : shownNames;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (turn.tools.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.build_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.openCodeToolsUsedSummary(turn.tools.length, names),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasReasoning)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.chatReasoning,
                    onPressed: () => _showReasoning(context),
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                  ),
              ],
            )
          else if (hasReasoning)
            TextButton.icon(
              onPressed: () => _showReasoning(context),
              icon: const Icon(Icons.psychology_outlined, size: 18),
              label: Text(l10n.chatReasoning),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (turn.text.isNotEmpty) ...[
            if (turn.tools.isNotEmpty || hasReasoning)
              const SizedBox(height: 6),
            MarkdownBody(
              data: turn.text,
              selectable: true,
              styleSheet: _markdownStyle(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReasoning(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.chatReasoning,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: MarkdownBody(
                    data: turn.reasoning,
                    selectable: true,
                    styleSheet: _markdownStyle(sheetContext),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final attachment in message.attachments)
                      _AttachmentView(attachment: attachment),
                  ],
                ),
                if (message.text.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.text.isNotEmpty)
                SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final hasText = message.text.trim().isNotEmpty;
    final hasReasoning = message.reasoning.trim().isNotEmpty;
    if (!hasText && !hasReasoning && message.tools.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReasoning) ...[
            _ReasoningBlock(text: message.reasoning),
            if (hasText) const SizedBox(height: 10),
          ],
          if (hasText)
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: _markdownStyle(context),
            ),
          if (message.tools.isNotEmpty) ...[
            if (hasText || hasReasoning) const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in message.tools)
                  Chip(
                    avatar: const Icon(Icons.build_rounded, size: 15),
                    label: Text(tool),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final OpenCodeAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (!attachment.isImage) {
      return Chip(
        avatar: const Icon(Icons.attach_file_rounded, size: 16),
        label: Text(attachment.name),
      );
    }

    try {
      final bytes = base64Decode(attachment.data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          cacheWidth: 440,
          errorBuilder: (context, error, stackTrace) =>
              _AttachmentChip(attachment: attachment),
        ),
      );
    } catch (_) {
      return _AttachmentChip(attachment: attachment);
    }
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment});

  final OpenCodeAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.attach_file_rounded, size: 16),
      label: Text(attachment.name),
    );
  }
}

class _ReasoningBlock extends StatelessWidget {
  const _ReasoningBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(
          Icons.psychology_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          l10n.chatReasoning,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: _markdownStyle(context),
            ),
          ),
        ],
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

class _RenameSessionDialog extends StatefulWidget {
  const _RenameSessionDialog({
    required this.initialTitle,
    required this.title,
    required this.hint,
    required this.cancel,
    required this.save,
  });

  final String initialTitle;
  final String title;
  final String hint;
  final String cancel;
  final String save;

  @override
  State<_RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<_RenameSessionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialTitle,
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.save),
        ),
      ],
    );
  }
}

class _ModelSelection {
  const _ModelSelection({required this.model, this.variant});

  final OpenCodeModel model;
  final String? variant;
}

class _ModelSheet extends StatefulWidget {
  const _ModelSheet({
    required this.title,
    required this.hint,
    required this.empty,
    required this.variantTitle,
    required this.defaultVariant,
    required this.models,
    required this.current,
  });

  final String title;
  final String hint;
  final String empty;
  final String variantTitle;
  final String defaultVariant;
  final List<OpenCodeModel> models;
  final OpenCodeModelRef? current;

  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  final _query = TextEditingController();
  var _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<OpenCodeModel> get _filtered {
    final filter = _filter.trim().toLowerCase();
    if (filter.isEmpty) {
      return widget.models;
    }
    return [
      for (final model in widget.models)
        if (model.name.toLowerCase().contains(filter) ||
            model.id.toLowerCase().contains(filter) ||
            model.providerId.toLowerCase().contains(filter))
          model,
    ];
  }

  Future<void> _select(OpenCodeModel model) async {
    if (model.variants.isEmpty) {
      Navigator.of(context).pop(_ModelSelection(model: model));
      return;
    }
    const defaultValue = '__default__';
    final variant = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            _SheetHeader(title: widget.variantTitle),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: Text(widget.defaultVariant),
              onTap: () => Navigator.of(sheetContext).pop(defaultValue),
            ),
            for (final id in model.variants)
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(id),
                onTap: () => Navigator.of(sheetContext).pop(id),
              ),
          ],
        ),
      ),
    );
    if (variant == null || !mounted) {
      return;
    }
    Navigator.of(context).pop(
      _ModelSelection(
        model: model,
        variant: variant == defaultValue ? null : variant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = _filtered;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(widget.title, style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: (value) => setState(() => _filter = value),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: models.isEmpty
                  ? Center(child: Text(widget.empty))
                  : ListView.builder(
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        final model = models[index];
                        final selected =
                            widget.current?.id == model.id &&
                            widget.current?.providerId == model.providerId;
                        return ListTile(
                          leading: const Icon(Icons.memory_rounded),
                          title: Text(model.name),
                          subtitle: Text(
                            [
                              '${model.providerId} · ${model.id}',
                              if (model.variants.isNotEmpty)
                                model.variants.join(', '),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => _select(model),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.modelLabel,
    required this.agentLabel,
    required this.onSend,
    required this.onStop,
    required this.onCommand,
    required this.onMention,
    required this.onModel,
    required this.onAgent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final String? modelLabel;
  final String? agentLabel;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onCommand;
  final VoidCallback onMention;
  final VoidCallback onModel;
  final VoidCallback onAgent;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
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
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  tooltip: l10n.openCodeCommandsTitle,
                  onPressed: onCommand,
                  icon: const Icon(Icons.terminal_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: l10n.openCodeMentionsTitle,
                  onPressed: onMention,
                  icon: const Icon(Icons.alternate_email_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Flexible(
                  child: _MetaButton(
                    icon: Icons.memory_rounded,
                    label: modelLabel ?? l10n.openCodeModel,
                    onTap: onModel,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: _MetaButton(
                    icon: Icons.smart_toy_outlined,
                    label: agentLabel ?? l10n.openCodeAgent,
                    onTap: onAgent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaButton extends StatelessWidget {
  const _MetaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: theme.textTheme.labelSmall,
      ),
    );
  }
}

class _MentionSheet extends StatefulWidget {
  const _MentionSheet({
    required this.title,
    required this.hint,
    required this.empty,
    required this.search,
    required this.failureText,
  });

  final String title;
  final String hint;
  final String empty;
  final Future<List<OpenCodeFileEntry>> Function(String query) search;
  final String Function(Object error) failureText;

  @override
  State<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends State<_MentionSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<OpenCodeFileEntry> _results = const [];
  var _loading = false;
  String? _error;
  var _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.search(query);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = widget.failureText(error);
        _results = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(widget.title, style: theme.textTheme.titleSmall),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _query.text.trim().isEmpty
                              ? widget.hint
                              : widget.empty,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final entry = _results[index];
                          return ListTile(
                            leading: Icon(
                              entry.isDirectory
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              entry.path,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context).pop(entry.path),
                          );
                        },
                      ),
              ),
            ],
          ),
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
