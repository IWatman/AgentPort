import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/opencode.dart';
import 'opencode_endpoints.dart';

/// REST and SSE client for a single OpenCode server.
///
/// Authentication uses HTTP Basic auth with the username `opencode` and the
/// token obtained from the pairing flow as the password.
class OpenCodeClient {
  OpenCodeClient({
    required String baseUrl,
    required this.token,
    this.username = 'opencode',
    OpenCodeHttpClientFactory? clientFactory,
    this.requestTimeout = const Duration(seconds: 20),
    this.eventIdleTimeout = const Duration(seconds: 90),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _baseUri = openCodeBaseUri(baseUrl);

  /// Oldest server version supported by this client.
  static const minimumVersion = '2.2.5';

  static final _versionPattern = RegExp(r'^\s*[vV]?(\d+)\.(\d+)\.(\d+)');

  final String token;
  final String username;
  final Duration requestTimeout;
  final Duration eventIdleTimeout;

  final OpenCodeHttpClientFactory _clientFactory;
  final Uri _baseUri;

  Uri get baseUri => _baseUri;

  late final String _authorization =
      'Basic ${base64Encode(utf8.encode('$username:$token'))}';

  /// Fetches server information and verifies the minimum supported version.
  Future<OpenCodeInfo> info() async {
    final decoded = await _getJson('api/info');
    final map = _asObject(decoded, 'server information');
    final version = map['version'];
    if (version is! String || version.trim().isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server did not report its version.',
      );
    }

    final info = OpenCodeInfo(
      version: version.trim(),
      urls: _readStringList(map['urls']),
      capabilities: _readCapabilities(map['capabilities']),
    );
    checkVersion(info.version);
    return info;
  }

  /// Lists all sessions visible to the connected server.
  Future<List<OpenCodeSession>> sessions() async {
    final decoded = await _getJson('api/session');
    final Object? list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map) {
      list = decoded['sessions'] ?? decoded['data'] ?? decoded['items'];
    } else {
      list = null;
    }
    if (list is! List) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server did not return a session list.',
      );
    }
    return List.unmodifiable(list.map(_parseSession));
  }

  /// Fetches a single session.
  Future<OpenCodeSession> session(String id) async {
    final decoded = await _getJson('api/session/${_segment(id)}');
    final Object? value;
    if (decoded is Map && decoded['session'] is Map) {
      value = decoded['session'];
    } else if (decoded is Map && decoded['data'] is Map) {
      value = decoded['data'];
    } else {
      value = decoded;
    }
    return _parseSession(value);
  }

  /// Sends a prompt to a session.
  ///
  /// The response is acknowledged but not parsed; streamed output arrives via
  /// [events].
  Future<void> sendPrompt(
    String id,
    String prompt, {
    String? agent,
    String? model,
  }) async {
    final body = <String, Object?>{'prompt': prompt};
    if (agent != null && agent.trim().isNotEmpty) {
      body['agent'] = agent.trim();
    }
    if (model != null && model.trim().isNotEmpty) {
      body['model'] = model.trim();
    }
    await _request('POST', 'api/session/${_segment(id)}/prompt', body: body);
  }

  /// Interrupts the current generation in a session.
  Future<void> interrupt(String id) async {
    await _request('POST', 'api/session/${_segment(id)}/interrupt');
  }

  /// Switches the agent used by a session.
  Future<void> setAgent(String id, String agent) async {
    final value = agent.trim();
    if (value.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'Choose an agent first.',
      );
    }
    await _request(
      'POST',
      'api/session/${_segment(id)}/agent',
      body: {'agent': value},
    );
  }

  /// Switches the model used by a session.
  Future<void> setModel(String id, String model) async {
    final value = model.trim();
    if (value.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'Choose a model first.',
      );
    }
    await _request(
      'POST',
      'api/session/${_segment(id)}/model',
      body: {'model': value},
    );
  }

  /// Opens the server event stream.
  ///
  /// The stream yields decoded SSE frames. A quiet stream longer than
  /// [eventIdleTimeout] fails with [OpenCodeFailureKind.timeout].
  Stream<OpenCodeEvent> events() async* {
    final client = _clientFactory();
    try {
      final request = http.Request('GET', _endpoint('api/event'))
        ..headers.addAll({
          'Authorization': _authorization,
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        });

      final response = await client.send(request).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString().timeout(
          requestTimeout,
        );
        throw _failureForStatus(response.statusCode, body);
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(eventIdleTimeout);

      String? frameId;
      String? frameType;
      final dataLines = <String>[];

      void resetFrame() {
        frameId = null;
        frameType = null;
        dataLines.clear();
      }

      await for (final line in lines) {
        if (line.isEmpty) {
          if (_hasEventData(dataLines)) {
            yield _decodeEvent(frameId, frameType, dataLines);
          }
          resetFrame();
          continue;
        }
        if (line.startsWith(':')) {
          continue;
        }

        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }
        switch (field) {
          case 'id':
            frameId = value;
          case 'event':
            frameType = value;
          case 'data':
            dataLines.add(value);
        }
      }

      // Flush a final frame that was not terminated by a blank line.
      if (_hasEventData(dataLines)) {
        yield _decodeEvent(frameId, frameType, dataLines);
      }
    } on OpenCodeFailure {
      rethrow;
    } on TimeoutException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.timeout,
        detail: 'The OpenCode event stream stopped responding.',
      );
    } on IOException catch (error) {
      throw OpenCodeFailure(
        OpenCodeFailureKind.network,
        detail: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw OpenCodeFailure(OpenCodeFailureKind.network, detail: error.message);
    } finally {
      client.close();
    }
  }

  /// Compares a reported version against [minimumVersion].
  static void checkVersion(String version) {
    final match = _versionPattern.firstMatch(version);
    if (match == null) {
      throw OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server reported an invalid version: $version',
      );
    }

    final current = [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
    const required = [2, 2, 5];
    for (var index = 0; index < required.length; index++) {
      if (current[index] > required[index]) {
        return;
      }
      if (current[index] < required[index]) {
        throw OpenCodeFailure(
          OpenCodeFailureKind.unsupportedVersion,
          detail:
              'OpenCode $minimumVersion or newer is required '
              '(server: $version).',
        );
      }
    }
  }

  /// Whether [version] is supported by this client.
  static bool isVersionSupported(String version) {
    try {
      checkVersion(version);
      return true;
    } on OpenCodeFailure {
      return false;
    }
  }

  bool _hasEventData(List<String> dataLines) {
    return dataLines.any((line) => line.trim().isNotEmpty);
  }

  OpenCodeEvent _decodeEvent(
    String? id,
    String? eventType,
    List<String> dataLines,
  ) {
    final payload = dataLines.join('\n');
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server sent malformed event data.',
      );
    }

    final Map<String, Object?> data;
    if (decoded is Map) {
      data = Map<String, Object?>.from(decoded);
    } else {
      data = {'value': decoded};
    }

    final type = eventType?.trim();
    final jsonType = data['type'];
    return OpenCodeEvent(
      id: id == null || id.isEmpty ? null : id,
      type: type != null && type.isNotEmpty
          ? type
          : jsonType is String && jsonType.isNotEmpty
          ? jsonType
          : 'message',
      data: data,
    );
  }

  Future<Object?> _getJson(String path) async {
    final response = await _request('GET', path);
    if (response.body.trim().isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server returned an empty response.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server returned malformed JSON.',
      );
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = _clientFactory();
    try {
      final request = http.Request(method, _endpoint(path))
        ..headers.addAll({
          'Authorization': _authorization,
          'Accept': 'application/json',
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }

      final streamed = await client.send(request).timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failureForStatus(response.statusCode, response.body);
      }
      return response;
    } on OpenCodeFailure {
      rethrow;
    } on TimeoutException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.timeout,
        detail: 'The OpenCode server took too long to respond.',
      );
    } on IOException catch (error) {
      throw OpenCodeFailure(
        OpenCodeFailureKind.network,
        detail: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw OpenCodeFailure(OpenCodeFailureKind.network, detail: error.message);
    } finally {
      client.close();
    }
  }

  Uri _endpoint(String relative) => _baseUri.resolve(relative);

  String _segment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidPayload,
        detail: 'A session id is required.',
      );
    }
    return Uri.encodeComponent(trimmed);
  }

  Map<String, Object?> _asObject(Object? value, String label) {
    if (value is! Map) {
      throw OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server returned an invalid $label response.',
      );
    }
    return Map<String, Object?>.from(value);
  }

  OpenCodeSession _parseSession(Object? value) {
    final map = _asObject(value, 'session');
    final id = map['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.invalidResponse,
        detail: 'The OpenCode server returned a session without an id.',
      );
    }
    final title = map['title'];
    return OpenCodeSession(
      id: id.trim(),
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Untitled session',
      project: _readProject(map),
      updatedAt: _readUpdatedAt(map),
    );
  }

  String? _readProject(Map<String, Object?> map) {
    final project = map['project'];
    if (project is String && project.trim().isNotEmpty) {
      return project.trim();
    }
    if (project is Map) {
      for (final key in const ['name', 'worktree', 'path', 'id']) {
        final value = project[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    for (final key in const ['projectID', 'projectId', 'directory']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  DateTime? _readUpdatedAt(Map<String, Object?> map) {
    var value = map['updatedAt'] ?? map['updated_at'];
    if (value == null && map['time'] is Map) {
      final time = map['time'] as Map;
      value = time['updated'] ?? time['updatedAt'];
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      final milliseconds = value > 100000000000
          ? value.toInt()
          : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return null;
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return List.unmodifiable(
      value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }

  Map<String, Object?> _readCapabilities(Object? value) {
    if (value is Map) {
      return Map.unmodifiable(Map<String, Object?>.from(value));
    }
    if (value is List) {
      return Map.unmodifiable({
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(): true,
      });
    }
    return const {};
  }

  OpenCodeFailure _failureForStatus(int statusCode, String body) {
    final kind = switch (statusCode) {
      401 || 403 => OpenCodeFailureKind.unauthorized,
      408 || 504 => OpenCodeFailureKind.timeout,
      >= 500 || 429 => OpenCodeFailureKind.server,
      _ => OpenCodeFailureKind.invalidResponse,
    };
    return OpenCodeFailure(
      kind,
      statusCode: statusCode,
      detail: _errorDetail(body),
    );
  }

  String? _errorDetail(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } on FormatException {
      // Fall through to the raw body.
    }
    return body.length > 300 ? body.substring(0, 300) : body;
  }
}
