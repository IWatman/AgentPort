import 'dart:convert';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/data/mcp/mcp_client.dart';
import 'package:agentport/data/mcp/mcp_credentials.dart';
import 'package:agentport/data/mcp/mcp_oauth.dart';
import 'package:agentport/data/repositories/mcp_server_repository.dart';
import 'package:agentport/domain/entities/mcp.dart';
import 'package:agentport/domain/entities/mcp_oauth.dart';
import 'package:drift/drift.dart' as drift;
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

class _FakeServer {
  final List<http.Request> requests = [];

  MockClient client() {
    return MockClient((request) async {
      requests.add(request);
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final method = body['method'];
      final id = body['id'];
      if (method == 'notifications/initialized') {
        return http.Response('', 202);
      }
      final result = switch (method) {
        'initialize' => {
          'protocolVersion': McpClient.protocolVersion,
          'capabilities': {'tools': {}},
        },
        'tools/list' => {
          'tools': [
            {
              'name': 'search_docs',
              'description': 'Search documentation',
              'inputSchema': {'type': 'object'},
            },
          ],
        },
        'tools/call' => {
          'content': [
            {'type': 'text', 'text': 'tool output'},
          ],
        },
        _ => null,
      };
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
        200,
        headers: const {
          'content-type': 'application/json',
          'mcp-session-id': 's1',
        },
      );
    });
  }
}

class _FakeOAuthFlow extends McpOAuthFlow {
  var refreshes = 0;

  @override
  Future<McpOAuthToken> refresh(McpOAuthToken token) async {
    refreshes++;
    return token.copyWith(
      accessToken: 'refreshed',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

void main() {
  late AppDatabase database;
  late _MemorySecureStore secureStore;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    secureStore = _MemorySecureStore();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database
        .into(database.marketplaceEntries)
        .insert(
          MarketplaceEntriesCompanion.insert(
            id: 'm1',
            name: 'Marketplace',
            description: const drift.Value(''),
            sourceUrl: 'https://github.com/acme/plugins',
            manifestUrl:
                'https://raw.githubusercontent.com/acme/plugins/main/'
                '.claude-plugin/marketplace.json',
            createdAt: now,
          ),
        );
    await database
        .into(database.marketplacePluginEntries)
        .insert(
          MarketplacePluginEntriesCompanion.insert(
            id: 'p1',
            marketplaceId: 'm1',
            name: 'context7',
            displayName: const drift.Value('Context7'),
            description: const drift.Value('Docs'),
            sourceJson: '"./context7"',
            sourceKind: 'path',
            mcpConfigJson: drift.Value(
              jsonEncode([
                {
                  'name': 'context7',
                  'type': 'http',
                  'url': 'https://mcp.example.com/mcp',
                  'headerNames': ['Authorization'],
                  'headerTemplates': {'Authorization': r'${TOKEN}'},
                },
              ]),
            ),
            lastSeenAt: now,
            createdAt: now,
          ),
        );
    await database
        .into(database.mcpServerEntries)
        .insert(
          McpServerEntriesCompanion.insert(
            id: 'p1/context7',
            pluginId: const drift.Value('p1'),
            marketplaceId: const drift.Value('m1'),
            name: 'context7',
            url: 'https://mcp.example.com/mcp',
            transport: 'http',
            authType: 'api-key',
            headerNamesJson: const drift.Value('["Authorization"]'),
            configHash: 'hash',
            createdAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  McpServerRepository repositoryFor(_FakeServer fake) {
    return McpServerRepository(
      database,
      McpCredentialStore(secureStore),
      client: McpClient(clientFactory: fake.client),
    );
  }

  test('adds bearer tokens and refreshes expired OAuth credentials', () async {
    final credentials = McpCredentialStore(secureStore);
    final oauth = _FakeOAuthFlow();
    final repository = McpServerRepository(
      database,
      credentials,
      client: McpClient(clientFactory: _FakeServer().client),
      oauth: oauth,
    );
    const serverId = 'p1/context7';

    await credentials.saveOAuthToken(
      serverId,
      McpOAuthToken(
        accessToken: 'access-1',
        tokenEndpoint: 'https://auth.example/token',
        clientId: 'client-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    var headers = await repository.requestHeaders(serverId);
    expect(headers['Authorization'], 'Bearer access-1');
    expect(oauth.refreshes, 0);

    await credentials.saveOAuthToken(
      serverId,
      McpOAuthToken(
        accessToken: 'expired',
        refreshToken: 'refresh-1',
        tokenEndpoint: 'https://auth.example/token',
        clientId: 'client-1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    headers = await repository.requestHeaders(serverId);
    expect(headers['Authorization'], 'Bearer refreshed');
    expect(oauth.refreshes, 1);
    expect(await repository.hasOAuthToken(serverId), isTrue);

    await repository.saveHeaders(serverId, const {'X-Test': '1'});
    expect(await repository.hasOAuthToken(serverId), isFalse);
  });

  test('lists installed servers with plugin and template metadata', () async {
    final repository = repositoryFor(_FakeServer());
    final servers = await repository.listServers();

    expect(servers, hasLength(1));
    final server = servers.single;
    expect(server.id, 'p1/context7');
    expect(server.displayName, 'Context7');
    expect(server.pluginTitle, 'Context7');
    expect(server.requiredHeaders, ['Authorization']);
    expect(server.headerTemplates['Authorization'], r'${TOKEN}');
    expect(server.supportsCurrentTransport, isTrue);
  });

  test('refreshes tools, caches them, and calls a tool with headers', () async {
    final fake = _FakeServer();
    final repository = repositoryFor(fake);
    await repository.saveHeaders('p1/context7', const {});

    final tools = await repository.refreshTools('p1/context7');
    expect(tools, hasLength(1));
    expect(tools.single.name, 'search_docs');
    expect(tools.single.needsApproval, isFalse);

    final cached = await repository.toolsFor('p1/context7');
    expect(cached.single.name, 'search_docs');

    final result = await repository.callTool(
      serverId: 'p1/context7',
      toolName: 'search_docs',
      arguments: const {'query': 'flutter'},
    );
    expect(result.content, 'tool output');

    final call = fake.requests.firstWhere(
      (request) => request.body.contains('tools/call'),
    );
    expect(call.headers['Mcp-Session-Id'], 's1');
  });

  test('stores header values in the secure store only', () async {
    final repository = repositoryFor(_FakeServer());
    await repository.saveHeaders('p1/context7', const {
      'Authorization': 'Bearer secret',
    });

    final headers = await repository.headersFor('p1/context7');
    expect(headers, {'Authorization': 'Bearer secret'});
    expect(secureStore.values.values.join(), contains('Bearer secret'));
    final databaseServer = await database
        .select(database.mcpServerEntries)
        .getSingle();
    expect(databaseServer.url, isNot(contains('secret')));
  });

  test('disabled servers cannot call tools', () async {
    final repository = repositoryFor(_FakeServer());
    await repository.setEnabled('p1/context7', false);

    expect(
      () => repository.callTool(
        serverId: 'p1/context7',
        toolName: 'search_docs',
        arguments: const {},
      ),
      throwsA(
        isA<McpFailure>().having(
          (failure) => failure.kind,
          'kind',
          McpFailureKind.protocol,
        ),
      ),
    );
  });
}
