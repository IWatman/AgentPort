import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/marketplace.dart';
import '../../domain/entities/mcp.dart';

typedef McpHttpClientFactory = http.Client Function();

/// Minimal MCP client for Streamable HTTP and the legacy HTTP+SSE transport.
///
/// The client performs the JSON-RPC handshake, discovers tools, and invokes
/// them. Authentication headers are supplied by the caller and are never
/// persisted here.
class McpClient {
  McpClient({McpHttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const protocolVersion = '2025-03-26';
  static const legacyProtocolVersion = '2024-11-05';
  static const _timeout = Duration(seconds: 25);

  final McpHttpClientFactory _clientFactory;

  Future<McpSession> connect({
    required McpServer server,
    Map<String, String> headers = const {},
  }) async {
    if (server.transport != McpTransport.http &&
        server.transport != McpTransport.sse) {
      throw const McpFailure(
        McpFailureKind.unsupportedTransport,
        'This MCP transport is not supported.',
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
        legacySse: server.transport == McpTransport.sse,
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
  McpSession._(
    this._client,
    this._uri,
    this._serverId,
    this._customHeaders, {
    this._legacySse = false,
  });

  final http.Client _client;
  final Uri _uri;
  final String _serverId;
  final Map<String, String> _customHeaders;
  final bool _legacySse;
  String? _sessionId;
  int _nextId = 1;
  bool _initialized = false;

  // Legacy HTTP+SSE state.
  String _sseBuffer = '';
  Uri? _messageUri;
  StreamSubscription<String>? _sseSubscription;
  Completer<Uri>? _endpointCompleter;
  final Map<int, Map<String, Object?>> _earlyResponses = {};
  final Map<int, Completer<Map<String, Object?>>> _pending = {};
  McpFailure? _sseFailure;
  bool _closed = false;

  Future<void> _initialize() async {
    if (_legacySse) {
      await _connectLegacySse();
    }

    final params = {
      'protocolVersion': _legacySse
          ? McpClient.legacyProtocolVersion
          : McpClient.protocolVersion,
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'AgentPort', 'version': '0.2.2'},
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
      if (_legacySse || error.kind != McpFailureKind.protocol) {
        rethrow;
      }
      // Older servers may only understand the previous protocol revision.
      final response = await _post(
        method: 'initialize',
        params: {...params, 'protocolVersion': McpClient.legacyProtocolVersion},
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
    if (_closed) {
      return;
    }
    _closed = true;
    _failSse(
      const McpFailure(McpFailureKind.protocol, 'The MCP session is closed.'),
    );
    _earlyResponses.clear();
    _sseBuffer = '';
    _client.close();
  }

  Future<void> _connectLegacySse() async {
    _endpointCompleter = Completer<Uri>();
    final request = http.Request('GET', _uri)
      ..headers.addAll({'Accept': 'text/event-stream', ..._customHeaders});

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(McpClient._timeout);
    } on TimeoutException {
      throw const McpFailure(
        McpFailureKind.timeout,
        'The MCP server took too long to open the SSE stream.',
      );
    } on http.ClientException catch (error) {
      throw McpFailure(McpFailureKind.network, error.message);
    } on Exception catch (error) {
      throw McpFailure(McpFailureKind.network, error.toString());
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
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('text/event-stream')) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server did not return an SSE stream.',
      );
    }

    _sseSubscription = response.stream
        .transform(utf8.decoder)
        .listen(
          _handleSseChunk,
          onError: _handleSseError,
          onDone: _handleSseDone,
        );
    await _awaitEndpoint();
  }

  Future<Uri> _awaitEndpoint() async {
    final endpoint = _messageUri;
    if (endpoint != null) {
      return endpoint;
    }
    final failure = _sseFailure;
    if (failure != null) {
      throw failure;
    }
    final completer = _endpointCompleter;
    if (completer == null) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP server did not provide an SSE endpoint.',
      );
    }
    try {
      return await completer.future.timeout(McpClient._timeout);
    } on TimeoutException {
      throw const McpFailure(
        McpFailureKind.timeout,
        'The MCP server took too long to provide an SSE endpoint.',
      );
    }
  }

  void _handleSseChunk(String chunk) {
    if (_closed || _sseFailure != null) {
      return;
    }
    _sseBuffer += chunk;
    _sseBuffer = _sseBuffer.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final index = _sseBuffer.indexOf('\n\n');
      if (index < 0) {
        return;
      }
      final block = _sseBuffer.substring(0, index);
      _sseBuffer = _sseBuffer.substring(index + 2);
      _handleSseEvent(block);
    }
  }

  void _handleSseEvent(String block) {
    String? event;
    final data = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    if (data.isEmpty || _closed || _sseFailure != null) {
      return;
    }
    final payload = data.join('\n');
    if (event == 'endpoint') {
      _handleEndpoint(payload);
    } else if (event == null || event == 'message') {
      _handleSseMessage(payload);
    }
  }

  void _handleEndpoint(String data) {
    if (_messageUri != null || _closed || _sseFailure != null) {
      return;
    }
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final completer = _endpointCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    final endpoint = _uri.resolve(trimmed);
    if (endpoint.scheme != _uri.scheme ||
        endpoint.host != _uri.host ||
        endpoint.port != _uri.port) {
      _failSse(
        const McpFailure(
          McpFailureKind.protocol,
          'The MCP endpoint must use the same origin as the server URL.',
        ),
      );
      return;
    }
    _messageUri = endpoint;
    completer.complete(endpoint);
  }

  void _handleSseMessage(String data) {
    final Map<String, Object?> message;
    try {
      message = _decodeObject(data);
    } on McpFailure {
      // Ignore malformed frames.
      return;
    }
    final id = message['id'];
    if (id is! num) {
      // Notifications and pings have no request id.
      return;
    }
    final messageId = id.toInt();
    final completer = _pending.remove(messageId);
    if (completer == null) {
      if (!_closed && messageId >= _nextId) {
        _earlyResponses[messageId] = message;
      }
      return;
    }
    if (!completer.isCompleted) {
      completer.complete(message);
    }
  }

  void _handleSseError(Object error) {
    _failSse(McpFailure(McpFailureKind.network, error.toString()));
  }

  void _handleSseDone() {
    if (_closed) {
      return;
    }
    _failSse(
      _sseFailure ??
          const McpFailure(
            McpFailureKind.network,
            'The MCP SSE stream closed.',
          ),
    );
  }

  void _failSse(McpFailure failure) {
    final effective = _sseFailure ??= failure;
    final endpoint = _endpointCompleter;
    if (endpoint != null && !endpoint.isCompleted) {
      endpoint.completeError(effective);
    }
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(effective);
      }
    }
    final subscription = _sseSubscription;
    _sseSubscription = null;
    if (subscription != null) {
      subscription.cancel().ignore();
    }
  }

  Future<Map<String, Object?>> _postLegacy({
    required String method,
    Map<String, Object?>? params,
    Duration timeout = McpClient._timeout,
  }) async {
    final failure = _sseFailure;
    if (failure != null) {
      throw failure;
    }
    if (_closed) {
      throw const McpFailure(
        McpFailureKind.protocol,
        'The MCP session is closed.',
      );
    }

    final id = _nextId++;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': ?params,
    });
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;

    try {
      final early = _earlyResponses.remove(id);
      if (early != null) {
        return _checkedResponse(early);
      }

      final endpoint = await _awaitEndpoint();

      final http.Response response;
      try {
        response = await _client
            .post(endpoint, headers: _legacyHeaders(), body: body)
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

      final direct = _directMessage(response, id);
      if (direct != null) {
        return _checkedResponse(direct);
      }

      try {
        final message = await completer.future.timeout(timeout);
        return _checkedResponse(message);
      } on TimeoutException {
        throw const McpFailure(
          McpFailureKind.timeout,
          'The MCP server took too long to respond.',
        );
      }
    } finally {
      _pending.remove(id);
    }
  }

  /// Accepts a JSON-RPC response delivered directly by the POST, if any.
  Map<String, Object?>? _directMessage(http.Response response, int id) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return null;
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('text/event-stream')) {
      for (final message in _parseSse(body)) {
        final messageId = message['id'];
        if (messageId is num && messageId.toInt() == id) {
          return message;
        }
      }
      return null;
    }
    if (!contentType.contains('application/json') && !body.startsWith('{')) {
      return null;
    }
    final message = _decodeObject(body);
    final messageId = message['id'];
    return messageId is num && messageId.toInt() == id ? message : null;
  }

  Map<String, Object?> _checkedResponse(Map<String, Object?> message) {
    final error = message['error'];
    if (error is Map) {
      throw McpFailure(
        McpFailureKind.protocol,
        error['message']?.toString() ?? 'MCP JSON-RPC error',
      );
    }
    return message;
  }

  Map<String, String> _legacyHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ..._customHeaders,
    };
  }

  Future<void> _notify(String method) async {
    final body = jsonEncode({'jsonrpc': '2.0', 'method': method});
    final target = _legacySse ? await _awaitEndpoint() : _uri;
    final headers = _legacySse ? _legacyHeaders() : _headers();
    try {
      final response = await _client
          .post(target, headers: headers, body: body)
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
    if (_legacySse) {
      return _postLegacy(method: method, params: params, timeout: timeout);
    }

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
