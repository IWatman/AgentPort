import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/repositories/opencode_repository.dart';
import 'package:agentport/domain/entities/opencode.dart';
import 'package:agentport/features/opencode/opencode_connections_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeOpenCodeRepository extends OpenCodeRepository {
  // The super parameters are private, so they cannot be forwarded with the
  // `super.` shorthand.
  // ignore: use_super_parameters
  _FakeOpenCodeRepository(AppDatabase database, SecureStore secureStore)
    : super(database, secureStore);

  final List<OpenCodeConnection> saved = [];
  Object? pairError;
  Object? manualError;

  @override
  Future<List<OpenCodeConnection>> connections() async => List.of(saved);

  @override
  Future<OpenCodeConnection> pair(
    OpenCodePairing pairing, {
    String? name,
  }) async {
    final error = pairError;
    if (error != null) {
      throw error;
    }
    final connection = OpenCodeConnection(
      id: 'paired-${saved.length}',
      name: name ?? pairing.primaryUrl,
      baseUrl: pairing.primaryUrl,
      tokenRef: 'token-${saved.length}',
    );
    saved.add(connection);
    return connection;
  }

  @override
  Future<OpenCodeConnection> connectManual({
    required String baseUrl,
    required String password,
    String? name,
  }) async {
    final error = manualError;
    if (error != null) {
      throw error;
    }
    final connection = OpenCodeConnection(
      id: 'manual-${saved.length}',
      name: name ?? baseUrl,
      baseUrl: baseUrl,
      tokenRef: 'token-${saved.length}',
    );
    saved.add(connection);
    return connection;
  }

  @override
  Future<void> delete(String id) async {
    saved.removeWhere((connection) => connection.id == id);
  }
}

void main() {
  late AppDatabase database;
  late _MemorySecureStore secureStore;
  late _FakeOpenCodeRepository repository;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    secureStore = _MemorySecureStore();
    repository = _FakeOpenCodeRepository(database, secureStore);
    container = ProviderContainer(
      overrides: [openCodeRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> open() async {
    final subscription = container.listen(
      openCodeConnectionsControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(openCodeConnectionsControllerProvider.future);
  }

  List<OpenCodeConnection> current() =>
      container.read(openCodeConnectionsControllerProvider).value ?? const [];

  test('loads saved connections from the repository', () async {
    repository.saved.add(
      const OpenCodeConnection(
        id: 'saved',
        name: 'Desk',
        baseUrl: 'https://example.com',
        tokenRef: 'ref',
      ),
    );

    await open();

    expect(current(), hasLength(1));
    expect(current().single.name, 'Desk');
  });

  test('pairs a payload and refreshes the list', () async {
    await open();
    final notifier = container.read(
      openCodeConnectionsControllerProvider.notifier,
    );

    final connection = await notifier.pair(
      OpenCodePairing(code: 'abc', urls: ['https://example.com:4096']),
      name: 'Home',
    );

    expect(connection.name, 'Home');
    expect(connection.baseUrl, 'https://example.com:4096');
    expect(repository.saved, hasLength(1));
    expect(current().single.id, connection.id);
  });

  test('connects manually and refreshes the list', () async {
    await open();
    final notifier = container.read(
      openCodeConnectionsControllerProvider.notifier,
    );

    final connection = await notifier.connectManual(
      baseUrl: 'http://192.168.1.10:4096',
      password: 'secret',
      name: 'Workshop',
    );

    expect(connection.name, 'Workshop');
    expect(repository.saved.single.baseUrl, 'http://192.168.1.10:4096');
    expect(current().single.id, connection.id);
  });

  test('deletes a connection and updates the list', () async {
    repository.saved.addAll(const [
      OpenCodeConnection(
        id: 'one',
        name: 'One',
        baseUrl: 'https://one.example',
        tokenRef: 'one',
      ),
      OpenCodeConnection(
        id: 'two',
        name: 'Two',
        baseUrl: 'https://two.example',
        tokenRef: 'two',
      ),
    ]);
    await open();
    final notifier = container.read(
      openCodeConnectionsControllerProvider.notifier,
    );

    await notifier.delete('one');

    expect(repository.saved.single.id, 'two');
    expect(current().single.id, 'two');
  });

  test('rethrows a pairing failure and keeps the list', () async {
    await open();
    repository.pairError = const OpenCodeFailure(
      OpenCodeFailureKind.unauthorized,
    );
    final notifier = container.read(
      openCodeConnectionsControllerProvider.notifier,
    );

    await expectLater(
      notifier.pair(
        OpenCodePairing(code: 'bad', urls: ['https://example.com']),
      ),
      throwsA(
        isA<OpenCodeFailure>().having(
          (failure) => failure.kind,
          'kind',
          OpenCodeFailureKind.unauthorized,
        ),
      ),
    );
    expect(current(), isEmpty);
  });
}
