import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/mcp_oauth.dart';

typedef OAuthHttpClientFactory = http.Client Function();
typedef OAuthBrowserLauncher = Future<bool> Function(Uri uri);

class McpOAuthException implements Exception {
  const McpOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class McpOAuthDiscovery {
  const McpOAuthDiscovery({
    required this.resource,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scopesSupported,
    this.registrationEndpoint,
  });

  final String resource;
  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final Uri? registrationEndpoint;
  final List<String> scopesSupported;
}

class McpOAuthClient {
  const McpOAuthClient({required this.clientId, this.clientSecret});

  final String clientId;
  final String? clientSecret;
}

/// Runs the MCP OAuth 2.1 authorization-code flow with PKCE.
class McpOAuthFlow {
  McpOAuthFlow({
    OAuthHttpClientFactory? clientFactory,
    OAuthBrowserLauncher? browserLauncher,
    this.callbackTimeout = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 25),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _browserLauncher = browserLauncher ?? _launchExternal;

  final OAuthHttpClientFactory _clientFactory;
  final OAuthBrowserLauncher _browserLauncher;
  final Duration callbackTimeout;
  final Duration requestTimeout;

  static Future<bool> _launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the browser, waits for the loopback callback, and returns tokens.
  Future<McpOAuthToken> authorize({required String resourceUrl}) async {
    final callback = await _CallbackServer.start();
    try {
      final discovery = await discover(resourceUrl);
      final client = await register(
        discovery,
        redirectUri: callback.redirectUri,
      );
      final verifier = _randomToken(48);
      final challenge = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');
      final state = _randomToken(24);
      final authorization = _authorizationUri(
        discovery: discovery,
        client: client,
        redirectUri: callback.redirectUri,
        state: state,
        challenge: challenge,
      );

      final launched = await _browserLauncher(authorization);
      if (!launched) {
        throw const McpOAuthException(
          'Could not open the browser for authorization.',
        );
      }

      final callbackUri = await callback.waitForCallback().timeout(
        callbackTimeout,
        onTimeout: () => throw const McpOAuthException(
          'Authorization timed out. Try connecting again.',
        ),
      );
      if (callbackUri.queryParameters['error'] != null) {
        throw McpOAuthException(
          callbackUri.queryParameters['error_description'] ??
              callbackUri.queryParameters['error']!,
        );
      }
      if (callbackUri.queryParameters['state'] != state) {
        throw const McpOAuthException(
          'The authorization response state does not match.',
        );
      }
      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const McpOAuthException(
          'The authorization server did not return a code.',
        );
      }

      return await exchangeCode(
        discovery: discovery,
        client: client,
        code: code,
        codeVerifier: verifier,
        redirectUri: callback.redirectUri,
      );
    } finally {
      await callback.close();
    }
  }

  Future<McpOAuthDiscovery> discover(String resourceUrl) async {
    final resource = Uri.tryParse(resourceUrl);
    if (resource == null ||
        !resource.hasScheme ||
        resource.host.isEmpty ||
        (resource.scheme != 'https' && resource.scheme != 'http')) {
      throw const McpOAuthException('The MCP server URL is invalid.');
    }

    final resourcePath = resource.path.replaceAll(RegExp(r'/+$'), '');
    final candidates = <Uri>[
      if (resourcePath.isNotEmpty && resourcePath != '/')
        resource.replace(
          path: '/.well-known/oauth-protected-resource$resourcePath',
          query: null,
          fragment: null,
        ),
      resource.replace(
        path: '/.well-known/oauth-protected-resource',
        query: null,
        fragment: null,
      ),
    ];

    Map<String, Object?>? metadata;
    for (final candidate in candidates) {
      metadata = await _getJson(candidate, allowNotFound: true);
      if (metadata != null) {
        break;
      }
    }
    if (metadata == null) {
      throw const McpOAuthException(
        'The MCP server does not publish OAuth metadata.',
      );
    }

    final servers = metadata['authorization_servers'];
    final issuer = servers is List && servers.isNotEmpty ? servers.first : null;
    if (issuer is! String || issuer.isEmpty) {
      throw const McpOAuthException(
        'The MCP server does not advertise an authorization server.',
      );
    }

    final issuerUri = Uri.parse(issuer);
    final issuerPath = issuerUri.path.replaceAll(RegExp(r'/+$'), '');
    final metadataCandidates = <Uri>[
      issuerUri.replace(
        path: '$issuerPath/.well-known/oauth-authorization-server',
        query: null,
        fragment: null,
      ),
      issuerUri.replace(
        path: '$issuerPath/.well-known/openid-configuration',
        query: null,
        fragment: null,
      ),
    ];
    Map<String, Object?>? serverMetadata;
    for (final candidate in metadataCandidates) {
      serverMetadata = await _getJson(candidate, allowNotFound: true);
      if (serverMetadata != null) {
        break;
      }
    }
    if (serverMetadata == null) {
      throw const McpOAuthException(
        'The authorization server metadata could not be loaded.',
      );
    }

    final authorizationEndpoint = _readUri(
      serverMetadata['authorization_endpoint'],
    );
    final tokenEndpoint = _readUri(serverMetadata['token_endpoint']);
    if (authorizationEndpoint == null || tokenEndpoint == null) {
      throw const McpOAuthException(
        'The authorization server metadata is incomplete.',
      );
    }

    return McpOAuthDiscovery(
      resource: metadata['resource'] is String
          ? metadata['resource'] as String
          : resourceUrl,
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      registrationEndpoint: _readUri(serverMetadata['registration_endpoint']),
      scopesSupported: _readStringList(serverMetadata['scopes_supported']),
    );
  }

  Future<McpOAuthClient> register(
    McpOAuthDiscovery discovery, {
    required Uri redirectUri,
  }) async {
    final endpoint = discovery.registrationEndpoint;
    if (endpoint == null) {
      throw const McpOAuthException(
        'The authorization server does not support dynamic registration.',
      );
    }
    final scope = _scopeFor(discovery.scopesSupported);
    final response = await _postJson(endpoint, {
      'client_name': 'AgentPort',
      'redirect_uris': [redirectUri.toString()],
      'grant_types': ['authorization_code', 'refresh_token'],
      'response_types': ['code'],
      'token_endpoint_auth_method': 'none',
      if (scope.isNotEmpty) 'scope': scope,
    });
    if (response == null) {
      throw const McpOAuthException('OAuth client registration failed.');
    }
    final clientId = response['client_id'];
    if (clientId is! String || clientId.isEmpty) {
      throw const McpOAuthException(
        'OAuth client registration returned no client id.',
      );
    }
    return McpOAuthClient(
      clientId: clientId,
      clientSecret: response['client_secret'] is String
          ? response['client_secret'] as String
          : null,
    );
  }

  Future<McpOAuthToken> exchangeCode({
    required McpOAuthDiscovery discovery,
    required McpOAuthClient client,
    required String code,
    required String codeVerifier,
    required Uri redirectUri,
  }) async {
    final response = await _postForm(discovery.tokenEndpoint, {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri.toString(),
      'client_id': client.clientId,
      'code_verifier': codeVerifier,
      if (client.clientSecret != null) 'client_secret': client.clientSecret!,
      'resource': discovery.resource,
    });
    return _tokenFromResponse(response, discovery: discovery, client: client);
  }

  Future<McpOAuthToken> refresh(McpOAuthToken token) async {
    final refreshToken = token.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const McpOAuthException(
        'The OAuth session expired. Connect the server again.',
      );
    }
    final response = await _postForm(Uri.parse(token.tokenEndpoint), {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': token.clientId,
      if (token.clientSecret != null) 'client_secret': token.clientSecret!,
      if (token.resource != null) 'resource': token.resource!,
    });
    if (response == null) {
      throw const McpOAuthException('The OAuth token could not be refreshed.');
    }
    final accessToken = response['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const McpOAuthException(
        'The authorization server returned no access token.',
      );
    }
    final expiresIn = _readInt(response['expires_in']);
    return token.copyWith(
      accessToken: accessToken,
      refreshToken: response['refresh_token'] is String
          ? response['refresh_token'] as String
          : refreshToken,
      expiresAt: expiresIn == null
          ? null
          : DateTime.now().add(Duration(seconds: expiresIn)),
      scope: response['scope'] is String
          ? response['scope'] as String
          : token.scope,
    );
  }

  McpOAuthToken _tokenFromResponse(
    Map<String, Object?>? response, {
    required McpOAuthDiscovery discovery,
    required McpOAuthClient client,
  }) {
    if (response == null) {
      throw const McpOAuthException(
        'The authorization server returned no token.',
      );
    }
    final accessToken = response['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const McpOAuthException(
        'The authorization server returned no access token.',
      );
    }
    final expiresIn = _readInt(response['expires_in']);
    return McpOAuthToken(
      accessToken: accessToken,
      refreshToken: response['refresh_token'] is String
          ? response['refresh_token'] as String
          : null,
      expiresAt: expiresIn == null
          ? null
          : DateTime.now().add(Duration(seconds: expiresIn)),
      tokenEndpoint: discovery.tokenEndpoint.toString(),
      clientId: client.clientId,
      clientSecret: client.clientSecret,
      scope: response['scope'] is String ? response['scope'] as String : null,
      resource: discovery.resource,
    );
  }

  Uri _authorizationUri({
    required McpOAuthDiscovery discovery,
    required McpOAuthClient client,
    required Uri redirectUri,
    required String state,
    required String challenge,
  }) {
    final scope = _scopeFor(discovery.scopesSupported);
    final params = <String, String>{
      'response_type': 'code',
      'client_id': client.clientId,
      'redirect_uri': redirectUri.toString(),
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      if (scope.isNotEmpty) 'scope': scope,
      if (discovery.resource.isNotEmpty) 'resource': discovery.resource,
    };
    return discovery.authorizationEndpoint.replace(
      queryParameters: {
        ...discovery.authorizationEndpoint.queryParameters,
        ...params,
      },
    );
  }

  String _scopeFor(List<String> supported) {
    const preferred = ['profile', 'email', 'offline_access'];
    final available = supported.map((value) => value.toLowerCase()).toSet();
    if (available.isEmpty) {
      return 'profile email offline_access';
    }
    final scopes = [
      for (final scope in preferred)
        if (available.contains(scope)) scope,
    ];
    return scopes.isEmpty ? preferred.join(' ') : scopes.join(' ');
  }

  Future<Map<String, Object?>?> _getJson(
    Uri uri, {
    bool allowNotFound = false,
  }) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(requestTimeout);
      if (allowNotFound && response.statusCode == 404) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpOAuthException(
          'OAuth metadata request failed (${response.statusCode}).',
        );
      }
      final decoded = _decode(response.body);
      if (decoded is! Map) {
        throw const McpOAuthException('OAuth metadata is malformed.');
      }
      return Map<String, Object?>.from(decoded);
    } on TimeoutException {
      throw const McpOAuthException('OAuth discovery timed out.');
    } on http.ClientException catch (error) {
      throw McpOAuthException(error.message);
    } finally {
      client.close();
    }
  }

  Future<Map<String, Object?>?> _postJson(
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw McpOAuthException(
          'OAuth client registration failed (${response.statusCode}).',
        );
      }
      final decoded = _decode(response.body);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on TimeoutException {
      throw const McpOAuthException('OAuth client registration timed out.');
    } on http.ClientException catch (error) {
      throw McpOAuthException(error.message);
    } finally {
      client.close();
    }
  }

  Future<Map<String, Object?>?> _postForm(
    Uri uri,
    Map<String, String> body,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(requestTimeout);
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map ? decoded['error_description'] : null;
        throw McpOAuthException(
          error is String && error.isNotEmpty
              ? error
              : 'OAuth token request failed (${response.statusCode}).',
        );
      }
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on TimeoutException {
      throw const McpOAuthException('The OAuth token request timed out.');
    } on http.ClientException catch (error) {
      throw McpOAuthException(error.message);
    } finally {
      client.close();
    }
  }

  Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const McpOAuthException(
        'The authorization server returned malformed JSON.',
      );
    }
  }

  Uri? _readUri(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(value.trim());
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  int? _readInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  String _randomToken(int bytes) {
    final random = Random.secure();
    final data = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(data).replaceAll('=', '');
  }
}

class _CallbackServer {
  _CallbackServer._(this._server)
    : redirectUri = Uri.parse('http://127.0.0.1:${_server.port}/callback');

  final HttpServer _server;
  final Uri redirectUri;
  final Completer<Uri> _completer = Completer<Uri>();
  var _closed = false;

  static Future<_CallbackServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final callback = _CallbackServer._(server);
    unawaited(callback._listen());
    return callback;
  }

  Future<Uri> waitForCallback() => _completer.future;

  Future<void> _listen() async {
    await for (final request in _server) {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _server.port,
        path: request.uri.path,
        queryParameters: request.uri.queryParameters,
      );
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><meta charset="utf-8">'
        '<title>AgentPort</title>'
        '<body style="font-family:sans-serif;padding:32px">'
        '<h2>Authorization complete</h2>'
        '<p>You can close this tab and return to AgentPort.</p>',
      );
      await request.response.close();
      if (!_completer.isCompleted) {
        _completer.complete(uri);
      }
      await close();
      return;
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    if (!_completer.isCompleted) {
      _completer.completeError(
        const McpOAuthException('The authorization callback was closed.'),
      );
    }
    await _server.close(force: true);
  }
}
