import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/security/secure_store.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/chat_failure.dart';
import '../../domain/entities/provider_oauth.dart';
import '../auth/provider_oauth.dart';

class ProviderRepository {
  ProviderRepository(
    this._database,
    this._secureStore, {
    Uuid? uuid,
    ProviderOAuthFlow? oauthFlow,
  }) : _uuid = uuid ?? const Uuid(),
       _oauthFlow = oauthFlow ?? ProviderOAuthFlow();

  final AppDatabase _database;
  final SecureStore _secureStore;
  final Uuid _uuid;
  final ProviderOAuthFlow _oauthFlow;
  final _credentialLocks = <String, Future<void>>{};
  Future<String>? _hostId;

  /// Installation identity is opaque, local, and excluded from backups.
  Future<String> oauthHostId() => _hostId ??= _loadHostId();

  Future<String> _loadHostId() async {
    const key = 'agentport.provider.oauth.host';
    final stored = await _secureStore.read(key);
    if (stored != null && stored.isNotEmpty) return stored;
    final value = 'urn:uuid:${_uuid.v4()}';
    await _secureStore.write(key, value);
    return value;
  }

  Future<List<AiProvider>> list() async {
    final rows = await (_database.select(
      _database.providerEntries,
    )..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();
    return rows.map(_toDomain).toList(growable: false);
  }

  Future<AiProvider?> get(String id) async {
    final row = await (_database.select(
      _database.providerEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<String?> apiKeyFor(
    AiProvider provider,
  ) => _locked(provider.id, () async {
    if (!provider.usesAccount) return _secureStore.read(provider.apiKeyRef);
    _validateEndpoint(provider.authMethod, provider.baseUrl);
    final current = await get(provider.id);
    if (current == null ||
        current.authMethod != provider.authMethod ||
        current.baseUrl != provider.baseUrl) {
      throw const ChatFailure(
        ChatFailureKind.unauthorized,
        detail: 'The provider account changed. Select it again.',
      );
    }
    var credential = await oauthCredentialFor(provider);
    if (credential == null) {
      throw const ChatFailure(
        ChatFailureKind.unauthorized,
        detail: 'Sign in to this provider again in Settings → AI providers.',
      );
    }
    if (credential.method != provider.authMethod) {
      throw const ChatFailure(
        ChatFailureKind.unauthorized,
        detail: 'The saved account does not match this provider.',
      );
    }
    if (provider.usesResponses &&
        (credential.expiresAt == null ||
            !credential.expiresAt!.isAfter(
              DateTime.now().add(const Duration(seconds: 60)),
            ))) {
      try {
        credential = await _oauthFlow.refreshChatGpt(credential);
        await _secureStore.write(
          _oauthRef(provider),
          jsonEncode(credential.toJson()),
        );
      } catch (_) {
        // Keep the rotating refresh token on transient failures. Never log it.
        throw const ChatFailure(
          ChatFailureKind.unauthorized,
          detail: 'Could not renew the ChatGPT session. Retry or sign in again in Settings → AI providers.',
        );
      }
    }
    return credential.accessToken;
  });

  Future<ProviderOAuthCredential?> oauthCredentialFor(
    AiProvider provider,
  ) async {
    final raw = await _secureStore.read(_oauthRef(provider));
    if (raw == null) return null;
    try {
      return ProviderOAuthCredential.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      throw const ChatFailure(
        ChatFailureKind.unauthorized,
        detail: 'The saved account is invalid. Sign in again.',
      );
    }
  }

  Future<void> disconnectAccount(AiProvider provider) =>
      _locked(provider.id, () async {
        await _secureStore.delete(_oauthRef(provider));
      });

  String _oauthRef(AiProvider provider) => '${provider.apiKeyRef}.oauth';

  Future<T> _locked<T>(String id, Future<T> Function() action) async {
    final previous = _credentialLocks[id];
    final done = Completer<void>();
    _credentialLocks[id] = done.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_credentialLocks[id], done.future)) {
        _credentialLocks.remove(id);
      }
    }
  }

  void _validateEndpoint(ProviderAuthMethod method, String baseUrl) {
    if (method == ProviderAuthMethod.apiKey) return;
    if (!method.allowsBaseUrl(baseUrl)) {
      throw const ChatFailure(
        ChatFailureKind.badRequest,
        detail: 'Account credentials can only be sent to the official provider endpoint.',
      );
    }
  }

  Future<AiProvider> create({
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    required String apiKey,
    ProviderAuthMethod authMethod = ProviderAuthMethod.apiKey,
    ProviderOAuthCredential? credential,
  }) async {
    _validateEndpoint(authMethod, baseUrl);
    if (authMethod == ProviderAuthMethod.apiKey) {
      if (credential != null) {
        throw ArgumentError('API-key providers cannot store an account.');
      }
    } else if (credential == null) {
      throw const ChatFailure(
        ChatFailureKind.badRequest,
        detail: 'Sign in to the provider account before saving.',
      );
    } else if (credential.method != authMethod) {
      throw ArgumentError('Account type mismatch.');
    }
    final id = _uuid.v4();
    final apiKeyRef = _apiKeyRef(id);
    if (authMethod == ProviderAuthMethod.apiKey) {
      await _secureStore.write(apiKeyRef, apiKey);
    }
    final oauthRef = '$apiKeyRef.oauth';
    if (credential != null) {
      await _secureStore.write(oauthRef, jsonEncode(credential.toJson()));
    }
    try {
      await _database
          .into(_database.providerEntries)
          .insert(
            ProviderEntriesCompanion.insert(
              id: id,
              name: name,
              type: type.storageValue,
              baseUrl: baseUrl,
              model: model,
              apiKeyRef: apiKeyRef,
              authMethod: Value(authMethod.storageValue),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    } catch (_) {
      await _secureStore.delete(apiKeyRef);
      await _secureStore.delete(oauthRef);
      rethrow;
    }
    return AiProvider(
      id: id,
      name: name,
      type: type,
      baseUrl: baseUrl,
      model: model,
      apiKeyRef: apiKeyRef,
      authMethod: authMethod,
    );
  }

  Future<void> update({
    required AiProvider provider,
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    String? apiKey,
    ProviderAuthMethod? authMethod,
    ProviderOAuthCredential? credential,
  }) => _locked(provider.id, () async {
    final method = authMethod ?? provider.authMethod;
    _validateEndpoint(method, baseUrl);
    if (credential != null && credential.method != method) {
      throw ArgumentError('Account type mismatch.');
    }
    if (method == ProviderAuthMethod.apiKey) {
      if (credential != null) {
        throw ArgumentError('API-key providers cannot store an account.');
      }
      if (provider.usesAccount && (apiKey == null || apiKey.isEmpty)) {
        throw const ChatFailure(
          ChatFailureKind.badRequest,
          detail: 'Enter an API key before switching this provider to key authentication.',
        );
      }
    } else {
      final stored =
          credential ??
          (method == provider.authMethod
              ? await oauthCredentialFor(provider)
              : null);
      if (stored == null || stored.method != method) {
        throw const ChatFailure(
          ChatFailureKind.badRequest,
          detail: 'Sign in to the provider account before saving.',
        );
      }
    }
    await (_database.update(
      _database.providerEntries,
    )..where((table) => table.id.equals(provider.id))).write(
      ProviderEntriesCompanion(
        name: Value(name),
        type: Value(type.storageValue),
        baseUrl: Value(baseUrl),
        model: Value(model),
        authMethod: Value(method.storageValue),
      ),
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStore.write(provider.apiKeyRef, apiKey);
    }
    if (method == ProviderAuthMethod.apiKey) {
      await _secureStore.delete(_oauthRef(provider));
    } else {
      await _secureStore.delete(provider.apiKeyRef);
      if (credential != null) {
        await _secureStore.write(
          _oauthRef(provider),
          jsonEncode(credential.toJson()),
        );
      }
    }
  });

  Future<void> delete(AiProvider provider) => _locked(provider.id, () async {
    await (_database.update(_database.conversations)
          ..where((table) => table.providerId.equals(provider.id)))
        .write(const ConversationsCompanion(model: Value(null)));
    await (_database.delete(
      _database.providerEntries,
    )..where((table) => table.id.equals(provider.id))).go();
    await _secureStore.delete(provider.apiKeyRef);
    await _secureStore.delete(_oauthRef(provider));
  });

  String _apiKeyRef(String providerId) => 'agentport.provider.$providerId.key';

  AiProvider _toDomain(ProviderEntry row) {
    return AiProvider(
      id: row.id,
      name: row.name,
      type: AiProviderType.fromStorage(row.type),
      baseUrl: row.baseUrl,
      model: row.model,
      apiKeyRef: row.apiKeyRef,
      authMethod: ProviderAuthMethod.fromStorage(row.authMethod),
    );
  }
}

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStoreProvider),
    oauthFlow: ref.watch(providerOAuthFlowProvider),
  );
});
