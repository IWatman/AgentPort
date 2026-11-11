import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentport/data/auth/provider_oauth.dart';
import 'package:agentport/domain/entities/provider_oauth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';

final _now = DateTime.utc(2026, 11, 11, 12);
const _hostId = 'urn:uuid:test-agentport-host';
const _clientId = 'oaiapp_test_agentport';
const _planScopes =
    'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';
late JsonWebKey _signingKey;
late JsonWebKey _otherKey;

Matcher _fails(ProviderOAuthError code) => throwsA(
  isA<ProviderOAuthException>().having((error) => error.code, 'code', code),
);

ProviderOAuthCredential _previous({
  String? refreshToken = 'test-refresh-old',
  String subject = 'test-subject',
}) => ProviderOAuthCredential(
  method: ProviderAuthMethod.chatGpt,
  accessToken: 'test-access-old',
  refreshToken: refreshToken,
  idToken: 'test-retained-id-token',
  clientId: _clientId,
  hostId: _hostId,
  issuer: ProviderOAuthFlow.openAiIssuer,
  subject: subject,
  email: 'test@example.invalid',
  expiresAt: _now,
  scopes: _planScopes.split(' '),
);

String _signed(Map<String, Object?> claims, {JsonWebKey? key}) {
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..setProtectedHeader('kid', 'test-signing-key')
    ..addRecipient(key ?? _signingKey, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

Map<String, Object?> _claims({String? nonce}) => {
  'iss': ProviderOAuthFlow.openAiIssuer,
  'sub': 'test-subject',
  'aud': [_clientId],
  'iat': _now.millisecondsSinceEpoch ~/ 1000,
  'exp': _now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'email': 'test@example.invalid',
  'nonce': ?nonce,
};

Future<void> _callback(Uri auth, Map<String, String> params) async {
  final redirect = Uri.parse(
    auth.queryParameters['redirect_uri'] ??
        auth.queryParameters['callback_url']!,
  );
  final client = http.Client();
  try {
    final response = await client.get(
      redirect.replace(queryParameters: params),
    );
    expect(response.statusCode, 200);
    expect(response.headers['cache-control'], 'no-store');
    expect(response.body, isNot(contains('test-code')));
  } finally {
    client.close();
  }
}

class _TrackingClient extends MockClient {
  _TrackingClient(super.handler);
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _Harness {
  _Harness({
    this.claimOverrides = const {},
    this.tokenOverrides = const {},
    this.callbackOverrides = const {},
    this.omitClientId = false,
    this.omitState = false,
    this.omitIdToken = false,
    this.tokenStatus = 200,
    this.useOtherSigningKey = false,
    this.tokenTransform,
    this.browser,
    this.timeout = const Duration(seconds: 3),
    this.httpTimeout = const Duration(seconds: 1),
    this.onRequest,
  }) {
    flow = ProviderOAuthFlow(
      httpClientFactory: () {
        final client = _TrackingClient(_respond);
        clients.add(client);
        return client;
      },
      browserLauncher: (uri) async {
        authorization = uri;
        if (!opened.isCompleted) opened.complete(uri);
        if (browser != null) return browser!(uri);
        await _callback(uri, {
          'code': 'test-code',
          if (!omitState) 'state': uri.queryParameters['state']!,
          if (!omitClientId && uri.host == 'auth.openai.com')
            'client_id': _clientId,
          ...callbackOverrides,
        });
        return true;
      },
      clock: () => _now,
      authorizationTimeout: timeout,
      httpTimeout: httpTimeout,
    );
  }

  late final ProviderOAuthFlow flow;
  final Map<String, Object?> claimOverrides;
  final Map<String, Object?> tokenOverrides;
  final Map<String, String> callbackOverrides;
  final bool omitClientId;
  final bool omitState;
  final bool omitIdToken;
  final int tokenStatus;
  final bool useOtherSigningKey;
  final String Function(String)? tokenTransform;
  final Future<bool> Function(Uri)? browser;
  final Duration timeout;
  final Duration httpTimeout;
  final Future<http.Response?> Function(http.Request)? onRequest;
  final clients = <_TrackingClient>[];
  final requests = <http.Request>[];
  final opened = Completer<Uri>();
  Uri? authorization;

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    expect(request.url.scheme, 'https');
    expect(request.followRedirects, isFalse);
    expect(request.headers['authorization'], isNull);
    final custom = await onRequest?.call(request);
    if (custom != null) return custom;
    if (request.url.toString() == ProviderOAuthFlow.openAiJwksUrl) {
      final jwk = _signingKey.toJson();
      return http.Response(
        jsonEncode({
          'keys': [
            {
              'kid': 'test-signing-key',
              'kty': 'RSA',
              'alg': 'RS256',
              'use': 'sig',
              'n': jwk['n'],
              'e': jwk['e'],
            },
          ],
        }),
        200,
      );
    }
    if (request.url.host == 'openrouter.ai') {
      expect(request.url.toString(), 'https://openrouter.ai/api/v1/auth/keys');
      return http.Response(
        jsonEncode({'key': 'test-openrouter-key', ...tokenOverrides}),
        tokenStatus,
      );
    }
    expect(
      request.url.toString(),
      'https://auth.openai.com/api/accounts/oauth/token',
    );
    var idToken = _signed({
      ..._claims(nonce: authorization?.queryParameters['nonce']),
      ...claimOverrides,
    }, key: useOtherSigningKey ? _otherKey : null);
    idToken = tokenTransform?.call(idToken) ?? idToken;
    return http.Response(
      jsonEncode({
        'access_token': 'test-access-new',
        'refresh_token': 'test-refresh-new',
        if (!omitIdToken) 'id_token': idToken,
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': _planScopes,
        ...tokenOverrides,
      }),
      tokenStatus,
    );
  }
}

void main() {
  setUpAll(() {
    // Ephemeral test keys are generated locally; no real credentials are used.
    _signingKey = JsonWebKey.generate('RS256', keyBitLength: 2048);
    _otherKey = JsonWebKey.generate('RS256', keyBitLength: 2048);
  });

  group('credential model', () {
    test('stable enum values, fixed OAuth endpoints and legacy fallback', () {
      for (final method in ProviderAuthMethod.values) {
        expect(ProviderAuthMethod.fromStorage(method.storageValue), method);
      }
      expect(
        ProviderAuthMethod.fromStorage('legacy'),
        ProviderAuthMethod.apiKey,
      );
      expect(ProviderAuthMethod.apiKey.baseUrl, isNull);
      expect(ProviderAuthMethod.chatGpt.baseUrl, 'https://api.openai.com/v1');
      expect(
        ProviderAuthMethod.openRouter.baseUrl,
        'https://openrouter.ai/api/v1',
      );
      for (final method in [
        ProviderAuthMethod.chatGpt,
        ProviderAuthMethod.openRouter,
      ]) {
        expect(method.allowsBaseUrl(method.baseUrl!), isTrue);
        expect(method.allowsBaseUrl('${method.baseUrl}/'), isTrue);
        for (final url in [
          'https://example.invalid/v1',
          '${method.baseUrl}?key=bad',
          '${method.baseUrl}#bad',
          '${method.baseUrl}/other',
          method.baseUrl!.replaceFirst('https:', 'http:'),
          method.baseUrl!.replaceFirst('https://', 'https://user@'),
          method.baseUrl!.replaceFirst('/v1', ':444/v1'),
        ]) {
          expect(method.allowsBaseUrl(url), isFalse, reason: url);
        }
      }
    });

    test(
      'round trips sensitive fields, freezes scopes and redacts toString',
      () {
        final credential = _previous();
        final decoded = ProviderOAuthCredential.fromJson(
          Map<String, Object?>.from(
            jsonDecode(jsonEncode(credential.toJson())) as Map,
          ),
        );
        expect(decoded.toJson(), credential.toJson());
        expect(() => decoded.scopes.add('bad'), throwsUnsupportedError);
        expect(decoded.toString(), isNot(contains(credential.accessToken)));
        expect(decoded.toString(), isNot(contains(credential.refreshToken!)));
        final openRouter = ProviderOAuthCredential(
          method: ProviderAuthMethod.openRouter,
          accessToken: 'test-key',
        );
        expect(
          ProviderOAuthCredential.fromJson(openRouter.toJson()).expiresAt,
          isNull,
        );
        expect(
          () => ProviderOAuthCredential.fromJson({
            'method': 'unknown',
            'access_token': 'test',
          }),
          throwsFormatException,
        );
      },
    );
  });

  group('ChatGPT authorization', () {
    test(
      'dynamic registration, S256, issued ID exchange and verified identity',
      () async {
        final harness = _Harness();
        final credential = await harness.flow.authorizeChatGpt(hostId: _hostId);
        final query = harness.authorization!.queryParameters;
        expect(query['client_id'], 'dynamic_agent_client');
        expect(query['agent_name_hint'], 'AgentPort');
        expect(query['ext_agent_host_id'], _hostId);
        expect(query['response_type'], 'code');
        expect(query['resource'], ProviderOAuthFlow.openAiResource);
        expect(query['scope'], _planScopes);
        expect(query['state'], isNotEmpty);
        expect(query['nonce'], isNotEmpty);
        expect(query['nonce'], isNot(query['state']));
        expect(query['code_challenge_method'], 'S256');
        final redirect = Uri.parse(query['redirect_uri']!);
        expect(redirect.host, '127.0.0.1');
        expect(redirect.scheme, 'http');
        expect(redirect.path, '/auth/callback');
        expect(redirect.port, greaterThan(0));
        final request = harness.requests.first;
        final form = request.bodyFields;
        expect(request.method, 'POST');
        expect(
          request.headers['content-type'],
          startsWith('application/x-www-form-urlencoded'),
        );
        expect(form['grant_type'], 'authorization_code');
        expect(form['client_id'], _clientId);
        expect(form['redirect_uri'], query['redirect_uri']);
        expect(form['resource'], ProviderOAuthFlow.openAiResource);
        expect(form['client_secret'], isNull);
        expect(form['code'], 'test-code');
        final verifier = form['code_verifier']!;
        expect(verifier.length, inInclusiveRange(43, 128));
        expect(
          query['code_challenge'],
          base64Url
              .encode(sha256.convert(ascii.encode(verifier)).bytes)
              .replaceAll('=', ''),
        );
        expect(credential.method, ProviderAuthMethod.chatGpt);
        expect(credential.clientId, _clientId);
        expect(credential.hostId, _hostId);
        expect(credential.subject, 'test-subject');
        expect(credential.email, 'test@example.invalid');
        expect(credential.issuer, ProviderOAuthFlow.openAiIssuer);
        expect(credential.accessToken, 'test-access-new');
        expect(credential.refreshToken, 'test-refresh-new');
        expect(credential.idToken, isNotEmpty);
        expect(credential.expiresAt, _now.add(const Duration(hours: 1)));
        expect(credential.scopes, contains('chatgpt.tokens.use.direct'));
        expect(harness.clients.every((client) => client.closed), isTrue);
        await _expectClosed(redirect);
      },
    );

    test(
      'returning registration retains issued client, host and account hints',
      () async {
        final harness = _Harness(omitClientId: true);
        final previous = _previous();
        final result = await harness.flow.authorizeChatGpt(
          hostId: _hostId,
          previous: previous,
        );
        final query = harness.authorization!.queryParameters;
        expect(query['client_id'], _clientId);
        expect(query.containsKey('agent_name_hint'), isFalse);
        expect(query['id_token_hint'], previous.idToken);
        expect(query['login_hint'], previous.email);
        expect(result.clientId, previous.clientId);
        expect(result.subject, previous.subject);
      },
    );

    test('new registration requires a real issued ID', () async {
      for (final harness in [
        _Harness(omitClientId: true),
        _Harness(callbackOverrides: {'client_id': 'dynamic_agent_client'}),
      ]) {
        await expectLater(
          harness.flow.authorizeChatGpt(hostId: _hostId),
          _fails(ProviderOAuthError.incompleteRegistration),
        );
        expect(harness.requests, isEmpty);
      }
    });

    test(
      'rejects changed registration and host before replacing credentials',
      () async {
        final changedClient = _Harness(
          callbackOverrides: {'client_id': 'oaiapp_unrelated'},
        );
        await expectLater(
          changedClient.flow.authorizeChatGpt(
            hostId: _hostId,
            previous: _previous(),
          ),
          _fails(ProviderOAuthError.registrationMismatch),
        );
        expect(changedClient.requests, isEmpty);
        final changedHost = _Harness();
        await expectLater(
          changedHost.flow.authorizeChatGpt(
            hostId: 'other-host',
            previous: _previous(),
          ),
          _fails(ProviderOAuthError.registrationMismatch),
        );
        expect(changedHost.authorization, isNull);
        final changedSubject = _Harness(
          claimOverrides: {'sub': 'different-account'},
        );
        await expectLater(
          changedSubject.flow.authorizeChatGpt(
            hostId: _hostId,
            previous: _previous(),
          ),
          _fails(ProviderOAuthError.identityMismatch),
        );
      },
    );

    for (final entry in {
      'nonce': <String, Object?>{'nonce': 'wrong-nonce'},
      'missing nonce': <String, Object?>{'nonce': null},
      'issuer': <String, Object?>{'iss': 'https://attacker.invalid'},
      'audience': <String, Object?>{
        'aud': ['other-client'],
      },
      'multiple audiences without azp': <String, Object?>{
        'aud': [_clientId, 'other'],
      },
      'authorized party': <String, Object?>{'azp': 'other'},
      'expiry': <String, Object?>{
        'exp':
            _now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
            1000,
      },
      'missing expiry': <String, Object?>{'exp': null},
      'missing subject': <String, Object?>{'sub': ''},
      'future issuance': <String, Object?>{
        'iat':
            _now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      },
      'future not-before': <String, Object?>{
        'nbf':
            _now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      },
    }.entries) {
      test('rejects invalid ${entry.key}', () async {
        final harness = _Harness(claimOverrides: entry.value);
        await expectLater(
          harness.flow.authorizeChatGpt(hostId: _hostId),
          _fails(ProviderOAuthError.invalidToken),
        );
        expect(harness.clients.every((client) => client.closed), isTrue);
      });
    }

    test('rejects a bad RSA signature', () async {
      final harness = _Harness(useOtherSigningKey: true);
      await expectLater(
        harness.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.invalidToken),
      );
    });

    for (final algorithm in ['none', 'HS256', 'RS512']) {
      test(
        'rejects $algorithm outside the signature algorithm allowlist',
        () async {
          final harness = _Harness(
            tokenTransform: (token) {
              final parts = token.split('.');
              final header = jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
              ) as Map;
              header['alg'] = algorithm;
              parts[0] = base64Url
                  .encode(utf8.encode(jsonEncode(header)))
                  .replaceAll('=', '');
              return parts.join('.');
            },
          );
          await expectLater(
            harness.flow.authorizeChatGpt(hostId: _hostId),
            _fails(ProviderOAuthError.invalidToken),
          );
          expect(harness.requests.length, 1);
        },
      );
    }

    test('never follows a token-provided JWKS URL', () async {
      final harness = _Harness(
        tokenTransform: (token) {
          final parts = token.split('.');
          final header = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
          ) as Map;
          header['jku'] = 'https://attacker.invalid/keys';
          parts[0] = base64Url
              .encode(utf8.encode(jsonEncode(header)))
              .replaceAll('=', '');
          return parts.join('.');
        },
      );
      await expectLater(
        harness.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.invalidToken),
      );
      expect(harness.requests.length, 1);
    });

    test('requires token-response plan scope, not callback scopes', () async {
      final harness = _Harness(
        tokenOverrides: {'scope': 'openid email'},
        callbackOverrides: {'scope': _planScopes},
      );
      await expectLater(
        harness.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.planPermissionRequired),
      );
    });

    test('rejects missing ID token and non-bearer token types', () async {
      for (final harness in [
        _Harness(omitIdToken: true),
        _Harness(tokenOverrides: {'token_type': 'MAC'}),
      ]) {
        await expectLater(
          harness.flow.authorizeChatGpt(hostId: _hostId),
          _fails(ProviderOAuthError.invalidToken),
        );
      }
    });

    test(
      'denied consent and state failures never redeem an authorization code',
      () async {
        final denied = _Harness(callbackOverrides: {'error': 'access_denied'});
        await expectLater(
          denied.flow.authorizeChatGpt(hostId: _hostId),
          _fails(ProviderOAuthError.accessDenied),
        );
        expect(denied.requests, isEmpty);
        for (final harness in [
          _Harness(callbackOverrides: {'state': 'attacker-state'}),
          _Harness(omitState: true),
          _Harness(
            callbackOverrides: {'error': 'access_denied', 'state': 'wrong'},
          ),
        ]) {
          await expectLater(
            harness.flow.authorizeChatGpt(hostId: _hostId),
            _fails(ProviderOAuthError.invalidState),
          );
          expect(harness.requests, isEmpty);
        }
      },
    );

    test('sanitizes token errors and raw network exception messages', () async {
      final harness = _Harness(
        onRequest: (_) async =>
            http.Response('sensitive-token-and-query-body', 400),
      );
      try {
        await harness.flow.authorizeChatGpt(hostId: _hostId);
        fail('Expected an authorization error.');
      } on ProviderOAuthException catch (error) {
        expect(error.code, ProviderOAuthError.authorizationFailed);
        expect(error.toString(), isNot(contains('sensitive-token')));
      }
      final network = _Harness(
        onRequest: (_) async => throw Exception('secret-url-token'),
      );
      await expectLater(
        network.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.network),
      );
    });

    test('reports an OpenAI region block without exposing the body', () async {
      final harness = _Harness(
        onRequest: (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'unsupported_country_region_territory',
              'message': 'sensitive-region-detail',
            },
          }),
          403,
        ),
      );
      try {
        await harness.flow.authorizeChatGpt(hostId: _hostId);
        fail('Expected a region error.');
      } on ProviderOAuthException catch (error) {
        expect(error.code, ProviderOAuthError.unsupportedRegion);
        expect(error.toString(), isNot(contains('sensitive-region-detail')));
      }
    });

    test('maps a non-JSON success body to invalidResponse', () async {
      final harness = _Harness(
        onRequest: (_) async => http.Response('<html>proxy</html>', 200),
      );
      await expectLater(
        harness.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.invalidResponse),
      );
    });
  });

  group('attempt lifecycle', () {
    test('cancel closes listener and HTTP client, and allows a later attempt', () async {
      final harness = _Harness(browser: (_) async => true);
      final future = harness.flow.authorizeChatGpt(hostId: _hostId);
      final assertion = expectLater(
        future,
        _fails(ProviderOAuthError.cancelled),
      );
      final auth = await harness.opened.future;
      final redirect = Uri.parse(auth.queryParameters['redirect_uri']!);
      await expectLater(
        harness.flow.authorizeOpenRouter(),
        _fails(ProviderOAuthError.busy),
      );
      harness.flow.cancel();
      harness.flow.cancel();
      await assertion;
      expect(harness.requests, isEmpty);
      expect(harness.clients.every((client) => client.closed), isTrue);
      await _expectClosed(redirect);
      final next = harness.flow.authorizeOpenRouter();
      final nextAssertion = expectLater(
        next,
        _fails(ProviderOAuthError.cancelled),
      );
      // Binding is asynchronous; cancel also works before the listener exists.
      harness.flow.cancel();
      await nextAssertion;
    });

    test('timeout closes listener, including a browser launcher that never returns', () async {
      for (final hangs in [false, true]) {
        final harness = _Harness(
          browser: (_) => hangs ? Completer<bool>().future : Future.value(true),
          timeout: const Duration(milliseconds: 100),
        );
        final future = harness.flow.authorizeChatGpt(hostId: _hostId);
        final assertion = expectLater(
          future,
          _fails(ProviderOAuthError.timeout),
        );
        final auth = await harness.opened.future;
        await assertion;
        await _expectClosed(Uri.parse(auth.queryParameters['redirect_uri']!));
        expect(harness.clients.every((client) => client.closed), isTrue);
      }
    });

    test('browser failure closes listener', () async {
      final harness = _Harness(browser: (_) async => false);
      await expectLater(
        harness.flow.authorizeOpenRouter(),
        _fails(ProviderOAuthError.browserUnavailable),
      );
      final redirect = Uri.parse(
        harness.authorization!.queryParameters['callback_url']!,
      );
      await _expectClosed(redirect);
    });

    test('duplicate callback parameters cannot bypass state validation', () async {
      final harness = _Harness(
        browser: (auth) async {
          final redirect = Uri.parse(auth.queryParameters['redirect_uri']!);
          final uri = redirect.replace(
            query:
                'code=test-code&client_id=$_clientId&state=${auth.queryParameters['state']}&state=other',
          );
          final client = http.Client();
          try {
            await client.get(uri);
          } finally {
            client.close();
          }
          return true;
        },
      );
      await expectLater(
        harness.flow.authorizeChatGpt(hostId: _hostId),
        _fails(ProviderOAuthError.invalidState),
      );
      expect(harness.requests, isEmpty);
    });

    test(
      'ignores unrelated paths and POST without consuming callback',
      () async {
        final harness = _Harness(
          browser: (auth) async {
            final redirect = Uri.parse(auth.queryParameters['redirect_uri']!);
            final client = http.Client();
            try {
              expect(
                (await client.get(redirect.replace(path: '/favicon.ico')))
                    .statusCode,
                404,
              );
              expect((await client.post(redirect)).statusCode, 405);
            } finally {
              client.close();
            }
            await _callback(auth, {
              'code': 'test-code',
              'client_id': _clientId,
              'state': auth.queryParameters['state']!,
            });
            return true;
          },
        );
        expect(
          (await harness.flow.authorizeChatGpt(hostId: _hostId)).subject,
          'test-subject',
        );
      },
    );
  });

  group('OpenRouter', () {
    test(
      'uses state, S256 and JSON key exchange at official endpoint',
      () async {
        final harness = _Harness();
        final credential = await harness.flow.authorizeOpenRouter();
        final auth = harness.authorization!;
        expect(auth.host, 'openrouter.ai');
        expect(auth.path, '/auth');
        expect(auth.queryParameters['state'], isNotEmpty);
        expect(auth.queryParameters['key_label'], 'AgentPort');
        expect(
          Uri.parse(auth.queryParameters['callback_url']!).path,
          '/callback',
        );
        final request = harness.requests.single;
        expect(request.method, 'POST');
        expect(request.headers['content-type'], startsWith('application/json'));
        final json = jsonDecode(request.body) as Map;
        expect(json['code'], 'test-code');
        expect(json['code_challenge_method'], 'S256');
        expect(
          auth.queryParameters['code_challenge'],
          base64Url
              .encode(
                sha256
                    .convert(ascii.encode(json['code_verifier'] as String))
                    .bytes,
              )
              .replaceAll('=', ''),
        );
        expect(credential.method, ProviderAuthMethod.openRouter);
        expect(credential.accessToken, 'test-openrouter-key');
        expect(credential.expiresAt, isNull);
        expect(credential.refreshToken, isNull);
        expect(credential.subject, isNull);
      },
    );

    test(
      'rejects bad state and declined consent without minting a key',
      () async {
        final wrong = _Harness(callbackOverrides: {'state': 'bad'});
        await expectLater(
          wrong.flow.authorizeOpenRouter(),
          _fails(ProviderOAuthError.invalidState),
        );
        expect(wrong.requests, isEmpty);
        final denied = _Harness(callbackOverrides: {'error': 'access_denied'});
        await expectLater(
          denied.flow.authorizeOpenRouter(),
          _fails(ProviderOAuthError.accessDenied),
        );
        expect(denied.requests, isEmpty);
      },
    );
  });

  group('ChatGPT refresh', () {
    test('uses issued client and resource, rotates tokens and retains verified identity', () async {
      final harness = _Harness(omitIdToken: true);
      final previous = _previous();
      final result = await harness.flow.refreshChatGpt(previous);
      expect(harness.authorization, isNull);
      final form = harness.requests.single.bodyFields;
      expect(form, {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': previous.refreshToken,
        'resource': ProviderOAuthFlow.openAiResource,
      });
      expect(form.containsKey('scope'), isFalse);
      expect(form.containsKey('client_secret'), isFalse);
      expect(result.accessToken, 'test-access-new');
      expect(result.refreshToken, 'test-refresh-new');
      expect(result.idToken, previous.idToken);
      expect(result.clientId, previous.clientId);
      expect(result.hostId, previous.hostId);
      expect(result.subject, previous.subject);
      expect(result.email, previous.email);
      expect(result.issuer, previous.issuer);
      expect(result.expiresAt, _now.add(const Duration(hours: 1)));
      expect(previous.refreshToken, 'test-refresh-old');
    });

    test('verifies replacement ID token signature, issuer, audience, expiry and subject', () async {
      final success = _Harness();
      final updated = await success.flow.refreshChatGpt(_previous());
      expect(updated.idToken, isNot(_previous().idToken));
      for (final harness in [
        _Harness(useOtherSigningKey: true),
        _Harness(claimOverrides: {'iss': 'https://attacker.invalid'}),
        _Harness(claimOverrides: {'aud': 'wrong-client'}),
        _Harness(claimOverrides: {'exp': 0}),
      ]) {
        await expectLater(
          harness.flow.refreshChatGpt(_previous()),
          _fails(ProviderOAuthError.invalidToken),
        );
      }
      final changed = _Harness(claimOverrides: {'sub': 'other-account'});
      await expectLater(
        changed.flow.refreshChatGpt(_previous()),
        _fails(ProviderOAuthError.identityMismatch),
      );
    });

    test('refresh retains omitted scope and refresh token but rejects removed plan scope', () async {
      final retained = _Harness(
        omitIdToken: true,
        onRequest: (_) async => http.Response(
          jsonEncode({
            'access_token': 'test-access',
            'expires_in': 3600,
            'token_type': 'Bearer',
          }),
          200,
        ),
      );
      final result = await retained.flow.refreshChatGpt(_previous());
      expect(result.scopes, _previous().scopes);
      expect(result.refreshToken, _previous().refreshToken);
      final declined = _Harness(
        omitIdToken: true,
        tokenOverrides: {'scope': 'openid email'},
      );
      await expectLater(
        declined.flow.refreshChatGpt(_previous()),
        _fails(ProviderOAuthError.planPermissionRequired),
      );
    });

    test('no browser or request for a non-refreshable credential', () async {
      final harness = _Harness();
      await expectLater(
        harness.flow.refreshChatGpt(_previous(refreshToken: null)),
        _fails(ProviderOAuthError.reauthorizationRequired),
      );
      await expectLater(
        harness.flow.refreshChatGpt(
          ProviderOAuthCredential(
            method: ProviderAuthMethod.openRouter,
            accessToken: 'test-key',
          ),
        ),
        _fails(ProviderOAuthError.reauthorizationRequired),
      );
      expect(harness.requests, isEmpty);
      expect(harness.authorization, isNull);
    });

    test(
      'invalid grant requests reauthorization without exposing the body',
      () async {
        final harness = _Harness(tokenStatus: 400);
        await expectLater(
          harness.flow.refreshChatGpt(_previous()),
          _fails(ProviderOAuthError.reauthorizationRequired),
        );
      },
    );

    test(
      'serializes concurrent refreshes and cancel does not interrupt refresh',
      () async {
        final gate = Completer<void>();
        final started = Completer<void>();
        final harness = _Harness(
          omitIdToken: true,
          onRequest: (_) async {
            started.complete();
            await gate.future;
            return null;
          },
        );
        final first = harness.flow.refreshChatGpt(_previous());
        final second = harness.flow.refreshChatGpt(_previous());
        await started.future;
        harness.flow.cancel();
        expect(harness.requests.length, 1);
        gate.complete();
        expect(identical(await first, await second), isTrue);
        expect(harness.requests.length, 1);
      },
    );

    test('network timeout is sanitized and closes refresh client', () async {
      final harness = _Harness(
        onRequest: (_) => Completer<http.Response?>().future,
        httpTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        harness.flow.refreshChatGpt(_previous()),
        _fails(ProviderOAuthError.timeout),
      );
      expect(harness.clients.every((client) => client.closed), isTrue);
    });
  });
}

Future<void> _expectClosed(Uri redirect) async {
  final socket = Socket.connect(
    redirect.host,
    redirect.port,
    timeout: const Duration(milliseconds: 200),
  );
  await expectLater(socket, throwsA(isA<SocketException>()));
}
