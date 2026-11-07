import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';

typedef McpHttpClientFactory = http.Client Function();

/// Minimal MCP Streamable HTTP client.
///
/// The client performs the JSON-RPC handshake, discovers tools, and invokes
/// them. Authentication headers are supplied by the caller and are never
/// persisted here.
class McpClient {
  McpClient({McpHttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const protocolVersion = '2025-03-26';
  static const _timeout = Duration(seconds: 25);

  final McpHttpClientFactory _clientFactory;

  Future<McpSession> connect({
    required McpServer server,
    Map<String, String> headers = const {},
  }) async {
    if (server.transport != McpTransport.http) {
      throw const McpFailure(
        McpFailureKind.unsupportedTransport,
        'Only Streamable HTTP MCP servers are supported right now.',
      );
    }

    final uri = Uri.tryParse(server.url);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server URL must use HTTPS.',
      );
    }

    final client = _clientFactory();
    try {
      final session = McpSession._(
        client,
        uri,
        server.id,
        Map.unmodifiable(headers),
      );
      await session._initialize();
      return session;
    } catch (_) {
      client.close();
      rethrow;
    }
  }
}

class McpSession {
  McpSession._(this._client, this._uri, this._serverId, this._customHeaders);

  final http.Client _client;
  final Uri _uri;
  final String _serverId;
  final Map<String, String> _customHeaders;
  String? _sessionId;
  int _nextId = 1;
  bool _initialized = false;

  Future<void> _initialize() async {
    final params = {
      'protocolVersion': McpClient.protocolVersion,
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'AgentPort', 'version': '0.1.0'},
    };

    try {
      final response = await _post(
        method: 'initialize',
        params: params,
        timeout: McpClient._timeout,
        captureSession: true,
      );
      final result = response['result'];
      if (result is! Map) {
        throw const McpFailure(
          McpFailureKind.invalidResponse,
          'The MCP server did not return an initialize result.',
        );
      }
      _initialized = true;
    } on McpFailure catch (error) {
      if (error.kind != McpFailureKind.protocol) {
        rethrow;
      }
      // Older servers may only understand the previous protocol revision.
      final response = await _post(
        method: 'initialize',
        params: {...params, 'protocolVersion': '2024-11-05'},
        timeout: McpClient._timeout,
        captureSession: true,
      );
      if (response['result'] is! Map) {
        throw const McpFailure(
          McpFailureKind.invalidResponse,
          'The MCP server did not return an initialize result.',
        );
      }
      _initialized = true;
    }

    await _notify('notifications/initialized');
  }

  Future<List<McpTool>> listTools() async {
    if (!_initialized) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP session is not initialized.',
      );
    }

    final tools = <McpTool>[];
    String? cursor;
    do {
      final response = await _post(
        method: 'tools/list',
        params: {'cursor': ?cursor},
      );
      final result = response['result'];
      if (result is! Map) {
        throw const McpFailure(
          McpFailureKind.invalidResponse,
          'The MCP server did not return a tools list.',
        );
      }
      final rawTools = result['tools'];
      if (rawTools is List) {
        for (final item in rawTools) {
          if (item is! Map) {
            continue;
          }
          final map = Map<String, Object?>.from(item);
          final name = map['name'];
          if (name is! String || name.trim().isEmpty) {
            continue;
          }
          final description = map['description'] is String
              ? (map['description']! as String)
              : '';
          final schema = map['inputSchema'];
          tools.add(
            McpTool(
              serverId: _serverId,
              name: name,
              description: description,
              inputSchema: schema is Map
                  ? Map<String, Object?>.from(schema)
                  : const {},
              needsApproval: mcpToolNeedsApproval(name, description),
            ),
          );
        }
      }
      final next = result['nextCursor'];
      cursor = next is String && next.isNotEmpty ? next : null;
    } while (cursor != null);

    return List.unmodifiable(tools);
  }

  Future<McpToolResult> callTool(
    String name,
    Map<String, Object?> arguments,
  ) async {
    if (!_initialized) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP session is not initialized.',
      );
    }

    final response = await _post(
      method: 'tools/call',
      params: {'name': name, 'arguments': arguments},
      timeout: const Duration(seconds: 90),
    );
    final result = response['result'];
    if (result is! Map) {
      throw const McpFailure(
        McpFailureKind.invalidResponse,
        'The MCP server did not return a tool result.',
      );
    }
    final content = <String>[];
    final rawContent = result['content'];
    if (rawContent is List) {
      for (final item in rawContent) {
        if (item is! Map) {
          continue;
        }
        final text = item['text'];
        if (text is String) {
          content.add(text);
        } else {
          content.add(jsonEncode(item));
        }
      }
    }
    final structured = result['structuredContent'];
    if (structured != null) {
      content.add(jsonEncode(structured));
    }
    return McpToolResult(
      content: content.isEmpty
          ? 'Tool returned no content.'
          : content.join('\n'),
      isError: result['isError'] == true,
    );
  }

  void close() {
    _client.close();
  }

  Future<void> _notify(String method) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'method': method});
    final headers = _headers();
    try {
      final response = await _client
          .post(_uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const McpFailure(
          McpFailureKind.unauthorized,
          'The MCP server rejected the request.',
        );
      }
    } on TimeoutException {
      // Notifications are best-effort.
    } on http.ClientException {
      // Some servers do not answer notifications.
    }
  }

  Future<Map<String, Object?>> _post({
    required String method,
    Map<String, Object?>? params,
    Duration timeout = McpClient._timeout,
    bool captureSession = false,
  }) async {
    final id = _nextId++;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    });

    final http.Response response;
    try {
      response = await _client
          .post(_uri, headers: _headers(), body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw const McpFailure(
        McpFailureKind.timeout,
        'The MCP server took too long to respond.',
      );
    } on http.ClientException catch (error) {
      throw McpFailure(McpFailureKind.network, error.message);
    } on Exception catch (error) {
      throw McpFailure(McpFailureKind.network, error.toString());
    }

    if (captureSession) {
      final session = response.headers['mcp-session-id'];
      if (session != null && session.isNotEmpty) {
        _sessionId = session;
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const McpFailure(
        McpFailureKind.unauthorized,
        'The MCP server rejected the credentials.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw McpFailure(
        McpFailureKind.protocol,
        'HTTP ${response.statusCode} from the MCP server.',
      );
    }
    if (response.body.trim().isEmpty) {
      throw const McpFailure(
        McpFailureKind.invalidResponse,
        'The MCP server returned an empty response.',
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    final messages = contentType.contains('text/event-stream')
        ? _parseSse(response.body)
        : [_decodeObject(response.body)];

    for (final message in messages) {
      final messageId = message['id'];
      if (messageId is num && messageId.toInt() == id) {
        final error = message['error'];
        if (error is Map) {
          throw McpFailure(
            McpFailureKind.protocol,
            error['message']?.toString() ?? 'MCP JSON-RPC error',
          );
        }
        return message;
      }
    }

    throw const McpFailure(
      McpFailureKind.invalidResponse,
      'The MCP server did not return the requested response.',
    );
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'MCP-Protocol-Version': McpClient.protocolVersion,
      'Mcp-Session-Id': ?_sessionId,
      ..._customHeaders,
    };
  }

  List<Map<String, Object?>> _parseSse(String body) {
    final messages = <Map<String, Object?>>[];
    for (final block in body.split(RegExp(r'\r?\n\r?\n'))) {
      final data = <String>[];
      for (final line in block.split(RegExp(r'\r?\n'))) {
        if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
        }
      }
      if (data.isEmpty) {
        continue;
      }
      final payload = data.join('\n').trim();
      if (payload.isEmpty) {
        continue;
      }
      try {
        messages.add(_decodeObject(payload));
      } on McpFailure {
        // Ignore malformed notification frames.
      }
    }
    return messages;
  }

  Map<String, Object?> _decodeObject(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const McpFailure(
        McpFailureKind.invalidResponse,
        'The MCP server returned malformed JSON.',
      );
    }
    if (decoded is! Map) {
      throw const McpFailure(
        McpFailureKind.invalidResponse,
        'The MCP server returned a non-object response.',
      );
    }
    return Map<String, Object?>.from(decoded);
  }
}
