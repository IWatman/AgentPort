import 'dart:convert';

import 'package:agentport/data/mcp/mcp_oauth.dart';
import 'package:agentport/domain/entities/mcp_oauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('McpOAuthFlow', () {
    test('discovers the authorization server metadata', () async {
      final client = McpOAuthFlow(
        clientFactory: () => MockClient((request) async {
          if (request.url.path.contains('oauth-protected-resource')) {
            return _json({
              'resource': 'https://mcp.example/mcp',
              'authorization_servers': ['https://auth.example'],
              'scopes_supported': ['profile', 'email'],
            });
          }
          return _json({
            'issuer': 'https://auth.example',
            'authorization_endpoint': 'https://auth.example/authorize',
            'token_endpoint': 'https://auth.example/token',
            'registration_endpoint': 'https://auth.example/register',
            'scopes_supported': ['profile', 'email', 'offline_access'],
          });
        }),
      );

      final discovery = await client.discover('https://mcp.example/mcp');

      expect(discovery.resource, 'https://mcp.example/mcp');
      expect(
        discovery.authorizationEndpoint.toString(),
        'https://auth.example/authorize',
      );
      expect(discovery.tokenEndpoint.toString(), 'https://auth.example/token');
      expect(
        discovery.registrationEndpoint.toString(),
        'https://auth.example/register',
      );
      expect(discovery.scopesSupported, contains('offline_access'));
    });

    test('runs registration, browser callback, and token exchange', () async {
      final requests = <http.Request>[];
      Map<String, String>? tokenForm;
      final flow = McpOAuthFlow(
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.contains('oauth-protected-resource')) {
            return _json({
              'resource': 'https://mcp.example/mcp',
              'authorization_servers': ['https://auth.example'],
            });
          }
          if (request.url.path == '/.well-known/oauth-authorization-server') {
            return _json({
              'authorization_endpoint': 'https://auth.example/authorize',
              'token_endpoint': 'https://auth.example/token',
              'registration_endpoint': 'https://auth.example/register',
              'scopes_supported': ['profile', 'email', 'offline_access'],
            });
          }
          if (request.url.path == '/register') {
            return _json({'client_id': 'client-1'}, 201);
          }
          if (request.url.path == '/token') {
            tokenForm = request.bodyFields;
            return _json({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'expires_in': 3600,
              'scope': 'profile email offline_access',
            });
          }
          return _json({'error': 'not found'}, 404);
        }),
        browserLauncher: (uri) async {
          final state = uri.queryParameters['state'];
          final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
          final callback = redirect.replace(
            queryParameters: {'code': 'code-1', 'state': state},
          );
          final response = await http.get(callback);
          return response.statusCode == 200;
        },
      );

      final token = await flow.authorize(
        resourceUrl: 'https://mcp.example/mcp',
      );

      expect(token.accessToken, 'access-1');
      expect(token.refreshToken, 'refresh-1');
      expect(token.clientId, 'client-1');
      expect(token.expiresAt, isNotNull);
      expect(token.resource, 'https://mcp.example/mcp');

      final registration = requests.firstWhere(
        (request) => request.url.path == '/register',
      );
      final registrationBody =
          jsonDecode(registration.body) as Map<String, Object?>;
      final redirectUris = registrationBody['redirect_uris'] as List;
      expect(redirectUris.single, startsWith('http://127.0.0.1:'));
      expect(registrationBody['scope'], contains('offline_access'));

      expect(tokenForm?['grant_type'], 'authorization_code');
      expect(tokenForm?['code'], 'code-1');
      expect(tokenForm?['client_id'], 'client-1');
      expect(tokenForm?['code_verifier'], isNotEmpty);
      expect(tokenForm?['resource'], 'https://mcp.example/mcp');
    });

    test('refreshes an expired token', () async {
      final flow = McpOAuthFlow(
        clientFactory: () => MockClient((request) async {
          expect(request.bodyFields['grant_type'], 'refresh_token');
          expect(request.bodyFields['refresh_token'], 'refresh-old');
          return _json({'access_token': 'access-new', 'expires_in': 600});
        }),
      );
      const token = McpOAuthToken(
        accessToken: 'access-old',
        refreshToken: 'refresh-old',
        tokenEndpoint: 'https://auth.example/token',
        clientId: 'client-1',
        resource: 'https://mcp.example/mcp',
      );

      final refreshed = await flow.refresh(token);

      expect(refreshed.accessToken, 'access-new');
      expect(refreshed.refreshToken, 'refresh-old');
      expect(refreshed.expiresAt, isNotNull);
    });

    test('reports a missing protected resource metadata', () async {
      final flow = McpOAuthFlow(
        clientFactory: () =>
            MockClient((request) async => http.Response('missing', 404)),
      );

      await expectLater(
        flow.discover('https://mcp.example/mcp'),
        throwsA(isA<McpOAuthException>()),
      );
    });
  });
}
