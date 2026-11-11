import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/chat_failure.dart';

class ChatRequestMessage {
  const ChatRequestMessage({
    required this.role,
    required this.content,
    this.contentParts = const [],
    this.toolCallId,
    this.toolCalls = const [],
  });

  final String role;
  final String content;

  /// Multimodal content parts (for example text + image_url). When non-empty,
  /// these replace the plain string content.
  final List<Map<String, Object?>> contentParts;

  /// Set for role `tool` messages.
  final String? toolCallId;

  /// Set for assistant messages that requested tools.
  final List<ChatToolCall> toolCalls;

  Map<String, Object?> toJson() {
    if (toolCallId != null) {
      return {'role': role, 'tool_call_id': toolCallId, 'content': content};
    }
    return {
      'role': role,
      if (toolCalls.isEmpty)
        'content': contentParts.isEmpty ? content : contentParts,
      if (toolCalls.isNotEmpty) 'content': content.isEmpty ? null : content,
      if (toolCalls.isNotEmpty)
        'tool_calls': toolCalls.map((call) => call.toJson()).toList(),
    };
  }
}

class ChatToolDefinition {
  const ChatToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class ChatToolCall {
  const ChatToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;

  /// Raw JSON string emitted by the model.
  final String arguments;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'function',
    'function': {'name': name, 'arguments': arguments},
  };
}

class ChatToolCallDelta {
  const ChatToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });

  final int index;
  final String? id;
  final String? name;
  final String? arguments;
}

class ChatDelta {
  const ChatDelta({
    this.content = '',
    this.reasoning = '',
    this.finishReason,
    this.toolCalls = const [],
  });

  final String content;
  final String reasoning;
  final String? finishReason;
  final List<ChatToolCallDelta> toolCalls;

  bool get isEmpty => content.isEmpty && reasoning.isEmpty && toolCalls.isEmpty;
}

typedef HttpClientFactory = http.Client Function();

/// Minimal OpenAI-compatible chat-completions client.
///
/// Only the streaming endpoint is used by the app; [testConnection] performs a
/// tiny non-streaming request to validate credentials.
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({HttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final HttpClientFactory _clientFactory;

  Stream<ChatDelta> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatRequestMessage> messages,
    List<ChatToolDefinition> tools = const [],
    bool allowRedirects = true,
  }) async* {
    final client = _clientFactory();
    try {
      final request = http.Request('POST', chatCompletionsUri(baseUrl))
        ..followRedirects = allowRedirects
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'model': model,
          'messages': messages.map((message) => message.toJson()).toList(),
          'stream': true,
          if (tools.isNotEmpty)
            'tools': tools.map((tool) => tool.toJson()).toList(),
          if (tools.isNotEmpty) 'tool_choice': 'auto',
        });

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw _failureFor(response.statusCode, body);
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 90));

      await for (final line in lines) {
        if (line.isEmpty || line.startsWith(':')) {
          continue;
        }
        if (!line.startsWith('data:')) {
          continue;
        }
        final payload = line.substring(5).trim();
        if (payload.isEmpty) {
          continue;
        }
        if (payload == '[DONE]') {
          yield const ChatDelta(finishReason: 'stop');
          break;
        }

        final Object? decoded;
        try {
          decoded = jsonDecode(payload);
        } on FormatException {
          throw const ChatFailure(
            ChatFailureKind.invalidResponse,
            detail: 'The server sent malformed streaming data.',
          );
        }
        if (decoded is! Map<String, Object?>) {
          continue;
        }

        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          throw ChatFailure(
            ChatFailureKind.server,
            detail: error['message']?.toString(),
          );
        }

        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) {
          continue;
        }
        final choice = choices.first;
        if (choice is! Map<String, Object?>) {
          continue;
        }
        final delta = choice['delta'];
        final deltaMap = delta is Map<String, Object?> ? delta : const {};
        final content = _readString(deltaMap['content']);
        final reasoning =
            _readString(deltaMap['reasoning_content']) ??
            _readString(deltaMap['reasoning']) ??
            '';

        yield ChatDelta(
          content: content ?? '',
          reasoning: reasoning,
          finishReason: choice['finish_reason']?.toString(),
          toolCalls: _readToolCalls(deltaMap['tool_calls']),
        );
      }
    } on ChatFailure {
      rethrow;
    } on TimeoutException {
      throw const ChatFailure(
        ChatFailureKind.network,
        detail: 'The provider took too long to respond.',
      );
    } on SocketException catch (error) {
      throw ChatFailure(ChatFailureKind.network, detail: error.message);
    } on http.ClientException catch (error) {
      throw ChatFailure(ChatFailureKind.network, detail: error.message);
    } finally {
      client.close();
    }
  }

  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
    bool allowRedirects = true,
  }) async {
    final client = _clientFactory();
    try {
      final request = http.Request('GET', modelsUri(baseUrl))
        ..followRedirects = allowRedirects
        ..headers['Authorization'] = 'Bearer $apiKey';
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failureFor(response.statusCode, response.body);
      }
    } on ChatFailure {
      rethrow;
    } on TimeoutException {
      throw const ChatFailure(
        ChatFailureKind.network,
        detail: 'The provider took too long to respond.',
      );
    } on SocketException catch (error) {
      throw ChatFailure(ChatFailureKind.network, detail: error.message);
    } on http.ClientException catch (error) {
      throw ChatFailure(ChatFailureKind.network, detail: error.message);
    } finally {
      client.close();
    }
  }

  /// Turns a user-supplied base URL into the models endpoint.
  static Uri modelsUri(String baseUrl) {
    final chat = chatCompletionsUri(baseUrl);
    final path = chat.path.replaceFirst(
      RegExp(r'/chat/completions$'),
      '/models',
    );
    return chat.replace(path: path);
  }

  /// Turns a user-supplied base URL into a chat-completions endpoint.
  ///
  /// Accepts a host (`https://api.deepseek.com`), a versioned base
  /// (`https://api.openai.com/v1`), or the full endpoint.
  static Uri chatCompletionsUri(String baseUrl) {
    final trimmed = baseUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw const ChatFailure(
        ChatFailureKind.badRequest,
        detail: 'Enter a valid base URL, for example https://api.deepseek.com',
      );
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      throw const ChatFailure(
        ChatFailureKind.badRequest,
        detail: 'The base URL must use http or https.',
      );
    }

    var path = parsed.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    if (path.endsWith('/chat/completions')) {
      return parsed.replace(path: path);
    }
    if (path.endsWith('/v1')) {
      return parsed.replace(path: '$path/chat/completions');
    }
    if (path.isEmpty) {
      return parsed.replace(path: '/v1/chat/completions');
    }
    return parsed.replace(path: '$path/chat/completions');
  }

  ChatFailure _failureFor(int statusCode, String body) {
    final kind = switch (statusCode) {
      401 || 403 => ChatFailureKind.unauthorized,
      402 => ChatFailureKind.insufficientBalance,
      429 => ChatFailureKind.rateLimited,
      >= 500 => ChatFailureKind.server,
      _ => ChatFailureKind.badRequest,
    };
    return ChatFailure(
      kind,
      statusCode: statusCode,
      detail: _errorMessage(body),
    );
  }

  String? _errorMessage(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          final message = error['message'];
          if (message != null) {
            return message.toString();
          }
        }
        final message = decoded['message'];
        if (message != null) {
          return message.toString();
        }
      }
    } on FormatException {
      // Fall through to the raw body.
    }
    return body.length > 500 ? body.substring(0, 500) : body;
  }

  String? _readString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  List<ChatToolCallDelta> _readToolCalls(Object? value) {
    if (value is! List) {
      return const [];
    }
    final result = <ChatToolCallDelta>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, Object?>.from(item);
      final index = map['index'];
      final function = map['function'];
      final functionMap = function is Map
          ? Map<String, Object?>.from(function)
          : const <String, Object?>{};
      result.add(
        ChatToolCallDelta(
          index: index is num ? index.toInt() : result.length,
          id: _readString(map['id']),
          name: _readString(functionMap['name']),
          arguments: _readString(functionMap['arguments']),
        ),
      );
    }
    return result;
  }
}

final openAiCompatibleClientProvider = Provider<OpenAiCompatibleClient>((ref) {
  return OpenAiCompatibleClient();
});
