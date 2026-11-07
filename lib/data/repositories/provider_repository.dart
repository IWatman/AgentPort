import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/security/secure_store.dart';
import '../../domain/entities/ai_provider.dart';

class ProviderRepository {
  ProviderRepository(this._database, this._secureStore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SecureStore _secureStore;
  final Uuid _uuid;

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

  Future<String?> apiKeyFor(AiProvider provider) {
    return _secureStore.read(provider.apiKeyRef);
  }

  Future<AiProvider> create({
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final id = _uuid.v4();
    final apiKeyRef = _apiKeyRef(id);
    await _secureStore.write(apiKeyRef, apiKey);
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
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    return AiProvider(
      id: id,
      name: name,
      type: type,
      baseUrl: baseUrl,
      model: model,
      apiKeyRef: apiKeyRef,
    );
  }

  Future<void> update({
    required AiProvider provider,
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStore.write(provider.apiKeyRef, apiKey);
    }
    await (_database.update(
      _database.providerEntries,
    )..where((table) => table.id.equals(provider.id))).write(
      ProviderEntriesCompanion(
        name: Value(name),
        type: Value(type.storageValue),
        baseUrl: Value(baseUrl),
        model: Value(model),
      ),
    );
  }

  Future<void> delete(AiProvider provider) async {
    await (_database.delete(
      _database.providerEntries,
    )..where((table) => table.id.equals(provider.id))).go();
    await _secureStore.delete(provider.apiKeyRef);
  }

  String _apiKeyRef(String providerId) => 'agentport.provider.$providerId.key';

  AiProvider _toDomain(ProviderEntry row) {
    return AiProvider(
      id: row.id,
      name: row.name,
      type: AiProviderType.fromStorage(row.type),
      baseUrl: row.baseUrl,
      model: row.model,
      apiKeyRef: row.apiKeyRef,
    );
  }
}

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStoreProvider),
  );
});
