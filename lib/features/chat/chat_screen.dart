import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_failure.dart';
import '../../domain/entities/chat_message.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/providers_controller.dart';
import '../shared/empty_state.dart';
import '../shared/failure_text.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  String? _lastSignature;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(chatControllerProvider(widget.conversationId));
    final providersAsync = ref.watch(providersControllerProvider);
    final providers = providersAsync.value ?? const <AiProvider>[];

    return Scaffold(
      appBar: session.value == null
          ? AppBar(title: Text(l10n.chatNewTitle))
          : _buildAppBar(context, l10n, session.value!, providers),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.chatErrorUnknown,
          body: error.toString(),
          action: OutlinedButton(
            onPressed: () =>
                ref.invalidate(chatControllerProvider(widget.conversationId)),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (state) {
          _scheduleScrollIfNeeded(state);
          final provider = _effectiveProvider(state, providers);
          final showProviderBanner =
              providersAsync.hasValue &&
              providers.isEmpty &&
              state.failure == null;

          return Column(
            children: [
              if (showProviderBanner)
                _ProviderBanner(
                  title: l10n.chatNoProvider,
                  body: l10n.providersEmptyBody,
                  actionLabel: l10n.providerAdd,
                  onAction: () => context.push('/providers/new'),
                ),
              Expanded(
                child: state.messages.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: l10n.chatEmptyTitle,
                        body: provider == null
                            ? l10n.providersEmptyBody
                            : l10n.chatEmptyBody,
                        action: provider == null
                            ? FilledButton.icon(
                                onPressed: () => context.push('/providers/new'),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(l10n.providerAdd),
                              )
                            : null,
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          final isLast = index == state.messages.length - 1;
                          return _MessageRow(
                            message: message,
                            streaming: state.streaming && isLast,
                          );
                        },
                      ),
              ),
              if (state.failure != null)
                _FailureBanner(
                  failure: state.failure!,
                  canRetry: state.canRetry,
                  onRetry: () => unawaited(
                    ref
                        .read(
                          chatControllerProvider(widget.conversationId)
                              .notifier,
                        )
                        .retry(),
                  ),
                  onOpenProviders: () => context.push('/providers'),
                ),
              _Composer(
                controller: _composer,
                streaming: state.streaming,
                onSend: () => _send(state),
                onStop: () => unawaited(
                  ref
                      .read(
                        chatControllerProvider(widget.conversationId).notifier,
                      )
                      .stop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    ChatSessionState state,
    List<AiProvider> providers,
  ) {
    final theme = Theme.of(context);
    final provider = _effectiveProvider(state, providers);
    final title = state.conversation.title.trim().isEmpty
        ? l10n.chatNewTitle
        : state.conversation.title;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            provider == null
                ? l10n.chatNoProvider
                : '${provider.name} · ${provider.model}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<_ChatMenuAction>(
          onSelected: (action) {
            switch (action) {
              case _ChatMenuAction.rename:
                unawaited(_rename(l10n, state));
              case _ChatMenuAction.provider:
                unawaited(_pickProvider(l10n, state, providers));
              case _ChatMenuAction.delete:
                unawaited(_delete(l10n));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ChatMenuAction.rename,
              child: Text(l10n.chatRenameTitle),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.provider,
              child: Text(l10n.chatProviderMenu),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.delete,
              child: Text(l10n.chatDeleteTitle),
            ),
          ],
        ),
      ],
    );
  }

  void _send(ChatSessionState state) {
    final text = _composer.text.trim();
    if (text.isEmpty || state.streaming) {
      return;
    }
    _composer.clear();
    unawaited(
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .send(text),
    );
  }

  Future<void> _rename(AppLocalizations l10n, ChatSessionState state) async {
    final controller = TextEditingController(
      text: state.conversation.title.trim(),
    );
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.chatRenameHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) {
      return;
    }
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .rename(title);
  }

  Future<void> _pickProvider(
    AppLocalizations l10n,
    ChatSessionState state,
    List<AiProvider> providers,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    l10n.chatProvider,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            for (final provider in providers)
              ListTile(
                leading: Icon(
                  provider.isDeepSeek
                      ? Icons.auto_awesome_rounded
                      : Icons.cloud_queue_rounded,
                ),
                title: Text(provider.name),
                subtitle: Text(
                  provider.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    provider.id == _effectiveProvider(state, providers)?.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(provider.id),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(l10n.providerAdd),
              onTap: () => Navigator.of(sheetContext).pop(_addProviderValue),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }
    if (selected == _addProviderValue) {
      await context.push('/providers/new');
      return;
    }
    for (final provider in providers) {
      if (provider.id == selected) {
        await ref
            .read(chatControllerProvider(widget.conversationId).notifier)
            .selectProvider(provider);
        return;
      }
    }
  }

  Future<void> _delete(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteBody),
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
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .deleteConversation();
    if (mounted) {
      context.pop();
    }
  }

  AiProvider? _effectiveProvider(
    ChatSessionState state,
    List<AiProvider> providers,
  ) {
    if (providers.isEmpty) {
      return null;
    }
    for (final provider in providers) {
      if (provider.id == state.conversation.providerId) {
        return provider;
      }
    }
    return providers.first;
  }

  void _scheduleScrollIfNeeded(ChatSessionState state) {
    final last = state.messages.isEmpty ? null : state.messages.last;
    final signature =
        '${state.messages.length}:${last?.content.length ?? 0}:'
        '${last?.reasoning?.length ?? 0}:${state.streaming}';
    if (signature == _lastSignature) {
      return;
    }
    _lastSignature = signature;
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

const _addProviderValue = '__add_provider__';

enum _ChatMenuAction { rename, provider, delete }

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.streaming});

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserBubble(message: message);
    }
    if (message.role == ChatRole.system || message.role == ChatRole.tool) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          message.content,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    return _AssistantMessage(message: message, streaming: streaming);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatefulWidget {
  const _AssistantMessage({required this.message, required this.streaming});

  final ChatMessage message;
  final bool streaming;

  @override
  State<_AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<_AssistantMessage> {
  late bool _reasoningExpanded =
      widget.streaming && widget.message.content.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = widget.message;
    final reasoning = message.reasoning;
    final hasContent = message.content.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reasoning != null && reasoning.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('reasoning-${message.id}'),
                  initiallyExpanded: _reasoningExpanded,
                  onExpansionChanged: (value) =>
                      setState(() => _reasoningExpanded = value),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  dense: true,
                  title: Row(
                    children: [
                      Icon(
                        Icons.psychology_alt_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.chatReasoning,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    SelectableText(
                      reasoning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasContent)
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: _markdownStyle(context),
            )
          else if (widget.streaming)
            const _TypingIndicator()
          else if (reasoning == null || reasoning.trim().isEmpty)
            Text(
              l10n.chatErrorUnknown,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (!widget.streaming &&
              message.status != ChatMessageStatus.complete) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  message.status == ChatMessageStatus.stopped
                      ? Icons.stop_circle_outlined
                      : Icons.error_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  message.status == ChatMessageStatus.stopped
                      ? l10n.chatStopped
                      : l10n.chatError,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Row(
        children: [
          for (var index = 0; index < 3; index++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({
    required this.failure,
    required this.canRetry,
    required this.onRetry,
    required this.onOpenProviders,
  });

  final ChatFailure failure;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpenProviders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chatFailureText(l10n, failure),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                    if (failure.detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          failure.detail!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onErrorContainer.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (failure.kind == ChatFailureKind.noProvider ||
                  failure.kind == ChatFailureKind.missingApiKey)
                TextButton(
                  onPressed: onOpenProviders,
                  child: Text(l10n.providersTitle),
                ),
              if (canRetry)
                TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderBanner extends StatelessWidget {
  const _ProviderBanner({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.streaming,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool streaming;
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
                  hintText: l10n.chatInputHint,
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
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: streaming ? l10n.chatStop : l10n.chatSend,
              onPressed: streaming ? onStop : onSend,
              icon: Icon(
                streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: streaming
                    ? scheme.errorContainer
                    : scheme.primary,
                foregroundColor: streaming
                    ? scheme.onErrorContainer
                    : scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
