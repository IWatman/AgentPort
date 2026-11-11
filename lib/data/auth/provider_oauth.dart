import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/provider_oauth.dart';

typedef OAuthBrowserLauncher = Future<bool> Function(Uri uri);
typedef OAuthHttpClientFactory = http.Client Function();

enum ProviderOAuthError {
  busy,
  cancelled,
  timeout,
  browserUnavailable,
  invalidState,
  accessDenied,
  registrationMismatch,
  identityMismatch,
  incompleteRegistration,
  invalidToken,
  planPermissionRequired,
  reauthorizationRequired,
  network,
  tls,
  invalidResponse,
  unsupportedRegion,
  authorizationFailed,
}

/// Only fixed messages are exposed: server bodies, URLs and tokens are private.
class ProviderOAuthException implements Exception {
  const ProviderOAuthException(this.code);

  final ProviderOAuthError code;

  String get message => switch (code) {
    ProviderOAuthError.busy => 'Another sign-in is already in progress.',
    ProviderOAuthError.cancelled => 'Sign-in was cancelled.',
    ProviderOAuthError.timeout => 'Sign-in timed out. Please try again.',
    ProviderOAuthError.browserUnavailable =>
      'Could not open the system browser.',
    ProviderOAuthError.invalidState =>
      'The sign-in response could not be verified.',
    ProviderOAuthError.accessDenied => 'Authorization was declined.',
    ProviderOAuthError.registrationMismatch =>
      'The selected registration does not match. Sign in again.',
    ProviderOAuthError.identityMismatch =>
      'The signed-in account does not match the selected account.',
    ProviderOAuthError.incompleteRegistration =>
      'Registration was not completed. Please try again.',
    ProviderOAuthError.invalidToken =>
      'The provider identity could not be verified.',
    ProviderOAuthError.planPermissionRequired =>
      'Allow this app to use your ChatGPT plan, then sign in again.',
    ProviderOAuthError.reauthorizationRequired =>
      'This session cannot be renewed. Please sign in again.',
    ProviderOAuthError.network =>
      'Could not contact the authorization service.',
    ProviderOAuthError.tls =>
      'The secure connection to the authorization service failed.',
    ProviderOAuthError.invalidResponse =>
      'The authorization service returned an unexpected response.',
    ProviderOAuthError.unsupportedRegion =>
      'The provider is not available in this country or region.',
    ProviderOAuthError.authorizationFailed =>
      'Authorization could not be completed. Please try again.',
  };

  @override
  String toString() => 'ProviderOAuthException: $message';
}

/// Native public-client OAuth. All remote endpoints are pinned, including JWKS;
/// HTTP/browser/clock injection allows tests without real accounts or secrets.
class ProviderOAuthFlow {
  ProviderOAuthFlow({
    OAuthHttpClientFactory? httpClientFactory,
    OAuthBrowserLauncher? browserLauncher,
    DateTime Function()? clock,
    this.authorizationTimeout = const Duration(minutes: 5),
    this.httpTimeout = const Duration(seconds: 30),
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new,
       _browserLauncher = browserLauncher ?? _launchBrowser,
       _clock = clock ?? DateTime.now;

  static const openAiIssuer = 'https://auth.openai.com';
  static const openAiResource = 'https://api.openai.com/v1';
  static const openAiJwksUrl = '$openAiIssuer/.well-known/jwks.json';
  static const _tokenUrl = '$openAiIssuer/api/accounts/oauth/token';
  static const _planScope = 'chatgpt.tokens.use.direct';
  static const _scopes =
      'openid profile email offline_access resource.invoke $_planScope';

  final OAuthHttpClientFactory _httpClientFactory;
  final OAuthBrowserLauncher _browserLauncher;
  final DateTime Function() _clock;
  final Duration authorizationTimeout;
  final Duration httpTimeout;
  final _refreshes = <String, Future<ProviderOAuthCredential>>{};
  _OAuthAttempt? _attempt;

  static Future<bool> _launchBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Cancels only the active interactive attempt, never a token refresh.
  void cancel() => _attempt?.cancel();

  Future<ProviderOAuthCredential> authorizeChatGpt({
    required String hostId,
    ProviderOAuthCredential? previous,
  }) async {
    if (hostId.trim().isEmpty ||
        (previous != null &&
            (!_validRegistration(previous) || previous.hostId != hostId))) {
      throw const ProviderOAuthException(
        ProviderOAuthError.registrationMismatch,
      );
    }
    return _authorize('/auth/callback', (
      attempt,
      client,
      redirect,
      state,
      verifier,
    ) async {
      final nonce = _random();
      final uri = Uri.parse('$openAiIssuer/api/accounts/authorize').replace(
        queryParameters: {
          'client_id': previous?.clientId ?? 'dynamic_agent_client',
          if (previous == null) 'agent_name_hint': 'AgentPort',
          'ext_agent_host_id': hostId,
          if (previous?.idToken case final String hint when hint.isNotEmpty)
            'id_token_hint': hint,
          if (previous?.email case final String email when email.isNotEmpty)
            'login_hint': email,
          'response_type': 'code',
          'redirect_uri': redirect.toString(),
          'scope': _scopes,
          'resource': openAiResource,
          'state': state,
          'nonce': nonce,
          'code_challenge_method': 'S256',
          'code_challenge': _challenge(verifier),
        },
      );
      final callback = await _openAndWait(attempt, uri, state);
      final returnedId = callback['client_id'];
      if (previous != null &&
          returnedId != null &&
          returnedId != previous.clientId) {
        throw const ProviderOAuthException(
          ProviderOAuthError.registrationMismatch,
        );
      }
      final clientId = returnedId ?? previous?.clientId;
      if (clientId == null ||
          clientId.isEmpty ||
          clientId == 'dynamic_agent_client') {
        throw const ProviderOAuthException(
          ProviderOAuthError.incompleteRegistration,
        );
      }
      attempt.ensureActive();
      final tokens = await _request(
        client,
        _tokenUrl,
        form: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': _required(callback, 'code'),
          'code_verifier': verifier,
          'redirect_uri': redirect.toString(),
          'resource': openAiResource,
        },
      );
      attempt.ensureActive();
      final idToken = _required(tokens, 'id_token');
      final identity = await _verifyIdentity(
        client,
        idToken,
        clientId,
        nonce: nonce,
      );
      attempt.ensureActive();
      if (previous != null && identity['sub'] != previous.subject) {
        throw const ProviderOAuthException(ProviderOAuthError.identityMismatch);
      }
      return _chatGptCredential(
        tokens,
        clientId: clientId,
        hostId: hostId,
        identity: identity,
        idToken: idToken,
      );
    });
  }

  Future<ProviderOAuthCredential> authorizeOpenRouter() => _authorize(
    '/callback',
    (attempt, client, redirect, state, verifier) async {
      final uri = Uri.https('openrouter.ai', '/auth', {
        'callback_url': redirect.toString(),
        'state': state,
        'code_challenge': _challenge(verifier),
        'code_challenge_method': 'S256',
        'key_label': 'AgentPort',
      });
      final callback = await _openAndWait(attempt, uri, state);
      attempt.ensureActive();
      final response = await _request(
        client,
        'https://openrouter.ai/api/v1/auth/keys',
        json: {
          'code': _required(callback, 'code'),
          'code_verifier': verifier,
          'code_challenge_method': 'S256',
        },
      );
      attempt.ensureActive();
      return ProviderOAuthCredential(
        method: ProviderAuthMethod.openRouter,
        accessToken: _required(response, 'key'),
      );
    },
  );

  Future<ProviderOAuthCredential> refreshChatGpt(
    ProviderOAuthCredential credential,
  ) {
    if (!_validRegistration(credential) ||
        (credential.refreshToken?.isEmpty ?? true)) {
      return Future.error(
        const ProviderOAuthException(
          ProviderOAuthError.reauthorizationRequired,
        ),
      );
    }
    // A rotating refresh token must not be consumed concurrently for one session.
    final key = jsonEncode([
      credential.issuer,
      credential.clientId,
      credential.hostId,
      credential.subject,
    ]);
    return _refreshes.putIfAbsent(key, () async {
      final client = _httpClientFactory();
      try {
        final tokens = await _request(
          client,
          _tokenUrl,
          form: {
            'grant_type': 'refresh_token',
            'client_id': credential.clientId!,
            'refresh_token': credential.refreshToken!,
            'resource': openAiResource,
          },
          refresh: true,
        );
        Map<String, Object?> identity = {
          'sub': credential.subject,
          'email': credential.email,
        };
        final idToken = tokens['id_token'];
        if (idToken != null) {
          if (idToken is! String || idToken.isEmpty) {
            throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
          }
          identity = await _verifyIdentity(
            client,
            idToken,
            credential.clientId!,
          );
          if (identity['sub'] != credential.subject) {
            throw const ProviderOAuthException(
              ProviderOAuthError.identityMismatch,
            );
          }
        }
        return _chatGptCredential(
          tokens,
          clientId: credential.clientId!,
          hostId: credential.hostId!,
          identity: identity,
          idToken: idToken as String? ?? credential.idToken,
          previous: credential,
        );
      } on ProviderOAuthException {
        rethrow;
      } catch (_) {
        throw const ProviderOAuthException(ProviderOAuthError.network);
      } finally {
        client.close();
        _refreshes.remove(key);
      }
    });
  }

  bool _validRegistration(ProviderOAuthCredential credential) =>
      credential.method == ProviderAuthMethod.chatGpt &&
      credential.issuer == openAiIssuer &&
      credential.clientId != null &&
      credential.clientId!.isNotEmpty &&
      credential.clientId != 'dynamic_agent_client' &&
      (credential.subject?.isNotEmpty ?? false) &&
      (credential.hostId?.isNotEmpty ?? false);

  Future<ProviderOAuthCredential> _authorize(
    String path,
    Future<ProviderOAuthCredential> Function(
      _OAuthAttempt,
      http.Client,
      Uri,
      String,
      String,
    )
    run,
  ) async {
    if (_attempt != null) {
      throw const ProviderOAuthException(ProviderOAuthError.busy);
    }
    final attempt = _OAuthAttempt();
    _attempt = attempt;
    http.Client? client;
    try {
      client = _httpClientFactory();
      final ownedClient = client;
      final result = () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        attempt.server = server;
        if (!attempt.active) {
          await server.close(force: true);
          attempt.ensureActive();
        }
        final redirect = Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: server.port,
          path: path,
        );
        attempt.listen(redirect);
        return run(attempt, ownedClient, redirect, _random(), _random(64));
      }();
      return await Future.any([
        result,
        attempt.cancelled.future.then<ProviderOAuthCredential>(
          (_) =>
              throw const ProviderOAuthException(ProviderOAuthError.cancelled),
        ),
      ]).timeout(
        authorizationTimeout,
        onTimeout: () =>
            throw const ProviderOAuthException(ProviderOAuthError.timeout),
      );
    } on ProviderOAuthException {
      rethrow;
    } catch (_) {
      throw const ProviderOAuthException(
        ProviderOAuthError.authorizationFailed,
      );
    } finally {
      attempt.active = false;
      client?.close();
      await attempt.server?.close(force: true);
      if (identical(_attempt, attempt)) _attempt = null;
    }
  }

  Future<Map<String, String>> _openAndWait(
    _OAuthAttempt attempt,
    Uri uri,
    String state,
  ) async {
    attempt.ensureActive();
    final launched = await _browserLauncher(uri);
    attempt.ensureActive();
    if (!launched) {
      throw const ProviderOAuthException(ProviderOAuthError.browserUnavailable);
    }
    final callback = await attempt.callback.future;
    attempt.ensureActive();
    if (callback.containsKey('error')) {
      // OpenRouter omits state on denial. A denial cannot grant credentials, so
      // report it even when the state parameter is absent.
      final returnedState = callback['state'];
      if (returnedState != null && returnedState != state) {
        throw const ProviderOAuthException(ProviderOAuthError.invalidState);
      }
      throw ProviderOAuthException(
        callback['error'] == 'access_denied'
            ? ProviderOAuthError.accessDenied
            : ProviderOAuthError.authorizationFailed,
      );
    }
    if (callback['state'] != state) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidState);
    }
    if (callback['code']?.isNotEmpty != true) {
      throw const ProviderOAuthException(
        ProviderOAuthError.authorizationFailed,
      );
    }
    return callback;
  }

  Future<Map<String, Object?>> _request(
    http.Client client,
    String url, {
    Map<String, String>? form,
    Map<String, Object?>? json,
    bool refresh = false,
  }) async {
    try {
      final request =
          http.Request(
              form == null && json == null ? 'GET' : 'POST',
              Uri.parse(url),
            )
            ..followRedirects = false
            ..headers['accept'] = 'application/json';
      if (form != null) request.bodyFields = form;
      if (json != null) {
        request.headers['content-type'] = 'application/json';
        request.body = jsonEncode(json);
      }
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(httpTimeout);
      if (response.statusCode != 200) {
        if (_isUnsupportedRegion(response.body)) {
          throw const ProviderOAuthException(
            ProviderOAuthError.unsupportedRegion,
          );
        }
        if (refresh &&
            (response.statusCode == 400 || response.statusCode == 401)) {
          throw const ProviderOAuthException(
            ProviderOAuthError.reauthorizationRequired,
          );
        }
        throw const ProviderOAuthException(
          ProviderOAuthError.authorizationFailed,
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const ProviderOAuthException(ProviderOAuthError.invalidResponse);
      }
      return body;
    } on ProviderOAuthException {
      rethrow;
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthError.timeout);
    } on HandshakeException {
      throw const ProviderOAuthException(ProviderOAuthError.tls);
    } on FormatException {
      throw const ProviderOAuthException(ProviderOAuthError.invalidResponse);
    } catch (_) {
      throw const ProviderOAuthException(ProviderOAuthError.network);
    }
  }

  /// OpenAI reports region blocks with a fixed error code. Only the code is
  /// inspected; the response body is never exposed or retained.
  static bool _isUnsupportedRegion(String body) {
    if (body.length > 8192) return false;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return (decoded['error'] as Map)['code'] ==
            'unsupported_country_region_territory';
      }
    } catch (_) {
      // Ignore malformed bodies and use the generic authorization error.
    }
    return false;
  }

  Future<Map<String, Object?>> _verifyIdentity(
    http.Client client,
    String token,
    String clientId, {
    String? nonce,
  }) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      // Never follow a token-provided key URL or accept symmetric/unsigned JWTs.
      if (header is! Map ||
          header['alg'] != 'RS256' ||
          header['kid'] is! String ||
          (header['kid'] as String).isEmpty ||
          header.containsKey('crit') ||
          header.containsKey('jku') ||
          header.containsKey('x5u') ||
          header.containsKey('jwk')) {
        throw const FormatException();
      }
      final jwks = await _request(client, openAiJwksUrl);
      final keys = jwks['keys'];
      if (keys is! List) throw const FormatException();
      final store = JsonWebKeyStore();
      var count = 0;
      for (final key in keys) {
        if (key is Map<String, dynamic> &&
            key['kid'] == header['kid'] &&
            key['kty'] == 'RSA' &&
            (key['alg'] == null || key['alg'] == 'RS256') &&
            (key['use'] == null || key['use'] == 'sig') &&
            (key['key_ops'] == null ||
                (key['key_ops'] is List &&
                    (key['key_ops'] as List).contains('verify')))) {
          store.addKey(JsonWebKey.fromJson(key));
          count++;
        }
      }
      if (count != 1) throw const FormatException();
      final signature = JsonWebSignature.fromCompactSerialization(token);
      final verified = await signature.getPayload(
        store,
        allowedAlgorithms: ['RS256'],
      );
      final payload = Map<String, Object?>.from(verified.jsonContent as Map);
      final now = _clock().toUtc().millisecondsSinceEpoch ~/ 1000;
      final aud = payload['aud'];
      final exp = payload['exp'];
      final iat = payload['iat'];
      final nbf = payload['nbf'];
      if (payload['iss'] != openAiIssuer ||
          !(aud == clientId ||
              (aud is List &&
                  aud.contains(clientId) &&
                  (aud.length == 1 || payload['azp'] == clientId))) ||
          (payload['azp'] != null && payload['azp'] != clientId) ||
          exp is! int ||
          exp <= now - 5 ||
          iat is! int ||
          iat > now + 5 ||
          (nbf != null && (nbf is! int || nbf > now + 5)) ||
          payload['sub'] is! String ||
          (payload['sub'] as String).isEmpty ||
          (nonce != null && payload['nonce'] != nonce) ||
          (payload['email'] != null && payload['email'] is! String)) {
        throw const FormatException();
      }
      return payload;
    } on ProviderOAuthException {
      rethrow;
    } catch (_) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
    }
  }

  ProviderOAuthCredential _chatGptCredential(
    Map<String, Object?> tokens, {
    required String clientId,
    required String hostId,
    required Map<String, Object?> identity,
    required String? idToken,
    ProviderOAuthCredential? previous,
  }) {
    final scope = tokens['scope'];
    if (scope != null && scope is! String) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
    }
    final scopes = scope is String
        ? scope.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList()
        : previous?.scopes ?? <String>[];
    if (!scopes.contains(_planScope)) {
      throw const ProviderOAuthException(
        ProviderOAuthError.planPermissionRequired,
      );
    }
    final expiresIn = tokens['expires_in'];
    if (tokens['token_type'] is! String ||
        (tokens['token_type'] as String).toLowerCase() != 'bearer' ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        expiresIn > 31536000) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
    }
    final refresh = tokens['refresh_token'];
    if (refresh != null && (refresh is! String || refresh.isEmpty)) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
    }
    return ProviderOAuthCredential(
      method: ProviderAuthMethod.chatGpt,
      clientId: clientId,
      hostId: hostId,
      subject: identity['sub'] as String,
      email: identity['email'] as String?,
      issuer: openAiIssuer,
      accessToken: _required(tokens, 'access_token'),
      refreshToken: refresh as String? ?? previous?.refreshToken,
      idToken: idToken,
      expiresAt: _clock().toUtc().add(Duration(seconds: expiresIn)),
      scopes: scopes,
    );
  }

  static String _required(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw const ProviderOAuthException(ProviderOAuthError.invalidToken);
    }
    return value;
  }

  static String _random([int length = 32]) => base64Url
      .encode(List<int>.generate(length, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  static String _challenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}

class _OAuthAttempt {
  HttpServer? server;
  bool active = true;
  final cancelled = Completer<void>();
  final callback = Completer<Map<String, String>>();

  void cancel() {
    active = false;
    if (!cancelled.isCompleted) cancelled.complete();
    unawaited(server?.close(force: true));
  }

  void ensureActive() {
    if (!active) {
      throw const ProviderOAuthException(ProviderOAuthError.cancelled);
    }
  }

  void listen(Uri redirect) {
    server!.listen(
      (request) async {
        try {
          request.response.headers
            ..contentType = ContentType.text
            ..set('cache-control', 'no-store')
            ..set('referrer-policy', 'no-referrer')
            ..set(
              'content-security-policy',
              "default-src 'none'; frame-ancestors 'none'",
            );
          if (!active ||
              callback.isCompleted ||
              request.uri.path != redirect.path ||
              request.headers.value('host') != '127.0.0.1:${redirect.port}') {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          if (request.method != 'GET') {
            request.response.statusCode = HttpStatus.methodNotAllowed;
            await request.response.close();
            return;
          }
          final params = request.uri.queryParametersAll;
          // Reject ambiguous callbacks instead of accepting the first/last value.
          final duplicate = params.values.any((values) => values.length != 1);
          request.response.write(
            'Return to AgentPort to finish sign-in. You can close this tab.',
          );
          await request.response.close();
          if (!callback.isCompleted) {
            callback.complete(
              duplicate
                  ? <String, String>{}
                  : params.map((key, values) => MapEntry(key, values.single)),
            );
          }
        } catch (_) {
          if (!callback.isCompleted) callback.complete(<String, String>{});
        }
      },
      onError: (Object _) {
        if (!callback.isCompleted) callback.complete(<String, String>{});
      },
    );
  }
}

// No disposal cancellation: repositories may share this instance for refresh.
final providerOAuthFlowProvider = Provider<ProviderOAuthFlow>(
  (ref) => ProviderOAuthFlow(),
);
