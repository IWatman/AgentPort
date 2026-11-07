import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/security/secure_store.dart';
import '../../domain/entities/opencode.dart';
import '../opencode/opencode_auth.dart';
import '../opencode/opencode_client.dart';
import '../opencode/opencode_endpoints.dart';

/// Stores OpenCode connections and resolves their access tokens from the
/// Android Keystore.
class OpenCodeRepository {
  OpenCodeRepository(
    this._database,
    this._secureStore, {
    OpenCodeAuth? auth,
    OpenCodeHttpClientFactory? clientFactory,
    Uuid? uuid,
  }) : _auth = auth ?? OpenCodeAuth(clientFactory: clientFactory),
       _clientFactory = clientFactory ?? _defaultClient,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final SecureStore _secureStore;
  final OpenCodeAuth _auth;
  final OpenCodeHttpClientFactory _clientFactory;
  final Uuid _uuid;

  static http.Client _defaultClient() => http.Client();

  static String tokenKey(String tokenRef) =>
      'agentport.opencode.token.$tokenRef';

  Future<List<OpenCodeConnection>> connections() async {
    final rows = await (_database.select(
      _database.openCodeConnectionEntries,
    )..orderBy([(table) => OrderingTerm.desc(table.lastSeen)])).get();
    return rows.map(_toConnection).toList(growable: false);
  }

  Future<OpenCodeConnection?> connection(String id) async {
    final row = await (_database.select(
      _database.openCodeConnectionEntries,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toConnection(row);
  }

  /// Redeems a pairing payload against the advertised URLs.
  ///
  /// Network failures try the next URL; authentication, version, and protocol
  /// failures stop immediately because another address will not fix them.
  Future<OpenCodeConnection> pair(
    OpenCodePairing pairing, {
    String? name,
  }) async {
    OpenCodeFailure? lastFailure;
    for (final url in pairing.urls) {
      final String token;
      try {
        token = await _auth.redeem(baseUrl: url, code: pairing.code);
      } on OpenCodeFailure catch (error) {
        lastFailure = error;
        if (!_isRetryable(error)) {
          rethrow;
        }
        continue;
      }

      final client = OpenCodeClient(
        baseUrl: url,
        token: token,
        clientFactory: _clientFactory,
      );
      final info = await client.info();
      return _save(
        baseUrl: url,
        token: token,
        name: name ?? _defaultName(url),
        info: info,
      );
    }

    throw lastFailure ??
        const OpenCodeFailure(
          OpenCodeFailureKind.network,
          detail: 'No OpenCode server URL was reachable.',
        );
  }

  /// Connects with a server URL and the service password.
  Future<OpenCodeConnection> connectManual({
    required String baseUrl,
    required String password,
    String? name,
  }) async {
    final normalized = normalizeOpenCodeBaseUrl(baseUrl);
    final client = OpenCodeClient(
      baseUrl: normalized,
      token: password,
      clientFactory: _clientFactory,
    );
    final info = await client.info();
    return _save(
      baseUrl: normalized,
      token: password,
      name: name ?? _defaultName(normalized),
      info: info,
    );
  }

  /// Checks a saved connection and refreshes its last-seen timestamp.
  Future<OpenCodeInfo> probe(OpenCodeConnection connection) async {
    final client = await clientFor(connection);
    final info = await client.info();
    await touch(connection);
    return info;
  }

  Future<OpenCodeClient> clientFor(OpenCodeConnection connection) async {
    final token = await tokenFor(connection);
    return OpenCodeClient(
      baseUrl: connection.baseUrl,
      token: token,
      username: connection.username,
      clientFactory: _clientFactory,
    );
  }

  Future<String> tokenFor(OpenCodeConnection connection) async {
    final token = await _secureStore.read(tokenKey(connection.tokenRef));
    if (token == null || token.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.unauthorized,
        detail: 'The OpenCode token is missing. Pair the server again.',
      );
    }
    return token;
  }

  Future<void> touch(OpenCodeConnection connection) async {
    await (_database.update(
      _database.openCodeConnectionEntries,
    )..where((table) => table.id.equals(connection.id))).write(
      OpenCodeConnectionEntriesCompanion(
        lastSeen: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> delete(String id) async {
    final existing = await connection(id);
    await _database.transaction(() async {
      await (_database.delete(
        _database.openCodeConnectionEntries,
      )..where((table) => table.id.equals(id))).go();
    });
    if (existing != null) {
      await _secureStore.delete(tokenKey(existing.tokenRef));
    }
  }

  Future<OpenCodeConnection> _save({
    required String baseUrl,
    required String token,
    required String name,
    required OpenCodeInfo info,
  }) async {
    final id = _uuid.v4();
    final tokenRef = _uuid.v4();
    await _secureStore.write(tokenKey(tokenRef), token);
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _database
          .into(_database.openCodeConnectionEntries)
          .insert(
            OpenCodeConnectionEntriesCompanion.insert(
              id: id,
              name: name,
              baseUrl: baseUrl,
              tokenRef: tokenRef,
              lastSeen: Value(now),
              createdAt: now,
            ),
          );
    } catch (_) {
      await _secureStore.delete(tokenKey(tokenRef));
      rethrow;
    }

    return OpenCodeConnection(
      id: id,
      name: name,
      baseUrl: baseUrl,
      tokenRef: tokenRef,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  bool _isRetryable(OpenCodeFailure failure) {
    return switch (failure.kind) {
      OpenCodeFailureKind.network ||
      OpenCodeFailureKind.timeout ||
      OpenCodeFailureKind.server => true,
      _ => false,
    };
  }

  String _defaultName(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = uri?.host ?? '';
    if (host.isEmpty) {
      return baseUrl;
    }
    if (uri != null && uri.hasPort) {
      return '$host:${uri.port}';
    }
    return host;
  }

  OpenCodeConnection _toConnection(OpenCodeConnectionEntry row) {
    return OpenCodeConnection(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      username: row.username,
      tokenRef: row.tokenRef,
      lastSeen: row.lastSeen == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.lastSeen!),
    );
  }
}

final openCodeRepositoryProvider = Provider<OpenCodeRepository>((ref) {
  return OpenCodeRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(secureStoreProvider),
  );
});
