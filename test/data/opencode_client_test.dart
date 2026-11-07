import 'dart:convert';

import 'package:agentport/data/opencode/opencode_auth.dart';
import 'package:agentport/data/opencode/opencode_client.dart';
import 'package:agentport/domain/entities/opencode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int statusCode = 200]) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('OpenCodeAuth', () {
    test('redeems a code and sends the JSON accept header', () async {
      final seen = <http.Request>[];
      final auth = OpenCodeAuth(
        clientFactory: () => MockClient((request) async {
          seen.add(request);
          return _json({'token': 'secret-token'});
        }),
      );

      final token = await auth.redeem(
        baseUrl: 'https://example.com/opencode',
        code: 'abc123',
      );

      expect(token, 'secret-token');
      expect(seen, hasLength(1));
      expect(
        seen.single.url.toString(),
        'https://example.com/opencode/auth/connect/abc123',
      );
      expect(seen.single.method, 'GET');
      expect(seen.single.headers['Accept'], 'application/json');
    });

    test('maps 401 and 404 to an authorization failure', () async {
      for (final status in [401, 404]) {
        final auth = OpenCodeAuth(
          clientFactory: () =>
              MockClient((request) async => http.Response('no', status)),
        );

        await expectLater(
          auth.redeem(baseUrl: 'https://example.com', code: 'abc'),
          throwsA(
            isA<OpenCodeFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  OpenCodeFailureKind.unauthorized,
                )
                .having((failure) => failure.statusCode, 'statusCode', status),
          ),
        );
      }
    });

    test('maps a missing token to an invalid response', () async {
      final auth = OpenCodeAuth(
        clientFactory: () => MockClient((request) async => _json({'ok': true})),
      );

      await expectLater(
        auth.redeem(baseUrl: 'https://example.com', code: 'abc'),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects malformed JSON', () async {
      final auth = OpenCodeAuth(
        clientFactory: () =>
            MockClient((request) async => http.Response('{nope', 200)),
      );

      await expectLater(
        auth.redeem(baseUrl: 'https://example.com', code: 'abc'),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('OpenCodeClient requests', () {
    test('uses Basic auth and checks the server version', () async {
      final seen = <http.Request>[];
      final client = OpenCodeClient(
        baseUrl: 'https://example.com/opencode',
        token: 'token-1',
        clientFactory: () => MockClient((request) async {
          seen.add(request);
          return _json({
            'version': '2.2.5',
            'urls': ['https://example.com'],
            'capabilities': {'streaming': true},
          });
        }),
      );

      final info = await client.info();

      expect(info.version, '2.2.5');
      expect(info.urls, ['https://example.com']);
      expect(info.capabilities['streaming'], isTrue);
      expect(
        seen.single.url.toString(),
        'https://example.com/opencode/api/info',
      );
      expect(
        seen.single.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('opencode:token-1'))}',
      );
      expect(seen.single.headers['Accept'], 'application/json');
    });

    test('rejects servers older than 2.2.5', () async {
      final client = OpenCodeClient(
        baseUrl: 'http://host:4096',
        token: 't',
        clientFactory: () =>
            MockClient((request) async => _json({'version': '2.2.4'})),
      );

      await expectLater(
        client.info(),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.unsupportedVersion,
          ),
        ),
      );
    });

    test('accepts semantically newer versions', () {
      expect(OpenCodeClient.isVersionSupported('2.2.5'), isTrue);
      expect(OpenCodeClient.isVersionSupported('v2.10.0'), isTrue);
      expect(OpenCodeClient.isVersionSupported('3.0.0-beta.1'), isTrue);
      expect(OpenCodeClient.isVersionSupported('2.2.4'), isFalse);
      expect(OpenCodeClient.isVersionSupported('2.1.99'), isFalse);
      expect(OpenCodeClient.isVersionSupported('not a version'), isFalse);
    });

    test('lists sessions', () async {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () => MockClient(
          (request) async => _json([
            {
              'id': 'ses_1',
              'title': 'Fix the build',
              'project': 'agentport',
              'updatedAt': '2026-11-08T08:00:00Z',
            },
            {'id': 'ses_2', 'title': ''},
          ]),
        ),
      );

      final sessions = await client.sessions();

      expect(sessions, hasLength(2));
      expect(sessions.first.id, 'ses_1');
      expect(sessions.first.title, 'Fix the build');
      expect(sessions.first.project, 'agentport');
      expect(sessions.first.updatedAt, DateTime.utc(2026, 11, 8, 8));
      expect(sessions[1].title, 'Untitled session');
    });

    test('parses a wrapped session list and session details', () async {
      final paths = <String>[];
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () => MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/api/session')) {
            return _json({
              'sessions': [
                {'id': 'ses_1', 'title': 'One'},
              ],
            });
          }
          return _json({
            'session': {
              'id': 'ses_1',
              'title': 'One',
              'time': {'updated': 1762584000000},
            },
          });
        }),
      );

      final sessions = await client.sessions();
      final session = await client.session('ses_1');

      expect(sessions.single.id, 'ses_1');
      expect(session.id, 'ses_1');
      expect(session.updatedAt, isNotNull);
      expect(paths, ['/api/session', '/api/session/ses_1']);
    });

    test('sends prompts with agent and model', () async {
      final seen = <http.Request>[];
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () => MockClient((request) async {
          seen.add(request);
          return http.Response('', 204);
        }),
      );

      await client.sendPrompt(
        'ses_1',
        'Hello',
        agent: 'build',
        model: 'deepseek/deepseek-chat',
      );

      final request = seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/session/ses_1/prompt');
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), {
        'prompt': 'Hello',
        'agent': 'build',
        'model': 'deepseek/deepseek-chat',
      });
    });

    test('sends interrupt, agent, and model requests', () async {
      final seen = <http.Request>[];
      final client = OpenCodeClient(
        baseUrl: 'https://example.com/opencode',
        token: 't',
        clientFactory: () => MockClient((request) async {
          seen.add(request);
          return http.Response('', 204);
        }),
      );

      await client.interrupt('ses_1');
      await client.setAgent('ses_1', 'plan');
      await client.setModel('ses_1', 'anthropic/claude');

      expect(seen.map((request) => request.url.path), [
        '/opencode/api/session/ses_1/interrupt',
        '/opencode/api/session/ses_1/agent',
        '/opencode/api/session/ses_1/model',
      ]);
      expect(jsonDecode(seen[1].body), {'agent': 'plan'});
      expect(jsonDecode(seen[2].body), {'model': 'anthropic/claude'});
    });

    test('maps 401 to an authorization failure', () async {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () =>
            MockClient((request) async => http.Response('denied', 401)),
      );

      await expectLater(
        client.sessions(),
        throwsA(
          isA<OpenCodeFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                OpenCodeFailureKind.unauthorized,
              )
              .having((failure) => failure.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('maps malformed JSON to an invalid response', () async {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () =>
            MockClient((request) async => http.Response('{nope', 200)),
      );

      await expectLater(
        client.sessions(),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects an invalid base URL', () {
      expect(
        () => OpenCodeClient(baseUrl: 'not a url', token: 't'),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidPayload,
          ),
        ),
      );
    });
  });

  group('OpenCodeClient events', () {
    test('parses SSE frames, multi-line data, and comments', () async {
      const body =
          ': keep-alive\n\n'
          'data:\n\n'
          'event: session.updated\n'
          'id: evt-1\n'
          'data: {"type":"session.updated","properties":{"id":"ses_1"}}\n'
          '\n'
          'id: 2\n'
          'data: {"type":"message.part",\n'
          'data: "text":"hi"}\n'
          '\n';

      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () => MockClient(
          (request) async => http.Response(
            body,
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );

      final events = await client.events().toList();

      expect(events, hasLength(2));
      expect(events.first.id, 'evt-1');
      expect(events.first.type, 'session.updated');
      expect(events.first.data['properties'], {'id': 'ses_1'});
      expect(events[1].id, '2');
      expect(events[1].type, 'message.part');
      expect(events[1].data['text'], 'hi');
    });

    test('sends Basic auth and the event-stream accept header', () async {
      http.Request? seen;
      final client = OpenCodeClient(
        baseUrl: 'https://example.com/opencode',
        token: 'token-1',
        clientFactory: () => MockClient((request) async {
          seen = request;
          return http.Response(
            'data: {"type":"server.connected"}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final events = await client.events().toList();

      expect(events.single.type, 'server.connected');
      expect(seen!.url.toString(), 'https://example.com/opencode/api/event');
      expect(seen!.headers['Accept'], 'text/event-stream');
      expect(
        seen!.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('opencode:token-1'))}',
      );
    });

    test('maps event-stream HTTP errors', () async {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () =>
            MockClient((request) async => http.Response('denied', 401)),
      );

      await expectLater(
        client.events().toList(),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.unauthorized,
          ),
        ),
      );
    });

    test('rejects malformed event JSON', () async {
      final client = OpenCodeClient(
        baseUrl: 'https://example.com',
        token: 't',
        clientFactory: () => MockClient(
          (request) async => http.Response(
            'data: {nope}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );

      await expectLater(
        client.events().toList(),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });
}
