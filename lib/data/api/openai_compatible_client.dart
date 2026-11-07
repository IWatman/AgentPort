import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/chat_failure.dart';

class ChatRequestMessage {
  const ChatRequestMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

class ChatDelta {
  const ChatDelta({this.content = '', this.reasoning = '', this.finishReason});

  final String content;
  final String reasoning;
  final String? finishReason;

  bool get isEmpty => content.isEmpty && reasoning.isEmpty;
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
  }) async* {
    final client = _clientFactory();
    try {
      final request = http.Request('POST', chatCompletionsUri(baseUrl))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode({
          'model': model,
          'messages': messages.map((message) => message.toJson()).toList(),
          'stream': true,
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
    required String model,
  }) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            chatCompletionsUri(baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': const [
                ChatRequestMessage(role: 'user', content: 'ping'),
              ],
              'max_tokens': 8,
              'stream': false,
            }),
          )
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
}

final openAiCompatibleClientProvider = Provider<OpenAiCompatibleClient>((ref) {
  return OpenAiCompatibleClient();
});
