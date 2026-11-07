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

    test('rejects SSE-only transport for now', () async {
      final client = McpClient(clientFactory: _FakeMcpServer().client);

      await expectLater(
        client.connect(server: _server(transport: McpTransport.sse)),
        throwsA(
          isA<McpFailure>().having(
            (failure) => failure.kind,
            'kind',
            McpFailureKind.unsupportedTransport,
          ),
        ),
      );
    });
  });
}
