import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../opencode/opencode_connections_screen.dart';
import '../providers/providers_controller.dart';
import '../shared/empty_state.dart';
import '../chat/conversations_controller.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conversations = ref.watch(conversationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatsTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.chatsTitle),
            Tab(text: l10n.openCodeTitle),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _startChat(context, ref, l10n),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newChat),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildChats(context, ref, l10n, conversations),
          const OpenCodeConnectionsScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _buildChats(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<ChatConversation>> conversations,
  ) {
    return conversations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: l10n.chatErrorUnknown,
        body: error.toString(),
        action: OutlinedButton(
          onPressed: () =>
              ref.read(conversationsControllerProvider.notifier).reload(),
          child: Text(l10n.commonRetry),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.forum_outlined,
            title: l10n.chatsEmptyTitle,
            body: l10n.chatsEmptyBody,
            action: FilledButton.icon(
              onPressed: () => _startChat(context, ref, l10n),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newChat),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final conversation = items[index];
            return _ConversationCard(
              conversation: conversation,
              onTap: () => context.push('/chats/${conversation.id}'),
              onRename: () =>
                  unawaited(_rename(context, ref, l10n, conversation)),
              onDelete: () =>
                  unawaited(_delete(context, ref, l10n, conversation)),
            );
          },
        );
      },
    );
  }

  Future<void> _startChat(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final providers = ref.read(providersControllerProvider).value;
    if (providers == null) {
      return;
    }
    if (providers.isEmpty) {
      final goToProviders = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.chatsNoProviderTitle),
          content: Text(l10n.chatsNoProviderBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.chatsAddProvider),
            ),
          ],
        ),
      );
      if (goToProviders == true && context.mounted) {
        await context.push('/providers/new');
      }
      return;
    }

    final AiProvider provider = providers.first;
    final conversation = await ref
        .read(conversationsControllerProvider.notifier)
        .create(providerId: provider.id);
    if (!context.mounted) {
      return;
    }
    await context.push('/chats/${conversation.id}');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ChatConversation conversation,
  ) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatsRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.chatsRenameHint,
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
    if (title == null || !context.mounted) {
      return;
    }
    await ref
        .read(conversationsControllerProvider.notifier)
        .rename(conversation, title);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ChatConversation conversation,
  ) async {
    final title = conversation.title.trim().isEmpty
        ? l10n.chatNewTitle
        : conversation.title;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatsDeleteTitle),
        content: Text(l10n.chatsDeleteBody(title)),
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    await ref
        .read(conversationsControllerProvider.notifier)
        .delete(conversation);
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final title = conversation.title.trim().isEmpty
        ? l10n.chatNewTitle
        : conversation.title;
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(conversation.updatedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final date = localizations.formatMediumDate(conversation.updatedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$date · $time',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_ConversationAction>(
          tooltip: l10n.chatsActions,
          onSelected: (action) {
            switch (action) {
              case _ConversationAction.rename:
                onRename();
              case _ConversationAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ConversationAction.rename,
              child: Text(l10n.chatsRenameTitle),
            ),
            PopupMenuItem(
              value: _ConversationAction.delete,
              child: Text(l10n.chatsDeleteTitle),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConversationAction { rename, delete }
