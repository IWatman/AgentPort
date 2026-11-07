import 'dart:convert';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/repositories/opencode_repository.dart';
import 'package:agentport/domain/entities/opencode.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemorySecureStore extends SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late AppDatabase database;
  late _MemorySecureStore secureStore;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secureStore = _MemorySecureStore();
  });

  tearDown(() async {
    await database.close();
  });

  OpenCodeRepository repository(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return OpenCodeRepository(
      database,
      secureStore,
      clientFactory: () => MockClient(handler),
    );
  }

  test(
    'redeems a pairing code, verifies the version, and saves a token',
    () async {
      final paths = <String>[];
      final repo = repository((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/auth/connect/abc123')) {
          return _json({'token': 'token-1'});
        }
        return _json({'version': '2.2.5', 'urls': <String>[]});
      });

      final connection = await repo.pair(
        OpenCodePairing(code: 'abc123', urls: ['https://example.com:4096']),
        name: 'Desk',
      );

      expect(connection.name, 'Desk');
      expect(connection.baseUrl, 'https://example.com:4096');
      expect(connection.username, 'opencode');
      expect(
        await secureStore.read(
          OpenCodeRepository.tokenKey(connection.tokenRef),
        ),
        'token-1',
      );
      expect(paths, ['/auth/connect/abc123', '/api/info']);

      final saved = await repo.connections();
      expect(saved.single.id, connection.id);
      expect(saved.single.lastSeen, isNotNull);
    },
  );

  test('tries the next URL after a network failure', () async {
    final hosts = <String>[];
    final repo = repository((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'first.example') {
        throw http.ClientException('unreachable', request.url);
      }
      if (request.url.path.endsWith('/auth/connect/abc')) {
        return _json({'token': 'token-2'});
      }
      return _json({'version': '2.3.0'});
    });

    final connection = await repo.pair(
      OpenCodePairing(
        code: 'abc',
        urls: ['https://first.example', 'https://second.example'],
      ),
    );

    expect(connection.baseUrl, 'https://second.example');
    expect(hosts, containsAllInOrder(['first.example', 'second.example']));
  });

  test('does not retry when the pairing code is rejected', () async {
    var calls = 0;
    final repo = repository((request) async {
      calls++;
      return _json({'error': 'expired'}, 404);
    });

    await expectLater(
      repo.pair(
        OpenCodePairing(
          code: 'abc',
          urls: ['https://first.example', 'https://second.example'],
        ),
      ),
      throwsA(
        isA<OpenCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          OpenCodeFailureKind.unauthorized,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('connects manually with a password and normalizes the URL', () async {
    final repo = repository((request) async {
      expect(request.url.toString(), 'https://example.com/api/info');
      expect(
        request.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('opencode:secret'))}',
      );
      return _json({'version': '2.2.5'});
    });

    final connection = await repo.connectManual(
      baseUrl: 'https://example.com/',
      password: 'secret',
    );

    expect(connection.baseUrl, 'https://example.com');
    expect(connection.name, 'example.com');
    final token = await repo.tokenFor(connection);
    expect(token, 'secret');
  });

  test('probe refreshes lastSeen and delete removes the token', () async {
    final repo = repository((request) async {
      if (request.url.path.endsWith('/auth/connect/abc')) {
        return _json({'token': 'token-3'});
      }
      return _json({'version': '2.2.5'});
    });
    final connection = await repo.pair(
      OpenCodePairing(code: 'abc', urls: ['https://example.com']),
    );

    await Future<void>.delayed(const Duration(milliseconds: 2));
    final info = await repo.probe(connection);
    expect(info.version, '2.2.5');

    final refreshed = await repo.connection(connection.id);
    expect(refreshed!.lastSeen!.isAfter(connection.lastSeen!), isTrue);

    await repo.delete(connection.id);
    expect(await repo.connections(), isEmpty);
    expect(
      secureStore.values.containsKey(
        OpenCodeRepository.tokenKey(connection.tokenRef),
      ),
      isFalse,
    );
  });

  test('rejects a missing token with an authorization failure', () async {
    final repo = repository((request) async => _json({'version': '2.2.5'}));
    const connection = OpenCodeConnection(
      id: 'id',
      name: 'name',
      baseUrl: 'https://example.com',
      tokenRef: 'missing',
    );

    await expectLater(
      repo.tokenFor(connection),
      throwsA(
        isA<OpenCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          OpenCodeFailureKind.unauthorized,
        ),
      ),
    );
  });
}
