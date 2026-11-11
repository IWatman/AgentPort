import 'dart:async';
import 'dart:convert';

import 'package:agentport/data/api/openai_compatible_client.dart';
import 'package:agentport/data/api/openai_responses_client.dart';
import 'package:agentport/domain/entities/chat_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String frame(Map<String, Object?> event) => 'data: ${jsonEncode(event)}\n\n';
const completed = {'type': 'response.completed'};
const tool = ChatToolDefinition(
  name: 'mcp__server__search',
  description: 'Search',
  parameters: {'type': 'object', 'properties': {}},
);

OpenAiResponsesClient streaming(
  List<Map<String, Object?>> events, {
  void Function(http.BaseRequest, Map<String, Object?>)? inspect,
}) => OpenAiResponsesClient(
  clientFactory: () => MockClient.streaming((request, body) async {
    inspect?.call(
      request,
      jsonDecode(await body.bytesToString()) as Map<String, Object?>,
    );
    final encoded = utf8.encode(': heartbeat\n\n${events.map(frame).join()}');
    // Exercise byte boundaries inside UTF-8 and SSE frames.
    return http.StreamedResponse(
      Stream.fromIterable(encoded.map((byte) => [byte])),
      200,
    );
  }),
);

Stream<ChatDelta> chat(
  OpenAiResponsesClient client, {
  List<ChatRequestMessage> messages = const [],
  List<ChatToolDefinition> tools = const [],
}) => client.streamChat(
  accessToken: 'private-token',
  model: 'account-model',
  messages: messages,
  tools: tools,
);

TypeMatcher<ChatFailure> failure(ChatFailureKind kind) =>
    isA<ChatFailure>().having((value) => value.kind, 'kind', kind);

void main() {
  test(
    'final snapshots supply reasoning and function arguments once',
    () async {
      final deltas = await chat(
        streaming([
          {
            'type': 'response.reasoning_summary_text.delta',
            'output_index': 0,
            'summary_index': 0,
            'delta': 'Reason',
          },
          {
            'type': 'response.output_item.added',
            'output_index': 1,
            'item': {
              'type': 'function_call',
              'call_id': 'call',
              'name': tool.name,
              'namespace': 'agentport',
              'arguments': '{}',
            },
          },
          {
            'type': 'response.completed',
            'response': {
              'status': 'completed',
              'output': [
                {
                  'type': 'reasoning',
                  'summary': [
                    {'type': 'summary_text', 'text': 'Reason'},
                  ],
                },
                {
                  'type': 'function_call',
                  'call_id': 'call',
                  'name': tool.name,
                  'namespace': 'agentport',
                  'arguments': '{}',
                },
              ],
            },
          },
        ]),
      ).toList();
      expect(deltas.map((delta) => delta.reasoning).join(), 'Reason');
      final calls = deltas.expand((delta) => delta.toolCalls);
      expect(calls.map((call) => call.arguments ?? '').join(), '{}');
      expect(calls.where((call) => call.name != null), hasLength(1));
    },
  );

  test('terminal failure metadata cannot masquerade as completion', () async {
    for (final response in [
      {'status': 'incomplete'},
      {
        'status': 'completed',
        'error': {'code': 'server_error', 'message': 'private-token'},
      },
    ]) {
      final received = <ChatDelta>[];
      Object? caught;
      try {
        await for (final delta in chat(
          streaming([
            {'type': 'response.completed', 'response': response},
          ]),
        )) {
          received.add(delta);
        }
      } catch (error) {
        caught = error;
      }
      expect(caught, isA<ChatFailure>());
      expect(caught.toString(), isNot(contains('private-token')));
      expect(received, isEmpty);
    }
  });

  test('rejects unsupported content and orphan tool results locally', () async {
    var sent = false;
    final client = OpenAiResponsesClient(
      clientFactory: () => MockClient((request) async {
        sent = true;
        return http.Response('', 200);
      }),
    );
    for (final message in const [
      ChatRequestMessage(role: 'tool', content: 'result', toolCallId: 'orphan'),
      ChatRequestMessage(
        role: 'user',
        content: '',
        contentParts: [
          {'type': 'input_audio', 'data': 'private-token'},
        ],
      ),
    ]) {
      await expectLater(
        chat(client, messages: [message]).toList(),
        throwsA(failure(ChatFailureKind.badRequest)),
      );
    }
    expect(sent, false);
  });

  test(
    'stream transport failures after partial text remain failures',
    () async {
      final client = OpenAiResponsesClient(
        clientFactory: () => MockClient.streaming(
          (request, body) async => http.StreamedResponse(
            (() async* {
              yield utf8.encode(
                frame({
                  'type': 'response.output_text.delta',
                  'delta': 'partial',
                }),
              );
              throw http.ClientException('private-token');
            })(),
            200,
          ),
        ),
      );
      await expectLater(
        chat(client),
        emitsInOrder([
          isA<ChatDelta>().having(
            (delta) => delta.content,
            'content',
            'partial',
          ),
          emitsError(failure(ChatFailureKind.network)),
          emitsDone,
        ]),
      );
    },
  );

  test(
    'uses fixed endpoint, developer instructions and minimal stateless body',
    () async {
      final client = streaming(
        [
          {
            'type': 'response.reasoning_summary_text.delta',
            'output_index': 0,
            'summary_index': 0,
            'delta': 'Think',
          },
          {
            'type': 'response.reasoning_summary_text.done',
            'output_index': 0,
            'summary_index': 0,
            'text': 'Think',
          },
          {
            'type': 'response.output_text.delta',
            'output_index': 1,
            'delta': 'Привет',
          },
          {
            'type': 'response.output_text.done',
            'output_index': 1,
            'text': 'Привет!',
          },
          completed,
        ],
        inspect: (request, body) {
          expect(request.url.toString(), 'https://api.openai.com/v1/responses');
          expect(request.followRedirects, false);
          expect(request.headers['Authorization'], 'Bearer private-token');
          expect(body.keys.toSet(), {'model', 'input', 'store', 'stream'});
          expect(body['store'], false);
          expect(body['stream'], true);
          expect(body['input'], [
            {'role': 'developer', 'content': 'Rules'},
            {'role': 'user', 'content': 'Hi'},
          ]);
        },
      );
      final deltas = await chat(
        client,
        messages: const [
          ChatRequestMessage(role: 'system', content: 'Rules'),
          ChatRequestMessage(role: 'user', content: 'Hi'),
        ],
      ).toList();
      expect(deltas.map((delta) => delta.content).join(), 'Привет!');
      expect(deltas.map((delta) => delta.reasoning).join(), 'Think');
      expect(deltas.where((delta) => delta.finishReason != null), hasLength(1));
      expect(deltas.last.finishReason, 'stop');
    },
  );

  test(
    'handles multiple text parts and final output without repeating deltas',
    () async {
      final deltas = await chat(
        streaming([
          {
            'type': 'response.output_text.delta',
            'output_index': 0,
            'content_index': 0,
            'delta': 'one',
          },
          {
            'type': 'response.completed',
            'response': {
              'status': 'completed',
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': 'one'},
                    {'type': 'output_text', 'text': 'two'},
                  ],
                },
              ],
            },
          },
        ]),
      ).toList();
      expect(deltas.map((delta) => delta.content).join(), 'onetwo');
    },
  );

  for (final terminal in [
    {
      'type': 'response.failed',
      'response': {
        'error': {
          'code': 'subscription_sharing_usage_limit_exceeded',
          'message': 'private-token secret',
        },
      },
    },
    {
      'type': 'error',
      'code': 'subscription_sharing_usage_limit_exceeded',
      'message': 'private-token',
    },
  ]) {
    test(
      'post-delta ${terminal['type']} never completes and hides diagnostics',
      () async {
        final received = <ChatDelta>[];
        Object? caught;
        try {
          await for (final delta in chat(
            streaming([
              {'type': 'response.output_text.delta', 'delta': 'partial'},
              terminal,
            ]),
          )) {
            received.add(delta);
          }
        } catch (error) {
          caught = error;
        }
        expect(caught, failure(ChatFailureKind.rateLimited));
        expect(caught.toString(), isNot(contains('private-token')));
        expect(received.single.content, 'partial');
        expect(received.single.finishReason, isNull);
      },
    );
  }

  test('incomplete, malformed and truncated streams fail', () async {
    for (final events in <List<Map<String, Object?>>>[
      [],
      [
        {'type': 'response.output_text.delta', 'delta': 'partial'},
      ],
      [
        {
          'type': 'response.incomplete',
          'response': {
            'incomplete_details': {'reason': 'max_output_tokens'},
          },
        },
      ],
    ]) {
      await expectLater(
        chat(streaming(events)).toList(),
        throwsA(failure(ChatFailureKind.invalidResponse)),
      );
    }
    for (final payload in [
      'data: {broken}\n\n',
      'data: [DONE]\n\n',
      'data: {"type":"response.completed"}',
    ]) {
      final client = OpenAiResponsesClient(
        clientFactory: () => MockClient.streaming(
          (request, body) async =>
              http.StreamedResponse(Stream.value(utf8.encode(payload)), 200),
        ),
      );
      await expectLater(
        chat(client).toList(),
        throwsA(failure(ChatFailureKind.invalidResponse)),
      );
    }
  });

  test('supports SSE event names and multiline data', () async {
    final client = OpenAiResponsesClient(
      clientFactory: () => MockClient.streaming(
        (request, body) async => http.StreamedResponse(
          Stream.value(
            utf8.encode(
              'event: response.output_text.delta\r\ndata: {\r\ndata: "delta":"hi"}\r\n\r\nevent: response.completed\r\ndata: {}\r\n\r\n',
            ),
          ),
          200,
        ),
      ),
    );
    final deltas = await chat(client).toList();
    expect(deltas.first.content, 'hi');
    expect(deltas.last.finishReason, 'stop');
  });

  test(
    'namespaces tools, replays qualified calls and converts multimodal input',
    () async {
      final client = streaming(
        [completed],
        inspect: (request, body) {
          final namespaces = body['tools'] as List;
          expect(namespaces.single['type'], 'namespace');
          expect(namespaces.single['name'], 'agentport');
          expect(namespaces.single['tools'], [
            {
              'type': 'function',
              'name': tool.name,
              'description': 'Search',
              'parameters': tool.parameters,
              'strict': false,
            },
          ]);
          expect(body['input'], [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'Look'},
                {
                  'type': 'input_image',
                  'image_url': 'data:image/png;base64,YQ==',
                  'detail': 'high',
                },
              ],
            },
            {
              'type': 'function_call',
              'call_id': 'call-1',
              'name': tool.name,
              'namespace': 'agentport',
              'arguments': '{}',
            },
            {
              'type': 'function_call_output',
              'call_id': 'call-1',
              'name': tool.name,
              'namespace': 'agentport',
              'output': 'result',
            },
          ]);
        },
      );
      await chat(
        client,
        tools: const [tool],
        messages: const [
          ChatRequestMessage(
            role: 'user',
            content: 'ignored',
            contentParts: [
              {'type': 'text', 'text': 'Look'},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,YQ==',
                  'detail': 'high',
                },
              },
            ],
          ),
          ChatRequestMessage(
            role: 'assistant',
            content: '',
            toolCalls: [
              ChatToolCall(
                id: 'call-1',
                name: 'mcp__server__search',
                arguments: '{}',
              ),
            ],
          ),
          ChatRequestMessage(
            role: 'tool',
            content: 'result',
            toolCallId: 'call-1',
          ),
        ],
      ).toList();
    },
  );

  for (final initialArguments in ['', '{"q":"x"}']) {
    test(
      'deduplicates initial snapshot $initialArguments and multipart function deltas',
      () async {
        Map<String, Object?> item(int index, String arguments) => {
          'type': 'function_call',
          'id': 'fc-$index',
          'call_id': 'call-$index',
          'namespace': 'agentport',
          'name': index == 1 ? tool.name : 'agentport.${tool.name}',
          'arguments': arguments,
        };
        final deltas = await chat(
          streaming([
            {
              'type': 'response.output_item.added',
              'output_index': 1,
              'item': item(1, initialArguments),
            },
            {
              'type': 'response.output_item.added',
              'output_index': 3,
              'item': item(3, '{}'),
            },
            {
              'type': 'response.function_call_arguments.delta',
              'output_index': 1,
              'delta': '{"q":',
            },
            {
              'type': 'response.function_call_arguments.delta',
              'output_index': 1,
              'delta': '"x"}',
            },
            {
              'type': 'response.function_call_arguments.done',
              'output_index': 1,
              'arguments': '{"q":"x"}',
            },
            {
              'type': 'response.output_item.done',
              'output_index': 1,
              'item': item(1, '{"q":"x"}'),
            },
            {
              'type': 'response.output_item.done',
              'output_index': 3,
              'item': item(3, '{}'),
            },
            completed,
          ]),
          tools: const [tool],
        ).toList();
        final calls = deltas.expand((delta) => delta.toolCalls).toList();
        expect(
          calls
              .where((call) => call.index == 1)
              .map((call) => call.arguments ?? '')
              .join(),
          '{"q":"x"}',
        );
        expect(
          calls
              .where((call) => call.index == 3)
              .map((call) => call.arguments ?? '')
              .join(),
          '{}',
        );
        expect(
          calls.where((call) => call.name != null).map((call) => call.name),
          [tool.name, tool.name],
        );
        expect(calls.where((call) => call.id != null).map((call) => call.id), [
          'call-1',
          'call-3',
        ]);
        expect(deltas.last.finishReason, 'tool_calls');
      },
    );
  }

  test('rejects mismatched final function arguments', () async {
    await expectLater(
      chat(
        streaming([
          {
            'type': 'response.output_item.added',
            'output_index': 0,
            'item': {
              'type': 'function_call',
              'call_id': 'c',
              'name': tool.name,
              'arguments': '',
            },
          },
          {
            'type': 'response.function_call_arguments.delta',
            'output_index': 0,
            'delta': '{"x":',
          },
          {
            'type': 'response.function_call_arguments.done',
            'output_index': 0,
            'arguments': '{"y":1}',
          },
        ]),
      ).toList(),
      throwsA(failure(ChatFailureKind.invalidResponse)),
    );
  });

  test('models uses SIWC visibility and preserves server ordering', () async {
    final client = OpenAiResponsesClient(
      clientFactory: () => MockClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/models');
        expect(request.followRedirects, false);
        expect(request.headers['Authorization'], 'Bearer private-token');
        return http.Response(
          jsonEncode({
            'models': [
              {'slug': 'z', 'display_name': 'Z model', 'visibility': 'list'},
              {
                'slug': 'hidden',
                'display_name': 'Hidden',
                'visibility': 'hidden',
              },
              {'slug': 'a', 'display_name': 'A model', 'visibility': 'list'},
            ],
          }),
          200,
        );
      }),
    );
    final models = await client.listModels(accessToken: 'private-token');
    expect(models.map((model) => model.id), ['z', 'a']);
    expect(models.map((model) => model.label), ['Z model', 'A model']);
  });

  test(
    'rejects malformed model catalogs rather than guessing the API-key shape',
    () async {
      for (final body in [
        '{"data":[]}',
        '{broken}',
        '{"models":[{"visibility":"list","slug":"x"}]}',
      ]) {
        final client = OpenAiResponsesClient(
          clientFactory: () =>
              MockClient((request) async => http.Response(body, 200)),
        );
        await expectLater(
          client.listModels(accessToken: 'private-token'),
          throwsA(failure(ChatFailureKind.invalidResponse)),
        );
      }
    },
  );

  test(
    'maps HTTP failures without leaking bodies or following redirects',
    () async {
      for (final entry in {
        401: ChatFailureKind.unauthorized,
        403: ChatFailureKind.unauthorized,
        429: ChatFailureKind.rateLimited,
        503: ChatFailureKind.server,
        400: ChatFailureKind.badRequest,
        302: ChatFailureKind.badRequest,
      }.entries) {
        final client = OpenAiResponsesClient(
          clientFactory: () => MockClient(
            (request) async =>
                http.Response('private-token raw request', entry.key),
          ),
        );
        await expectLater(
          chat(client).toList(),
          throwsA(
            failure(entry.value)
                .having((value) => value.statusCode, 'status', entry.key),
          ),
        );
        try {
          await client.listModels(accessToken: 'private-token');
        } catch (error) {
          expect(error.toString(), isNot(contains('private-token')));
        }
      }
    },
  );

  test('transport exceptions are sanitized', () async {
    final client = OpenAiResponsesClient(
      clientFactory: () => MockClient(
        (request) async =>
            throw http.ClientException('private-token raw request'),
      ),
    );
    await expectLater(
      chat(client).toList(),
      throwsA(failure(ChatFailureKind.network)),
    );
    try {
      await client.listModels(accessToken: 'private-token');
    } catch (error) {
      expect(error.toString(), isNot(contains('private-token')));
    }
  });

  test(
    'canceling a subscription closes its HTTP client and response stream',
    () async {
      final canceled = Completer<void>();
      final bytes = StreamController<List<int>>(
        onCancel: () {
          canceled.complete();
        },
      );
      final transport = _TrackingClient(bytes.stream);
      final client = OpenAiResponsesClient(clientFactory: () => transport);
      final first = chat(client).take(1).toList();
      bytes.add(
        utf8.encode(
          frame({'type': 'response.output_text.delta', 'delta': 'first'}),
        ),
      );
      expect((await first).single.content, 'first');
      await canceled.future.timeout(const Duration(seconds: 2));
      expect(transport.closed, true);
      await bytes.close();
    },
  );
}

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.bytes);
  final Stream<List<int>> bytes;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(bytes, 200);

  @override
  void close() {
    closed = true;
  }
}
