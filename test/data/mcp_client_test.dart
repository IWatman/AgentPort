import 'dart:async';
import 'dart:convert';

import 'package:agentport/data/mcp/mcp_client.dart';
import 'package:agentport/domain/entities/marketplace.dart';
import 'package:agentport/domain/entities/mcp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

McpServer _server({McpTransport transport = McpTransport.http}) {
  return McpServer(
    id: 'builtin/context7/context7',
    name: 'context7',
    pluginTitle: 'Context7',
    url: 'https://mcp.example.com/mcp',
    transport: transport,
    authType: McpAuthType.apiKey,
    enabled: true,
    headerNames: const ['Authorization'],
    headerTemplates: const {'Authorization': r'${TOKEN}'},
  );
}

class _FakeMcpServer {
  int requests = 0;
  final List<http.Request> seen = [];
  bool sse = false;

  MockClient client() {
    return MockClient((request) async {
      requests++;
      seen.add(request);
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
          'serverInfo': {'name': 'fake', 'version': '1'},
        },
        'tools/list' => {
          'tools': [
            {
              'name': 'search_docs',
              'description': 'Search documentation',
              'inputSchema': {
                'type': 'object',
                'properties': {
                  'query': {'type': 'string'},
                },
              },
            },
            {
              'name': 'write_file',
              'description': 'Write a file',
              'inputSchema': {'type': 'object'},
            },
          ],
        },
        'tools/call' => {
          'content': [
            {'type': 'text', 'text': 'result text'},
          ],
          'isError': false,
        },
        _ => null,
      };

      final message = jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });
      final headers = <String, String>{
        'content-type': sse ? 'text/event-stream' : 'application/json',
        'mcp-session-id': 'session-1',
      };
      if (sse) {
        return http.Response(
          'event: message\ndata: $message\n\n',
          200,
          headers: headers,
        );
      }
      return http.Response(message, 200, headers: headers);
    });
  }
}

class _FakeLegacySseServer extends http.BaseClient {
  _FakeLegacySseServer({
    this.endpoint = '/messages?session=legacy',
    this.sse = true,
    this.directResponses = false,
  });

  final String endpoint;
  final bool sse;
  final bool directResponses;
  final StreamController<List<int>> _events = StreamController<List<int>>();
  final List<http.BaseRequest> requests = [];
  final List<http.Request> posts = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (request.method == 'GET') {
      if (!sse) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('not an event stream')),
          200,
          headers: const {'content-type': 'text/plain'},
        );
      }
      _events.add(utf8.encode('event: endpoint\ndata: $endpoint\n\n'));
      return http.StreamedResponse(
        _events.stream,
        200,
        headers: const {'content-type': 'text/event-stream'},
      );
    }

    final post = request as http.Request;
    posts.add(post);
    final body = jsonDecode(post.body) as Map<String, Object?>;
    final method = body['method'];
    if (method == 'notifications/initialized') {
      return http.StreamedResponse(Stream<List<int>>.empty(), 202);
    }

    final result = switch (method) {
      'initialize' => {
        'protocolVersion': McpClient.legacyProtocolVersion,
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'legacy', 'version': '1'},
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
          {'type': 'text', 'text': 'legacy result'},
        ],
      },
      _ => null,
    };
    final message = jsonEncode({
      'jsonrpc': '2.0',
      'id': body['id'],
      'result': result,
    });
    if (directResponses) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(message)),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    _events.add(utf8.encode('event: message\ndata: $message\n\n'));
    return http.StreamedResponse(Stream<List<int>>.empty(), 202);
  }

  void dispose() {
    unawaited(_events.close());
  }
}

void main() {
  group('McpClient', () {
    test('initializes, sends the session id, and lists tools', () async {
      final fake = _FakeMcpServer();
      final client = McpClient(clientFactory: fake.client);

      final session = await client.connect(
        server: _server(),
        headers: const {'Authorization': 'Bearer test'},
      );
      addTearDown(session.close);
      final tools = await session.listTools();

      expect(tools, hasLength(2));
      expect(tools.first.name, 'search_docs');
      expect(tools.first.serverId, 'builtin/context7/context7');
      expect(tools.first.inputSchema['type'], 'object');
      expect(tools.first.needsApproval, isFalse);
      expect(tools[1].needsApproval, isTrue);

      final initialize = fake.seen.first;
      expect(initialize.headers['Authorization'], 'Bearer test');
      expect(initialize.headers['Accept'], contains('text/event-stream'));
      final toolsRequest = fake.seen.firstWhere(
        (request) => request.body.contains('tools/list'),
      );
      expect(toolsRequest.headers['Mcp-Session-Id'], 'session-1');
      expect(toolsRequest.headers['MCP-Protocol-Version'], isNotEmpty);
    });

    test('parses SSE responses', () async {
      final fake = _FakeMcpServer()..sse = true;
      final client = McpClient(clientFactory: fake.client);

      final session = await client.connect(server: _server());
      addTearDown(session.close);
      final tools = await session.listTools();

      expect(tools.map((tool) => tool.name), ['search_docs', 'write_file']);
    });

    test('calls a tool and returns text content', () async {
      final fake = _FakeMcpServer();
      final client = McpClient(clientFactory: fake.client);

      final session = await client.connect(server: _server());
      addTearDown(session.close);
      final result = await session.callTool('search_docs', {
        'query': 'flutter',
      });

      expect(result.content, 'result text');
      expect(result.isError, isFalse);
      final call = fake.seen.firstWhere(
        (request) => request.body.contains('tools/call'),
      );
      final body = jsonDecode(call.body) as Map<String, Object?>;
      final params = body['params'] as Map<String, Object?>;
      expect(params['name'], 'search_docs');
      expect((params['arguments'] as Map)['query'], 'flutter');
    });

    test('maps HTTP 401 to an authorization failure', () async {
      final client = McpClient(
        clientFactory: () =>
            MockClient((request) async => http.Response('denied', 401)),
      );

      await expectLater(
        client.connect(server: _server()),
        throwsA(
          isA<McpFailure>().having(
            (failure) => failure.kind,
            'kind',
            McpFailureKind.unauthorized,
          ),
        ),
      );
    });

    test(
      'completes initialize, tools/list, and tools/call over legacy SSE',
      () async {
        final fake = _FakeLegacySseServer();
        addTearDown(fake.dispose);
        final client = McpClient(clientFactory: () => fake);

        final session = await client.connect(
          server: _server(transport: McpTransport.sse),
          headers: const {'Authorization': 'Bearer legacy'},
        );
        addTearDown(session.close);

        final tools = await session.listTools();
        expect(tools.map((tool) => tool.name), ['search_docs']);

        final result = await session.callTool('search_docs', {'query': 'sse'});
        expect(result.content, 'legacy result');

        final get = fake.requests.singleWhere(
          (request) => request.method == 'GET',
        );
        expect(get.url.path, '/mcp');
        expect(get.headers['Accept'], 'text/event-stream');
        expect(get.headers['Authorization'], 'Bearer legacy');

        final initialize = fake.posts.firstWhere(
          (request) => request.body.contains('"method":"initialize"'),
        );
        expect(initialize.url.path, '/messages');
        expect(initialize.url.queryParameters['session'], 'legacy');
        expect(initialize.headers['Authorization'], 'Bearer legacy');
        final params =
            (jsonDecode(initialize.body) as Map<String, Object?>)['params']
                as Map<String, Object?>;
        expect(params['protocolVersion'], '2024-11-05');
        expect(params['protocolVersion'], McpClient.legacyProtocolVersion);

        expect(fake.posts, isNotEmpty);
        for (final post in fake.posts) {
          expect(post.headers['Authorization'], 'Bearer legacy');
        }
        expect(
          fake.posts.map((request) => request.body),
          contains(contains('notifications/initialized')),
        );
      },
    );

    test('accepts direct JSON responses to legacy POSTs', () async {
      final fake = _FakeLegacySseServer(directResponses: true);
      addTearDown(fake.dispose);
      final client = McpClient(clientFactory: () => fake);

      final session = await client.connect(
        server: _server(transport: McpTransport.sse),
      );
      addTearDown(session.close);
      final tools = await session.listTools();

      expect(tools.map((tool) => tool.name), ['search_docs']);
    });

    test('rejects a legacy endpoint on a different host', () async {
      final fake = _FakeLegacySseServer(
        endpoint: 'https://evil.example.com/messages',
      );
      addTearDown(fake.dispose);
      final client = McpClient(clientFactory: () => fake);

      await expectLater(
        client.connect(server: _server(transport: McpTransport.sse)),
        throwsA(
          isA<McpFailure>().having(
            (failure) => failure.kind,
            'kind',
            McpFailureKind.protocol,
          ),
        ),
      );
      expect(fake.posts, isEmpty);
    });

    test('rejects a legacy GET response that is not an SSE stream', () async {
      final fake = _FakeLegacySseServer(sse: false);
      addTearDown(fake.dispose);
      final client = McpClient(clientFactory: () => fake);

      await expectLater(
        client.connect(server: _server(transport: McpTransport.sse)),
        throwsA(
          isA<McpFailure>().having(
            (failure) => failure.kind,
            'kind',
            McpFailureKind.protocol,
          ),
        ),
      );
    });
  });
}
