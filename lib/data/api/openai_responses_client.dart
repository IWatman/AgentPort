import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/chat_failure.dart';
import 'openai_compatible_client.dart';

class ResponsesModel {
  const ResponsesModel({required this.id, required this.label});

  final String id;
  final String label;
}

/// Stateless Responses transport for Sign in with ChatGPT plan usage.
/// See OpenAI's SIWC models-and-inference and preview-limitations guides.
class OpenAiResponsesClient {
  OpenAiResponsesClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;
  static const _namespace = 'agentport';

  Stream<ChatDelta> streamChat({
    required String accessToken,
    required String model,
    required List<ChatRequestMessage> messages,
    List<ChatToolDefinition> tools = const [],
  }) async* {
    final client = _clientFactory();
    try {
      final request =
          http.Request('POST', Uri.parse('https://api.openai.com/v1/responses'))
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode({
              'model': model,
              'input': _input(messages),
              'store': false,
              'stream': true,
              if (tools.isNotEmpty)
                'tools': [
                  {
                    'type': 'namespace',
                    'name': _namespace,
                    'description': 'Client-side AgentPort tools.',
                    'tools': [
                      for (final tool in tools)
                        {
                          'type': 'function',
                          'name': tool.name,
                          'description': tool.description,
                          'parameters': tool.parameters,
                          'strict': false,
                        },
                    ],
                  },
                ],
            });
      final response = await client.send(request).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpFailure(response.statusCode);
      }
      final state = _ResponseState(tools.map((tool) => tool.name).toSet());
      await for (final event in _events(response.stream)) {
        for (final delta in state.accept(event)) {
          yield delta;
        }
        if (state.completed) return;
      }
      throw const ChatFailure(
        ChatFailureKind.invalidResponse,
        detail: 'The response stream ended before completion.',
      );
    } on ChatFailure {
      rethrow;
    } on FormatException {
      throw _invalidResponse;
    } on TimeoutException {
      throw _networkFailure;
    } on SocketException {
      throw _networkFailure;
    } on http.ClientException {
      throw _networkFailure;
    } on Exception {
      throw const ChatFailure(ChatFailureKind.unknown);
    } finally {
      client.close();
    }
  }

  Future<List<ResponsesModel>> listModels({required String accessToken}) async {
    final client = _clientFactory();
    try {
      final request =
          http.Request('GET', Uri.parse('https://api.openai.com/v1/models'))
            ..followRedirects = false
            ..headers['Authorization'] = 'Bearer $accessToken';
      final response = await client.send(request).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpFailure(response.statusCode);
      }
      final decoded = jsonDecode(
        await response.stream.bytesToString().timeout(_requestTimeout),
      );
      if (decoded is! Map || decoded['models'] is! List) {
        throw _invalidResponse;
      }
      final result = <ResponsesModel>[];
      for (final entry in decoded['models'] as List) {
        if (entry is! Map || entry['visibility'] != 'list') continue;
        final id = entry['slug'];
        final label = entry['display_name'];
        if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
          throw _invalidResponse;
        }
        result.add(ResponsesModel(id: id, label: label));
      }
      return result;
    } on ChatFailure {
      rethrow;
    } on FormatException {
      throw _invalidResponse;
    } on TimeoutException {
      throw _networkFailure;
    } on SocketException {
      throw _networkFailure;
    } on http.ClientException {
      throw _networkFailure;
    } on Exception {
      throw const ChatFailure(ChatFailureKind.unknown);
    } finally {
      client.close();
    }
  }

  Future<void> testConnection({required String accessToken}) async {
    await listModels(accessToken: accessToken);
  }

  List<Map<String, Object?>> _input(List<ChatRequestMessage> messages) {
    final calls = <String, String>{};
    final input = <Map<String, Object?>>[];
    for (final message in messages) {
      if (message.role == 'tool') {
        final id = message.toolCallId;
        if (id == null || id.isEmpty || !calls.containsKey(id)) {
          throw const ChatFailure(
            ChatFailureKind.badRequest,
            detail: 'A tool result is missing its function call.',
          );
        }
        input.add({
          'type': 'function_call_output',
          'call_id': id,
          'name': calls[id],
          'namespace': _namespace,
          'output': message.content,
        });
        continue;
      }
      final role = message.role == 'system' ? 'developer' : message.role;
      if (!const {'developer', 'user', 'assistant'}.contains(role)) {
        throw const ChatFailure(ChatFailureKind.badRequest);
      }
      if (message.content.isNotEmpty ||
          message.contentParts.isNotEmpty ||
          message.toolCalls.isEmpty) {
        input.add({
          'role': role,
          'content': message.contentParts.isEmpty
              ? message.content
              : message.contentParts.map(_contentPart).toList(),
        });
      }
      for (final call in message.toolCalls) {
        calls[call.id] = call.name;
        input.add({
          'type': 'function_call',
          'call_id': call.id,
          'name': call.name,
          'namespace': _namespace,
          'arguments': call.arguments,
        });
      }
    }
    return input;
  }

  Map<String, Object?> _contentPart(Map<String, Object?> part) {
    if (part['type'] == 'text' && part['text'] is String) {
      return {'type': 'input_text', 'text': part['text']};
    }
    final image = part['image_url'];
    if (part['type'] == 'image_url' && image is Map && image['url'] is String) {
      return {
        'type': 'input_image',
        'image_url': image['url'],
        'detail': image['detail'] ?? 'auto',
      };
    }
    throw const ChatFailure(
      ChatFailureKind.badRequest,
      detail: 'Unsupported message content.',
    );
  }
}

const _requestTimeout = Duration(seconds: 45);
const _invalidResponse = ChatFailure(
  ChatFailureKind.invalidResponse,
  detail: 'OpenAI sent an invalid response.',
);
const _networkFailure = ChatFailure(
  ChatFailureKind.network,
  detail: 'The OpenAI connection was interrupted or timed out.',
);

// Never expose response bodies or transport exception messages: they may contain
// bearer credentials, request input, or other private diagnostic material.
ChatFailure _httpFailure(int status) => ChatFailure(switch (status) {
  401 || 403 => ChatFailureKind.unauthorized,
  402 => ChatFailureKind.insufficientBalance,
  429 => ChatFailureKind.rateLimited,
  >= 500 => ChatFailureKind.server,
  _ => ChatFailureKind.badRequest,
}, statusCode: status);

ChatFailure _eventFailure(Object? value) {
  final error = value is Map ? value : const {};
  // Only known codes are surfaced. Arbitrary provider messages are untrusted.
  return switch (error['code']) {
    'subscription_sharing_usage_limit_exceeded' || 'rate_limit_exceeded' =>
      const ChatFailure(ChatFailureKind.rateLimited, statusCode: 429),
    'insufficient_quota' => const ChatFailure(
      ChatFailureKind.insufficientBalance,
    ),
    'subscription_sharing_usage_unavailable' ||
    'subscription_sharing_user_unavailable' => const ChatFailure(
      ChatFailureKind.server,
      statusCode: 503,
    ),
    'subscription_sharing_invalid_user' || 'invalid_api_key' =>
      const ChatFailure(ChatFailureKind.unauthorized, statusCode: 401),
    'subscription_sharing_user_not_eligible' ||
    'subscription_sharing_route_not_supported' ||
    'chatpass_v2_scope_not_authorized' ||
    'chatpass_v2_invalid_authorization_context' => const ChatFailure(
      ChatFailureKind.unauthorized,
      statusCode: 403,
    ),
    'subscription_sharing_unsupported_capability' => const ChatFailure(
      ChatFailureKind.badRequest,
      statusCode: 400,
    ),
    _ => const ChatFailure(ChatFailureKind.server),
  };
}

Stream<Map<String, Object?>> _events(Stream<List<int>> bytes) async* {
  final data = <String>[];
  String? eventType;
  final lines = bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .timeout(const Duration(seconds: 90));
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        final payload = data.join('\n');
        data.clear();
        if (payload == '[DONE]') return;
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) throw _invalidResponse;
        yield {
          ...decoded,
          if (decoded['type'] == null && eventType != null) 'type': eventType,
        };
      }
      eventType = null;
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    } else if (line.startsWith('event:')) {
      eventType = line.substring(6).trim();
    }
  }
  // An unterminated SSE frame is not a trustworthy terminal event.
  if (data.isNotEmpty) throw _invalidResponse;
}

class _FunctionState {
  String? id;
  String? name;
  String snapshot = '';
  String emitted = '';
  bool announced = false;
}

class _ResponseState {
  _ResponseState(this.aliases);

  final Set<String> aliases;
  final functions = <int, _FunctionState>{};
  final text = <String, String>{};
  bool completed = false;

  Iterable<ChatDelta> accept(Map<String, Object?> event) sync* {
    final type = event['type'];
    final response = event['response'];
    if (type == 'error' || event['error'] != null) {
      throw _eventFailure(event['error'] ?? event);
    }
    if (type == 'response.failed') {
      throw _eventFailure(response is Map ? response['error'] : null);
    }
    if (type == 'response.incomplete') {
      throw const ChatFailure(
        ChatFailureKind.invalidResponse,
        detail: 'OpenAI could not complete the response.',
      );
    }
    if (type == 'response.completed') {
      if (response is Map) {
        if (response['error'] != null) throw _eventFailure(response['error']);
        final status = response['status'];
        if (status != null && status != 'completed') throw _invalidResponse;
        final output = response['output'];
        if (output is List) {
          for (var i = 0; i < output.length; i++) {
            final item = output[i];
            if (item is Map<String, Object?>) yield* _item(i, item, true);
          }
        }
      }
      for (final entry in functions.entries) {
        yield* _function(entry.key, entry.value, finish: true);
      }
      completed = true;
      yield ChatDelta(finishReason: functions.isEmpty ? 'stop' : 'tool_calls');
      return;
    }
    final index = event['output_index'];
    final outputIndex = index is int ? index : 0;
    if (type == 'response.output_item.added' ||
        type == 'response.output_item.done') {
      final item = event['item'];
      if (item is Map<String, Object?>) {
        yield* _item(outputIndex, item, type == 'response.output_item.done');
      }
    } else if (type == 'response.function_call_arguments.delta' ||
        type == 'response.function_call_arguments.done') {
      final state = functions.putIfAbsent(outputIndex, _FunctionState.new);
      if (type == 'response.function_call_arguments.delta') {
        final delta = event['delta'];
        if (delta is! String) throw _invalidResponse;
        state.emitted += delta;
        yield ChatDelta(
          toolCalls: [ChatToolCallDelta(index: outputIndex, arguments: delta)],
        );
      } else {
        if (event['arguments'] is String) {
          state.snapshot = event['arguments'] as String;
        }
        yield* _function(outputIndex, state, finish: true);
      }
    } else if (type is String &&
        const {
          'response.output_text.delta',
          'response.output_text.done',
          'response.refusal.delta',
          'response.refusal.done',
          'response.reasoning_summary_text.delta',
          'response.reasoning_summary_text.done',
          'response.reasoning_text.delta',
          'response.reasoning_text.done',
        }.contains(type)) {
      final reasoning = type.startsWith('response.reasoning');
      final key =
          '$outputIndex:${event['content_index'] ?? event['summary_index'] ?? 0}:${type.substring(0, type.lastIndexOf('.'))}';
      final done = type.endsWith('.done');
      final value =
          event[done
              ? (type.contains('refusal') ? 'refusal' : 'text')
              : 'delta'];
      if (value is! String) throw _invalidResponse;
      final previous = text[key] ?? '';
      final delta = done ? _suffix(previous, value) : value;
      text[key] = previous + delta;
      if (delta.isNotEmpty) {
        yield ChatDelta(
          content: reasoning ? '' : delta,
          reasoning: reasoning ? delta : '',
        );
      }
    }
  }

  Iterable<ChatDelta> _item(
    int index,
    Map<String, Object?> item,
    bool done,
  ) sync* {
    if (done && (item['type'] == 'message' || item['type'] == 'reasoning')) {
      final parts = item[item['type'] == 'message' ? 'content' : 'summary'];
      if (parts is List) {
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (part is! Map) continue;
          final kind = switch (part['type']) {
            'output_text' => 'output_text',
            'refusal' => 'refusal',
            'summary_text' => 'reasoning_summary_text',
            _ => null,
          };
          if (kind == null) continue;
          yield* accept({
            'type': 'response.$kind.done',
            'output_index': index,
            'content_index': i,
            if (kind == 'refusal')
              'refusal': part['refusal']
            else
              'text': part['text'],
          });
        }
      }
      return;
    }
    if (item['type'] != 'function_call') return;
    if (item['namespace'] != null && item['namespace'] != 'agentport') {
      throw _invalidResponse;
    }
    final state = functions.putIfAbsent(index, _FunctionState.new);
    if (item['call_id'] is String) state.id = item['call_id'] as String;
    final name = item['name'];
    if (name is String) {
      state.name = aliases.contains(name)
          ? name
          : name.startsWith('agentport.') &&
                aliases.contains(name.substring(10))
          ? name.substring(10)
          : name;
    }
    if (item['arguments'] is String) {
      state.snapshot = item['arguments'] as String;
    }
    yield* _function(index, state, finish: done);
  }

  Iterable<ChatDelta> _function(
    int index,
    _FunctionState state, {
    required bool finish,
  }) sync* {
    if (!state.announced && state.id != null && state.name != null) {
      state.announced = true;
      yield ChatDelta(
        toolCalls: [
          ChatToolCallDelta(index: index, id: state.id, name: state.name),
        ],
      );
    }
    if (finish) {
      if (!state.announced) throw _invalidResponse;
      if (state.snapshot.isNotEmpty) {
        final suffix = _suffix(state.emitted, state.snapshot);
        state.emitted = state.snapshot;
        if (suffix.isNotEmpty) {
          yield ChatDelta(
            toolCalls: [ChatToolCallDelta(index: index, arguments: suffix)],
          );
        }
      }
    }
  }

  String _suffix(String previous, String full) {
    if (!full.startsWith(previous)) throw _invalidResponse;
    return full.substring(previous.length);
  }
}

final openAiResponsesClientProvider = Provider<OpenAiResponsesClient>((ref) {
  return OpenAiResponsesClient();
});
