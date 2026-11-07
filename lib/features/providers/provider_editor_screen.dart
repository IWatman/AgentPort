import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/openai_compatible_client.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_failure.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import '../shared/failure_text.dart';
import 'providers_controller.dart';

class ProviderEditorScreen extends ConsumerStatefulWidget {
  const ProviderEditorScreen({this.providerId, super.key});

  final String? providerId;

  @override
  ConsumerState<ProviderEditorScreen> createState() =>
      _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends ConsumerState<ProviderEditorScreen> {
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();

  AiProviderType _type = AiProviderType.deepSeek;
  AiProvider? _existing;
  bool _initialized = false;
  bool _obscureApiKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.providerId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final providers = ref.watch(providersControllerProvider);

    AiProvider? existing;
    if (_isEditing) {
      final items = providers.value;
      if (items == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.providerEditTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      for (final provider in items) {
        if (provider.id == widget.providerId) {
          existing = provider;
          break;
        }
      }
      if (existing == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.providerEditTitle)),
          body: EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.providerNotFoundTitle,
            body: l10n.providerNotFoundBody,
          ),
        );
      }
    }

    if (!_initialized) {
      _existing = existing;
      _initialize(existing);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.providerEditTitle : l10n.providerNewTitle,
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.commonDelete,
              onPressed: _saving ? null : () => _confirmDelete(l10n),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionLabel(text: l10n.providerType),
          SegmentedButton<AiProviderType>(
            segments: [
              ButtonSegment(
                value: AiProviderType.deepSeek,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(l10n.providerTypeDeepSeek),
              ),
              ButtonSegment(
                value: AiProviderType.openAiCompatible,
                icon: const Icon(Icons.cloud_queue_rounded),
                label: Text(l10n.providerTypeCustom),
              ),
            ],
            selected: {_type},
            onSelectionChanged: _saving
                ? null
                : (selection) {
                    setState(() {
                      _type = selection.first;
                      _applyPreset(_type);
                    });
                  },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.providerName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.providerBaseUrl,
              hintText: l10n.providerBaseUrlHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _modelController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.providerModel,
              hintText: l10n.providerModelHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.providerApiKey,
              helperText: _isEditing
                  ? l10n.providerApiKeyKeep
                  : l10n.providerApiKeyHelp,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureApiKey ? l10n.commonShow : l10n.commonHide,
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _testing || _saving ? null : () => _testConnection(l10n),
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: Text(l10n.providerTest),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _testing ? null : () => _save(l10n),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.providerSave),
          ),
        ],
      ),
    );
  }

  void _initialize(AiProvider? provider) {
    if (provider == null) {
      _type = AiProviderType.deepSeek;
      _applyPreset(_type);
      return;
    }
    _type = provider.type;
    _nameController.text = provider.name;
    _baseUrlController.text = provider.baseUrl;
    _modelController.text = provider.model;
  }

  void _applyPreset(AiProviderType type) {
    final isDeepSeek = type == AiProviderType.deepSeek;
    final name = isDeepSeek
        ? ProviderPresets.deepSeekName
        : ProviderPresets.customName;
    final baseUrl = isDeepSeek
        ? ProviderPresets.deepSeekBaseUrl
        : ProviderPresets.customBaseUrl;
    final model = isDeepSeek
        ? ProviderPresets.deepSeekModel
        : ProviderPresets.customModel;

    if (_nameController.text.trim().isEmpty ||
        _nameController.text.trim() == ProviderPresets.deepSeekName ||
        _nameController.text.trim() == ProviderPresets.customName) {
      _nameController.text = name;
    }
    if (_baseUrlController.text.trim().isEmpty ||
        _baseUrlController.text.trim() == ProviderPresets.deepSeekBaseUrl ||
        _baseUrlController.text.trim() == ProviderPresets.customBaseUrl) {
      _baseUrlController.text = baseUrl;
    }
    if (_modelController.text.trim().isEmpty ||
        _modelController.text.trim() == ProviderPresets.deepSeekModel ||
        _modelController.text.trim() == ProviderPresets.customModel) {
      _modelController.text = model;
    }
  }

  Future<void> _testConnection(AppLocalizations l10n) async {
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    var apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      setState(() => _error = l10n.providerFieldRequired);
      return;
    }
    if (apiKey.isEmpty && _existing != null) {
      apiKey =
          await ref.read(providerRepositoryProvider).apiKeyFor(_existing!) ??
          '';
    }
    if (apiKey.isEmpty) {
      setState(() => _error = l10n.providerApiKeyRequired);
      return;
    }

    setState(() {
      _testing = true;
      _error = null;
    });

    final client = ref.read(openAiCompatibleClientProvider);
    try {
      await client.testConnection(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      );
      if (!mounted) {
        return;
      }
      _showSnack(l10n.providerTestSuccess);
    } on ChatFailure catch (failure) {
      if (!mounted) {
        return;
      }
      final detail = failure.detail;
      _showSnack(
        '${l10n.providerTestFailed} ${chatFailureText(l10n, failure)}'
        '${detail == null ? '' : '\n$detail'}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('${l10n.providerTestFailed} $error');
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save(AppLocalizations l10n) async {
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      setState(() => _error = l10n.providerFieldRequired);
      return;
    }
    if (_existing == null && apiKey.isEmpty) {
      setState(() => _error = l10n.providerApiKeyRequired);
      return;
    }

    try {
      OpenAiCompatibleClient.chatCompletionsUri(baseUrl);
    } on ChatFailure catch (failure) {
      setState(() => _error = chatFailureText(l10n, failure));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final controller = ref.read(providersControllerProvider.notifier);
      if (_existing == null) {
        await controller.create(
          name: name,
          type: _type,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey,
        );
      } else {
        await controller.save(
          provider: _existing!,
          name: name,
          type: _type,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey.isEmpty ? null : apiKey,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final provider = _existing;
    if (provider == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.providerDeleteTitle),
        content: Text(l10n.providerDeleteBody(provider.name)),
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

    await ref.read(providersControllerProvider.notifier).delete(provider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
