import 'dart:convert';

import 'package:agentport/data/api/openai_compatible_client.dart';
import 'package:agentport/domain/entities/chat_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('chatCompletionsUri', () {
    test('adds /v1/chat/completions to a bare host', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUri(
          'https://api.deepseek.com',
        ).toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('keeps an existing /v1 prefix', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUri(
          'https://api.openai.com/v1',
        ).toString(),
        'https://api.openai.com/v1/chat/completions',
      );
    });

    test('accepts the full endpoint and trailing slashes', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUri(
          'https://example.com/v1/chat/completions/',
        ).toString(),
        'https://example.com/v1/chat/completions',
      );
    });

    test('preserves custom path prefixes', () {
      expect(
        OpenAiCompatibleClient.chatCompletionsUri(
          'https://proxy.example.com/openai/v1',
        ).toString(),
        'https://proxy.example.com/openai/v1/chat/completions',
      );
    });

    test('rejects invalid URLs', () {
      expect(
        () => OpenAiCompatibleClient.chatCompletionsUri('not a url'),
        throwsA(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.badRequest,
          ),
        ),
      );
      expect(
        () => OpenAiCompatibleClient.chatCompletionsUri('ftp://example.com'),
        throwsA(isA<ChatFailure>()),
      );
    });
  });

  group('streamChat', () {
    test('parses content, reasoning, and done markers', () async {
      final events = [
        'data: ${jsonEncode({'choices': [{'delta': {'reasoning_content': 'think'}}]})}\n\n',
        'data: ${jsonEncode({'choices': [{'delta': {'content': 'Hel'}}]})}\n\n',
        'data: ${jsonEncode({'choices': [{'delta': {'content': 'lo'}, 'finish_reason': 'stop'}]})}\n\n',
        'data: [DONE]\n\n',
      ];
      final client = OpenAiCompatibleClient(
        clientFactory: () => MockClient.streaming((request, bodyStream) async {
          expect(request.url.path, '/v1/chat/completions');
          expect(request.headers['Authorization'], 'Bearer secret');
          final body = await bodyStream.bytesToString();
          expect(jsonDecode(body), containsPair('stream', true));
          return http.StreamedResponse(
            Stream.fromIterable(events.map(utf8.encode)),
            200,
          );
        }),
      );

      final deltas = await client
          .streamChat(
            baseUrl: 'https://example.com',
            apiKey: 'secret',
            model: 'deepseek-chat',
            messages: const [
              ChatRequestMessage(role: 'user', content: 'Hi'),
            ],
          )
          .toList();

      expect(deltas.map((delta) => delta.reasoning).join(), 'think');
      expect(deltas.map((delta) => delta.content).join(), 'Hello');
      expect(deltas.last.finishReason, 'stop');
    });

    test('maps HTTP errors to chat failures', () async {
      final client = OpenAiCompatibleClient(
        clientFactory: () => MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'error': {'message': 'Invalid API key'},
                }),
              ),
            ),
            401,
          ),
        ),
      );

      expect(
        client.streamChat(
          baseUrl: 'https://example.com/v1',
          apiKey: 'bad',
          model: 'deepseek-chat',
          messages: const [],
        ),
        emitsError(
          isA<ChatFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ChatFailureKind.unauthorized,
              )
              .having(
                (failure) => failure.detail,
                'detail',
                'Invalid API key',
              ),
        ),
      );
    });

    test('maps malformed streams to invalid responses', () async {
      final client = OpenAiCompatibleClient(
        clientFactory: () => MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.value(utf8.encode('data: {oops}\n\n')),
            200,
          ),
        ),
      );

      expect(
        client.streamChat(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'model',
          messages: const [],
        ),
        emitsError(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('testConnection', () {
    test('succeeds on a 200 response', () async {
      final client = OpenAiCompatibleClient(
        clientFactory: () => MockClient((request) async {
          expect(request.url.path, '/v1/chat/completions');
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['stream'], false);
          return http.Response('{}', 200);
        }),
      );

      await client.testConnection(
        baseUrl: 'https://example.com',
        apiKey: 'key',
        model: 'model',
      );
    });

    test('throws a rate-limit failure on HTTP 429', () async {
      final client = OpenAiCompatibleClient(
        clientFactory: () => MockClient(
          (request) async => http.Response('slow down', 429),
        ),
      );

      expect(
        client.testConnection(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'model',
        ),
        throwsA(
          isA<ChatFailure>().having(
            (failure) => failure.kind,
            'kind',
            ChatFailureKind.rateLimited,
          ),
        ),
      );
    });
  });
}
