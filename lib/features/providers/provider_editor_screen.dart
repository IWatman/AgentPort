import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/system_proxy.dart';
import '../../data/api/openai_compatible_client.dart';
import '../../data/api/openai_responses_client.dart';
import '../../data/auth/provider_oauth.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_failure.dart';
import '../../domain/entities/provider_oauth.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import '../shared/failure_text.dart';
import 'model_catalog.dart';
import 'provider_oauth_text.dart';
import 'provider_presets.dart';
import 'providers_controller.dart';

class ProviderEditorScreen extends ConsumerStatefulWidget {
  const ProviderEditorScreen({
    this.providerId,
    this.initialPresetId,
    super.key,
  });

  final String? providerId;
  final String? initialPresetId;

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
  String? _selectedPresetId;
  AiProvider? _existing;
  bool _initialized = false;
  bool _obscureApiKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _error;
  ProviderAuthMethod _authMethod = ProviderAuthMethod.apiKey;
  ProviderOAuthCredential? _credential;
  bool _credentialDirty = false;
  bool _authorizing = false;
  bool _loadingAccount = false;
  List<ModelOption> _accountModels = const [];

  bool get _busy => _saving || _testing || _authorizing || _loadingAccount;
  bool get _usesAccount => _authMethod != ProviderAuthMethod.apiKey;

  bool get _isEditing => widget.providerId != null;

  @override
  void dispose() {
    if (_authorizing) {
      _activeFlow?.cancel();
    }
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
              onPressed: _busy ? null : () => _confirmDelete(l10n),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!_isEditing) ...[
            _SectionLabel(text: l10n.providerPresetsTitle),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ProviderPreset.all.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final preset = ProviderPreset.all[index];
                  return _PresetCard(
                    key: ValueKey('providerPreset-${preset.id}'),
                    preset: preset,
                    selected: _selectedPresetId == preset.id,
                    onTap: _busy ? null : () => _selectPreset(preset),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
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
            onSelectionChanged: _busy || _usesAccount
                ? null
                : (selection) => _selectType(selection.first),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('providerNameField'),
            enabled: !_busy,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.providerName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('providerBaseUrlField'),
            enabled: !_busy && !_usesAccount,
            controller: _baseUrlController,
            onChanged: (_) => setState(() {}),
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
          DropdownButtonFormField<ProviderAuthMethod>(
            key: ValueKey('providerAuth-$_authMethod'),
            initialValue: _authMethod,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.providerAuthMethod,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: ProviderAuthMethod.apiKey,
                child: Text(l10n.providerAuthApiKey),
              ),
              DropdownMenuItem(
                value: ProviderAuthMethod.chatGpt,
                child: Text(l10n.providerAuthChatGpt),
              ),
              DropdownMenuItem(
                value: ProviderAuthMethod.openRouter,
                child: Text(l10n.providerAuthOpenRouter),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) _selectAuthMethod(value);
                  },
          ),
          const SizedBox(height: 14),
          if (_usesAccount) ...[
            Text(
              _authMethod == ProviderAuthMethod.chatGpt
                  ? l10n.providerChatGptNotice
                  : l10n.providerOpenRouterNotice,
            ),
            const SizedBox(height: 12),
            if (_loadingAccount) const LinearProgressIndicator(),
            if (_credential != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(l10n.providerAccountConnected),
                subtitle: Text(
                  _credential!.email ??
                      (_authMethod == ProviderAuthMethod.chatGpt
                          ? 'ChatGPT'
                          : 'OpenRouter'),
                ),
              ),
            OutlinedButton.icon(
              key: const Key('providerAccountSignIn'),
              onPressed: _busy ? null : () => _signIn(l10n),
              icon: _authorizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _authMethod == ProviderAuthMethod.chatGpt
                    ? l10n.providerContinueChatGpt
                    : l10n.providerContinueOpenRouter,
              ),
            ),
            if (_authorizing)
              TextButton(
                onPressed: () => _activeFlow?.cancel(),
                child: Text(l10n.commonCancel),
              ),
            if (_credential != null)
              TextButton.icon(
                key: const Key('providerAccountDisconnect'),
                onPressed: _busy ? null : () => _disconnect(l10n),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.providerAccountDisconnect),
              ),
            if (_authMethod == ProviderAuthMethod.chatGpt) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'providerAccountModel-${_modelController.text}-${_accountModels.length}',
                ),
                initialValue:
                    _accountModels.any(
                      (item) => item.id == _modelController.text,
                    )
                    ? _modelController.text
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.chatModel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final option in _accountModels)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        option.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _modelController.text = value ?? ''),
              ),
            ] else if (_authMethod == ProviderAuthMethod.openRouter) ...[
              const SizedBox(height: 14),
              TextField(
                key: const Key('providerOpenRouterModelField'),
                enabled: !_busy,
                controller: _modelController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.providerOpenRouterModel,
                  helperText: l10n.providerOpenRouterModelHelp,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ] else
            TextField(
              key: const Key('providerApiKeyField'),
              controller: _apiKeyController,
              enabled: !_busy,
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
            onPressed: _busy ? null : () => _testConnection(l10n),
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
            onPressed: _busy ? null : () => _save(l10n),
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
      final preset =
          ProviderPreset.byId(widget.initialPresetId) ??
          ProviderPreset.deepSeek;
      _applyPreset(preset, force: true);
      return;
    }
    _type = provider.type;
    _authMethod = provider.authMethod;
    _nameController.text = provider.name;
    _baseUrlController.text = provider.baseUrl;
    _modelController.text = provider.model;
    if (provider.usesAccount) {
      _loadingAccount = true;
      unawaited(_loadSavedAccount(provider));
    }
  }

  void _selectPreset(ProviderPreset preset) {
    final oldHost = Uri.tryParse(_baseUrlController.text)?.host;
    final newHost = Uri.tryParse(preset.baseUrl)?.host;
    setState(() {
      _authMethod = ProviderAuthMethod.apiKey;
      _credential = null;
      _credentialDirty = false;
      _accountModels = const [];
      if (oldHost != null && oldHost != newHost) {
        _apiKeyController.clear();
      }
      _applyPreset(preset, force: true);
      _error = null;
    });
  }

  void _selectType(AiProviderType type) {
    if (_isEditing) {
      setState(() {
        _type = type;
        _error = null;
      });
      return;
    }
    final preset = type == AiProviderType.deepSeek
        ? ProviderPreset.deepSeek
        : ProviderPreset.custom;
    setState(() {
      _applyPreset(preset);
      _error = null;
    });
  }

  ProviderOAuthFlow? _activeFlow;

  void _selectAuthMethod(ProviderAuthMethod method) {
    setState(() {
      _authMethod = method;
      _credential = null;
      _credentialDirty = false;
      _accountModels = const [];
      _apiKeyController.clear();
      _error = null;
      if (method == ProviderAuthMethod.apiKey) {
        _modelController.text =
            _baseUrlController.text.trim() == ProviderPreset.openRouter.baseUrl
            ? ProviderPreset.openRouter.model
            : ProviderPreset.openAi.model;
      } else {
        _type = AiProviderType.openAiCompatible;
        _baseUrlController.text = method.baseUrl!;
        _selectedPresetId = null;
        _modelController.text = method == ProviderAuthMethod.chatGpt
            ? ''
            : ProviderPreset.openRouter.model;
        if (!_isEditing &&
            _isPresetValue(_nameController.text, (preset) => preset.label)) {
          _nameController.text = method == ProviderAuthMethod.chatGpt
              ? 'ChatGPT'
              : ProviderPreset.openRouter.label;
        }
      }
    });
    if (_existing?.authMethod == method &&
        method != ProviderAuthMethod.apiKey) {
      setState(() => _loadingAccount = true);
      unawaited(_loadSavedAccount(_existing!));
    }
  }

  Future<void> _loadSavedAccount(AiProvider provider) async {
    try {
      final repository = ref.read(providerRepositoryProvider);
      var credential = await repository.oauthCredentialFor(provider);
      if (credential != null && provider.usesResponses) {
        await repository.apiKeyFor(provider);
        credential = await repository.oauthCredentialFor(provider);
      }
      final models = credential != null && provider.usesResponses
          ? await ref
                .read(openAiResponsesClientProvider)
                .listModels(accessToken: credential.accessToken)
          : null;
      if (!mounted || _authMethod != provider.authMethod) {
        return;
      }
      setState(() {
        _credential = credential;
        _credentialDirty = false;
        if (models != null) {
          _setAccountModels([
            for (final item in models)
              ModelOption(id: item.id, label: item.label),
          ]);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(context).providerAccountLoadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

  void _setAccountModels(List<ModelOption> models) {
    _accountModels = models;
    if (!models.any((item) => item.id == _modelController.text)) {
      _modelController.text = models.isEmpty ? '' : models.first.id;
    }
  }

  Future<void> _signIn(AppLocalizations l10n) async {
    setState(() {
      _authorizing = true;
      _error = null;
    });
    // Refresh the proxy in case the user connected a VPN/proxy after startup.
    await SystemProxy.apply();
    if (!mounted) {
      return;
    }
    final method = _authMethod;
    final flow = ref.read(providerOAuthFlowProvider);
    _activeFlow = flow;
    try {
      final repository = ref.read(providerRepositoryProvider);
      final credential = method == ProviderAuthMethod.chatGpt
          ? await flow.authorizeChatGpt(
              hostId: await repository.oauthHostId(),
              previous: _credential,
            )
          : await flow.authorizeOpenRouter();
      if (!mounted) {
        return;
      }
      setState(() {
        _credential = credential;
        _credentialDirty = true;
        if (method == ProviderAuthMethod.openRouter &&
            _modelController.text.trim().isEmpty) {
          _modelController.text = ProviderPreset.openRouter.model;
        }
      });
      if (method == ProviderAuthMethod.chatGpt) {
        // Keep the new credential even if the model list cannot be loaded.
        try {
          final models = await ref
              .read(openAiResponsesClientProvider)
              .listModels(accessToken: credential.accessToken);
          if (mounted && _authMethod == method) {
            setState(
              () => _setAccountModels([
                for (final item in models)
                  ModelOption(id: item.id, label: item.label),
              ]),
            );
          }
        } catch (_) {
          if (mounted) {
            setState(() => _error = l10n.providerAccountLoadFailed);
          }
        }
      }
    } on ProviderOAuthException catch (error) {
      if (mounted) {
        setState(() => _error = providerOAuthErrorText(l10n, error));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ChatFailure
              ? chatFailureText(l10n, error)
              : error.toString(),
        );
      }
    } finally {
      _activeFlow = null;
      if (mounted) setState(() => _authorizing = false);
    }
  }

  Future<void> _disconnect(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.providerAccountDisconnect),
        content: Text(l10n.providerAccountDisconnectNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.providerAccountDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      if (_existing != null && _existing!.authMethod == _authMethod) {
        await ref
            .read(providerRepositoryProvider)
            .disconnectAccount(_existing!);
      }
      if (!mounted) return;
      setState(() {
        _credential = null;
        _credentialDirty = false;
        _accountModels = const [];
        _modelController.clear();
      });
    } catch (_) {
      if (mounted) setState(() => _error = l10n.providerAccountLoadFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Applies [preset]. Unless [force] is set, fields edited by the user keep
  /// their value; only empty fields or values that still match a preset are
  /// replaced.
  void _applyPreset(ProviderPreset preset, {bool force = false}) {
    if (force || _isPresetValue(_nameController.text, (item) => item.label)) {
      _nameController.text = preset.label;
    }
    if (force ||
        _isPresetValue(_baseUrlController.text, (item) => item.baseUrl)) {
      _baseUrlController.text = preset.baseUrl;
    }
    if (force || _isPresetValue(_modelController.text, (item) => item.model)) {
      _modelController.text = preset.model;
    }
    _type = preset.type;
    _selectedPresetId = preset.id;
  }

  bool _isPresetValue(
    String value,
    String Function(ProviderPreset preset) select,
  ) {
    final trimmed = value.trim();
    return trimmed.isEmpty ||
        ProviderPreset.all.any((preset) => select(preset) == trimmed);
  }

  Future<void> _testConnection(AppLocalizations l10n) async {
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    var apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty) {
      setState(() => _error = l10n.providerFieldRequired);
      return;
    }
    if (_usesAccount) {
      if (_credential == null) {
        setState(() => _error = l10n.providerAccountRequired);
        return;
      }
      setState(() {
        _testing = true;
        _error = null;
      });
      try {
        if (_authMethod == ProviderAuthMethod.chatGpt) {
          var credential = _credential!;
          if (credential.expiresAt == null ||
              !credential.expiresAt!.isAfter(
                DateTime.now().add(const Duration(seconds: 60)),
              )) {
            if (!_credentialDirty &&
                _existing != null &&
                _existing!.authMethod == _authMethod) {
              await ref.read(providerRepositoryProvider).apiKeyFor(_existing!);
              credential = (await ref
                  .read(providerRepositoryProvider)
                  .oauthCredentialFor(_existing!))!;
            } else {
              credential = await ref
                  .read(providerOAuthFlowProvider)
                  .refreshChatGpt(credential);
              _credentialDirty = true;
            }
            _credential = credential;
          }
          final models = await ref
              .read(openAiResponsesClientProvider)
              .listModels(accessToken: credential.accessToken);
          if (mounted) {
            setState(
              () => _setAccountModels([
                for (final item in models)
                  ModelOption(id: item.id, label: item.label),
              ]),
            );
          }
        } else {
          await ref
              .read(openAiCompatibleClientProvider)
              .testConnection(
                baseUrl: ProviderAuthMethod.openRouter.baseUrl!,
                apiKey: _credential!.accessToken,
                allowRedirects: false,
              );
        }
        if (mounted) _showSnack(l10n.providerTestSuccess);
      } catch (_) {
        if (mounted) setState(() => _error = l10n.providerAccountLoadFailed);
      } finally {
        if (mounted) setState(() => _testing = false);
      }
      return;
    }
    if (apiKey.isEmpty && _existing != null && !_existing!.usesAccount) {
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
      await client.testConnection(baseUrl: baseUrl, apiKey: apiKey);
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
    var model = _modelController.text.trim();
    final options = ProviderModelCatalog.forBaseUrl(baseUrl);
    if (!_usesAccount &&
        options.isNotEmpty &&
        !options.any((option) => option.id == model)) {
      model = options.first.id;
    }
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty) {
      setState(() => _error = l10n.providerFieldRequired);
      return;
    }
    if (_usesAccount && (_credential == null || model.isEmpty)) {
      setState(() => _error = l10n.providerAccountRequired);
      return;
    }
    if (!_usesAccount &&
        (_existing == null || _existing!.usesAccount) &&
        apiKey.isEmpty) {
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
          authMethod: _authMethod,
          credential: _credential,
        );
      } else {
        await controller.save(
          provider: _existing!,
          name: name,
          type: _type,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey.isEmpty ? null : apiKey,
          authMethod: _authMethod,
          credential: _credentialDirty ? _credential : null,
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
        _error = error is ProviderOAuthException
            ? providerOAuthErrorText(l10n, error)
            : error is ChatFailure
            ? chatFailureText(l10n, error)
            : error.toString();
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ProviderPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.16),
            scheme.surfaceContainerHigh,
          )
        : scheme.surfaceContainerHigh;

    return SizedBox(
      width: 172,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      preset.icon,
                      size: 20,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  preset.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
