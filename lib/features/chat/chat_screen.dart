import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/api/openai_responses_client.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_failure.dart';
import '../../domain/entities/chat_message.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/model_catalog.dart';
import '../providers/providers_controller.dart';
import '../shared/empty_state.dart';
import '../shared/failure_text.dart';
import '../shared/scroll_to_bottom.dart';
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
  final _attachments = <ChatMessageAttachment>[];
  final _speech = SpeechToText();
  String? _lastSignature;
  String? _approvalId;
  bool _listening = false;
  String _voiceBaseText = '';
  var _stickToBottom = true;
  var _didInitialScroll = false;
  var _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _composer.dispose();
    _scroll.dispose();
    unawaited(_speech.stop());
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
    final session = ref.watch(chatControllerProvider(widget.conversationId));
    final providersAsync = ref.watch(providersControllerProvider);
    final providers = providersAsync.value ?? const <AiProvider>[];

    final approval = session.value?.pendingApproval;
    if (approval != null && approval.id != _approvalId) {
      _approvalId = approval.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_showToolApproval(approval));
        }
      });
    }

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
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: state.messages.isEmpty
                          ? EmptyState(
                              icon: Icons.chat_bubble_outline_rounded,
                              title: l10n.chatEmptyTitle,
                              body: provider == null
                                  ? l10n.providersEmptyBody
                                  : l10n.chatEmptyBody,
                              action: provider == null
                                  ? FilledButton.icon(
                                      onPressed: () =>
                                          context.push('/providers/new'),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(l10n.providerAdd),
                                    )
                                  : null,
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
                                final message = state.messages[index];
                                final isLast =
                                    index == state.messages.length - 1;
                                return _MessageRow(
                                  message: message,
                                  streaming: state.streaming && isLast,
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
              if (state.activeTool != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    l10n.chatToolRunning(state.activeTool!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              _Composer(
                controller: _composer,
                streaming: state.streaming,
                attachments: _attachments,
                listening: _listening,
                modelLabel: provider == null
                    ? l10n.chatNoProvider
                    : _modelBarLabel(l10n, state, provider),
                onSend: () => _send(state),
                onStop: () => unawaited(
                  ref
                      .read(
                        chatControllerProvider(widget.conversationId).notifier,
                      )
                      .stop(),
                ),
                onAttach: () => unawaited(_attach(l10n)),
                onRemoveAttachment: _removeAttachment,
                onVoice: () => unawaited(_toggleVoice(l10n)),
                onPickModel: state.streaming || provider == null
                    ? null
                    : () => unawaited(_pickModel(l10n, state, provider)),
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
                : '${provider.name} · '
                      '${_modelBarLabel(l10n, state, provider)}',
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
          enabled: !state.streaming,
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
    if ((text.isEmpty && _attachments.isEmpty) || state.streaming) {
      return;
    }
    if (_listening) {
      unawaited(_speech.cancel());
      setState(() => _listening = false);
    }
    final attachments = List<ChatMessageAttachment>.of(_attachments);
    unawaited(
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .send(
            text,
            attachments: attachments,
            onAccepted: () {
              if (!mounted) {
                return;
              }
              _composer.clear();
              setState(_attachments.clear);
            },
          ),
    );
    _scrollToBottomSoon();
  }

  String _modelFor(ChatSessionState state, AiProvider provider) {
    final model = state.conversation.model?.trim();
    return model == null || model.isEmpty ? provider.model : model;
  }

  Future<void> _showToolApproval(ChatToolApproval approval) async {
    final l10n = AppLocalizations.of(context);
    final arguments = approval.arguments.trim().isEmpty
        ? '{}'
        : approval.arguments;
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatToolApprovalTitle),
        content: SingleChildScrollView(
          child: SelectableText(
            l10n.chatToolApprovalBody(
              approval.toolName,
              arguments.length > 2000
                  ? '${arguments.substring(0, 2000)}…'
                  : arguments,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.chatDeny),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.chatAllow),
          ),
        ],
      ),
    );
    _approvalId = null;
    if (!mounted) {
      return;
    }
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .resolveToolApproval(allowed == true);
  }

  String _modelBarLabel(
    AppLocalizations l10n,
    ChatSessionState state,
    AiProvider provider,
  ) {
    final model = _modelFor(state, provider);
    return model.trim().isEmpty
        ? l10n.chatChooseModel
        : ProviderModelCatalog.labelFor(provider.baseUrl, model);
  }

  Future<void> _attach(AppLocalizations l10n) async {
    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chatAttachPhoto),
              onTap: () => Navigator.of(sheetContext).pop(_AttachSource.photo),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: Text(l10n.chatAttachFile),
              onTap: () => Navigator.of(sheetContext).pop(_AttachSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    if (source == _AttachSource.photo) {
      await _pickPhoto(l10n);
    } else {
      await _pickFile(l10n);
    }
  }

  Future<void> _pickPhoto(AppLocalizations l10n) async {
    if (_attachments.length >= _maxAttachments) {
      _snack(l10n.chatAttachmentLimit);
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 78,
    );
    if (picked == null || !mounted) {
      return;
    }
    final length = await picked.length();
    if (length > _maxAttachmentBytes) {
      _snack(l10n.chatAttachmentTooLarge);
      return;
    }
    final List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      _snack(l10n.chatFileUnsupported);
      return;
    }
    if (!mounted) {
      return;
    }
    if (bytes.length > _maxAttachmentBytes) {
      _snack(l10n.chatAttachmentTooLarge);
      return;
    }
    final name = picked.name;
    setState(() {
      _attachments.add(
        ChatMessageAttachment(
          name: name,
          mimeType: picked.mimeType ?? _mimeForName(name),
          bytesBase64: base64Encode(bytes),
        ),
      );
    });
  }

  Future<void> _pickFile(AppLocalizations l10n) async {
    if (_attachments.length >= _maxAttachments) {
      _snack(l10n.chatAttachmentLimit);
      return;
    }
    final file = await FilePicker.pickFile();
    if (file == null || !mounted) {
      return;
    }
    final name = file.name;
    final mime = _mimeForName(name);
    final isImage = mime.startsWith('image/');
    if (!isImage && !_isTextFile(name)) {
      _snack(l10n.chatFileUnsupported);
      return;
    }
    final length = await file.length();
    if (length != null && length > _maxAttachmentBytes) {
      _snack(l10n.chatAttachmentTooLarge);
      return;
    }
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _snack(l10n.chatFileUnsupported);
      return;
    }
    if (!mounted) {
      return;
    }
    if (bytes.length > _maxAttachmentBytes) {
      _snack(l10n.chatAttachmentTooLarge);
      return;
    }
    if (isImage) {
      setState(() {
        _attachments.add(
          ChatMessageAttachment(
            name: name,
            mimeType: mime,
            bytesBase64: base64Encode(bytes),
          ),
        );
      });
      return;
    }
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.length > _maxTextAttachmentChars) {
      text =
          '${text.substring(0, _maxTextAttachmentChars)}\n'
          '…[truncated]';
    }
    setState(() {
      _attachments.add(
        ChatMessageAttachment(name: name, mimeType: mime, textContent: text),
      );
    });
  }

  void _removeAttachment(ChatMessageAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  Future<void> _toggleVoice(AppLocalizations l10n) async {
    if (_listening) {
      await _speech.cancel();
      if (mounted) {
        setState(() => _listening = false);
      }
      return;
    }

    bool available;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          unawaited(_speech.cancel());
          setState(() => _listening = false);
          _snack(l10n.chatVoiceUnavailable);
        },
      );
    } catch (_) {
      available = false;
    }
    if (!available || !mounted) {
      _snack(l10n.chatVoiceUnavailable);
      return;
    }

    _voiceBaseText = _composer.text;
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) {
            return;
          }
          final recognized = result.recognizedWords.trim();
          final text = _voiceBaseText.trim().isEmpty
              ? recognized
              : '${_voiceBaseText.trim()} $recognized';
          _composer.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
        listenOptions: SpeechListenOptions(cancelOnError: true),
      );
    } catch (_) {
      unawaited(_speech.cancel());
      if (mounted) {
        setState(() => _listening = false);
        _snack(l10n.chatVoiceUnavailable);
      }
    }
  }

  Future<void> _pickModel(
    AppLocalizations l10n,
    ChatSessionState state,
    AiProvider provider,
  ) async {
    final current = _modelFor(state, provider);
    if (provider.usesResponses) {
      final modelsFuture = _loadChatGptModels(provider);
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: FutureBuilder<List<ModelOption>>(
            future: modelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.providerAccountLoadFailed),
                );
              }
              final models = snapshot.data ?? const <ModelOption>[];
              if (models.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.providerNoAccountModels),
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      l10n.chatModel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final option in models)
                    ListTile(
                      leading: const Icon(Icons.memory_rounded),
                      title: Text(option.label),
                      subtitle: Text(option.id),
                      trailing: current == option.id
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(option.id),
                    ),
                ],
              );
            },
          ),
        ),
      );
      if (selected != null && mounted) {
        await ref
            .read(chatControllerProvider(widget.conversationId).notifier)
            .selectModel(selected);
      }
      return;
    }
    final suggestions = _modelSuggestions(provider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.chatModel,
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (provider.model.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(
                  l10n.chatModelDefault(
                    ProviderModelCatalog.labelFor(
                      provider.baseUrl,
                      provider.model,
                    ),
                  ),
                ),
                subtitle: current == provider.model
                    ? null
                    : Text(provider.model),
                trailing: current == provider.model
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(_defaultModelValue),
              ),
            for (final option in suggestions)
              ListTile(
                leading: const Icon(Icons.memory_rounded),
                title: Text(option.label),
                subtitle: Text(option.id),
                trailing: current == option.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final controller = ref.read(
      chatControllerProvider(widget.conversationId).notifier,
    );
    if (selected == _defaultModelValue) {
      await controller.selectModel(null);
      return;
    }
    await controller.selectModel(selected);
  }

  Future<List<ModelOption>> _loadChatGptModels(AiProvider provider) async {
    final token = await ref
        .read(providerRepositoryProvider)
        .apiKeyFor(provider);
    if (token == null || token.isEmpty) {
      throw StateError('Account disconnected.');
    }
    final models = await ref
        .read(openAiResponsesClientProvider)
        .listModels(accessToken: token);
    return [
      for (final model in models) ModelOption(id: model.id, label: model.label),
    ];
  }

  List<ModelOption> _modelSuggestions(AiProvider provider) {
    return ProviderModelCatalog.forBaseUrl(provider.baseUrl)
        .where((option) => option.id != provider.model)
        .toList(growable: false);
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _mimeForName(String name) {
    final extension = p.extension(name).toLowerCase().replaceFirst('.', '');
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'json' => 'application/json',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'html' => 'text/html',
      'xml' => 'application/xml',
      'yaml' || 'yml' => 'text/yaml',
      'dart' ||
      'js' ||
      'ts' ||
      'py' ||
      'java' ||
      'kt' ||
      'swift' ||
      'c' ||
      'cpp' ||
      'h' ||
      'css' ||
      'sql' ||
      'sh' ||
      'log' ||
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  bool _isTextFile(String name) {
    final mime = _mimeForName(name);
    return mime.startsWith('text/') ||
        mime == 'application/json' ||
        mime == 'application/xml';
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
        child: ListView(
          shrinkWrap: true,
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
                  ProviderModelCatalog.labelFor(
                    provider.baseUrl,
                    provider.model,
                  ),
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

const _addProviderValue = '__add_provider__';
const _defaultModelValue = '__default_model__';
const _maxAttachmentBytes = 8 * 1024 * 1024;
const _maxAttachments = 4;
const _maxTextAttachmentChars = 200000;

enum _AttachSource { photo, file }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.attachments.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  for (final attachment in message.attachments)
                    _AttachmentPreview(attachment: attachment),
                ],
              ),
              if (message.content.trim().isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.content.trim().isNotEmpty)
              SelectableText(
                message.content,
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
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (attachment.isImage && attachment.bytesBase64 != null) {
      try {
        final bytes = base64Decode(attachment.bytesBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 220,
            height: 160,
            fit: BoxFit.cover,
            cacheWidth: 660,
            errorBuilder: (context, error, stackTrace) => _fileChip(theme),
          ),
        );
      } on FormatException {
        return _fileChip(theme);
      }
    }
    return _fileChip(theme);
  }

  Widget _fileChip(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attachment.isImage
                ? Icons.image_outlined
                : Icons.description_outlined,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
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
  late bool _reasoningExpanded = false;

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
    required this.attachments,
    required this.listening,
    required this.modelLabel,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onVoice,
    required this.onPickModel,
  });

  final TextEditingController controller;
  final bool streaming;
  final List<ChatMessageAttachment> attachments;
  final bool listening;
  final String modelLabel;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final ValueChanged<ChatMessageAttachment> onRemoveAttachment;
  final VoidCallback onVoice;
  final VoidCallback? onPickModel;

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
            if (attachments.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final attachment in attachments)
                        InputChip(
                          avatar: Icon(
                            attachment.isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                            size: 16,
                          ),
                          label: Text(
                            attachment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => onRemoveAttachment(attachment),
                          deleteButtonTooltipMessage: l10n.chatRemoveAttachment,
                        ),
                    ],
                  ),
                ),
              ),
            if (listening)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    l10n.chatListening,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: streaming ? null : onAttach,
                  tooltip: l10n.chatAttach,
                  icon: const Icon(Icons.add_rounded),
                ),
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
                const SizedBox(width: 4),
                IconButton(
                  onPressed: streaming ? null : onVoice,
                  tooltip: listening ? l10n.chatVoiceStop : l10n.chatVoice,
                  color: listening ? scheme.primary : null,
                  icon: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  ),
                ),
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
            const SizedBox(height: 6),
            InkWell(
              onTap: onPickModel,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        modelLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
