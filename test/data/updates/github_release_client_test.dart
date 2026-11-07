import 'dart:async';
import 'dart:convert';

import 'package:agentport/data/updates/github_release_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'release_test_utils.dart';

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('GitHubReleaseClient', () {
    test(
      'sends the GitHub API headers and returns the newest release',
      () async {
        http.Request? seen;
        final client = MockClient((request) async {
          seen = request;
          return _jsonResponse([githubRelease(tag: 'v0.2.0')]);
        });

        final release = await GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0',
          client: client,
        );

        expect(release, isNotNull);
        expect(release!.tagName, 'v0.2.0');
        expect(seen, isNotNull);
        expect(seen!.url.toString(), GitHubReleaseClient.defaultReleasesUrl);
        expect(seen!.method, 'GET');
        expect(seen!.headers['Accept'], 'application/vnd.github+json');
        expect(seen!.headers['X-GitHub-Api-Version'], '2022-11-28');
        expect(seen!.headers['User-Agent'], 'AgentPort/0.1.0');
      },
    );

    test('uses the client supplied to the constructor', () async {
      final client = GitHubReleaseClient(
        client: MockClient(
          (request) async => _jsonResponse([githubRelease(tag: 'v0.3.0')]),
        ),
      );

      final release = await client.latestStable(currentVersion: '0.2.0');

      expect(release?.tagName, 'v0.3.0');
    });

    test('ignores drafts and pre-releases and sorts by published_at', () async {
      final client = MockClient(
        (request) async => _jsonResponse([
          githubRelease(
            tag: 'v9.0.0',
            publishedAt: '2026-05-01T00:00:00Z',
            prerelease: true,
          ),
          githubRelease(
            tag: 'v8.0.0',
            publishedAt: '2026-04-01T00:00:00Z',
            draft: true,
          ),
          githubRelease(tag: 'v0.2.0', publishedAt: '2026-02-01T00:00:00Z'),
          githubRelease(tag: 'v0.3.0', publishedAt: '2026-01-01T00:00:00Z'),
        ]),
      );

      final release = await GitHubReleaseClient().latestStable(
        currentVersion: '0.1.0',
        client: client,
      );

      expect(release?.tagName, 'v0.2.0');
    });

    test('returns null when the newest stable release is not newer', () async {
      for (final tag in ['v0.1.0', 'v0.0.9', '0.1.0+999']) {
        final client = MockClient(
          (request) async => _jsonResponse([githubRelease(tag: tag)]),
        );

        final release = await GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0+100',
          client: client,
        );

        expect(release, isNull, reason: tag);
      }
    });

    test('returns null when every release is a draft or pre-release', () async {
      final client = MockClient(
        (request) async => _jsonResponse([
          githubRelease(tag: 'v2.0.0', draft: true),
          githubRelease(tag: 'v1.0.0', prerelease: true),
        ]),
      );

      final release = await GitHubReleaseClient().latestStable(
        currentVersion: '0.1.0',
        client: client,
      );

      expect(release, isNull);
    });

    test('returns null for an empty list', () async {
      final client = MockClient(
        (request) async => _jsonResponse(const <Object>[]),
      );

      final release = await GitHubReleaseClient().latestStable(
        currentVersion: '0.1.0',
        client: client,
      );

      expect(release, isNull);
    });

    test('skips malformed entries and still returns a valid release', () async {
      final client = MockClient(
        (request) async => _jsonResponse([
          null,
          'not-an-object',
          {'name': 'Missing tag'},
          githubRelease(tag: 'not-a-version'),
          githubRelease(tag: 'v0.1.1'),
        ]),
      );

      final release = await GitHubReleaseClient().latestStable(
        currentVersion: '0.1.0',
        client: client,
      );

      expect(release?.tagName, 'v0.1.1');
    });

    test('maps malformed JSON to invalidResponse', () async {
      final client = MockClient(
        (request) async => http.Response('{not json', 200),
      );

      await expectLater(
        GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0',
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('maps a non-list payload to invalidResponse', () async {
      final client = MockClient(
        (request) async => _jsonResponse({'message': 'unexpected'}),
      );

      await expectLater(
        GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0',
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('maps 403 and 429 to rateLimited with a useful message', () async {
      for (final status in [403, 429]) {
        final client = MockClient(
          (request) async => _jsonResponse({
            'message': 'API rate limit exceeded',
          }, statusCode: status),
        );

        await expectLater(
          GitHubReleaseClient().latestStable(
            currentVersion: '0.1.0',
            client: client,
          ),
          throwsA(
            isA<UpdateFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  UpdateFailureKind.rateLimited,
                )
                .having((failure) => failure.statusCode, 'statusCode', status)
                .having(
                  (failure) => failure.detail,
                  'detail',
                  allOf(contains('rate limit'), contains('Try again later')),
                ),
          ),
        );
      }
    });

    test('includes the retry delay in rate-limit messages', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'API rate limit exceeded'}),
          429,
          headers: {'retry-after': '60'},
        ),
      );

      await expectLater(
        GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0',
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.detail,
            'detail',
            contains('60 seconds'),
          ),
        ),
      );
    });

    test('maps other HTTP errors to server', () async {
      for (final status in [404, 500, 503]) {
        final client = MockClient(
          (request) async => http.Response('failure', status),
        );

        await expectLater(
          GitHubReleaseClient().latestStable(
            currentVersion: '0.1.0',
            client: client,
          ),
          throwsA(
            isA<UpdateFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  UpdateFailureKind.server,
                )
                .having((failure) => failure.statusCode, 'statusCode', status),
          ),
        );
      }
    });

    test('maps timeouts to timeout', () async {
      final client = MockClient(
        (request) async => throw TimeoutException('slow'),
      );

      await expectLater(
        GitHubReleaseClient().latestStable(
          currentVersion: '0.1.0',
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.timeout,
          ),
        ),
      );
    });

    test('maps client and other exceptions to network', () async {
      final errors = <Object>[
        http.ClientException('offline'),
        Exception('offline'),
      ];

      for (final error in errors) {
        final client = MockClient((request) async => throw error);

        await expectLater(
          GitHubReleaseClient().latestStable(
            currentVersion: '0.1.0',
            client: client,
          ),
          throwsA(
            isA<UpdateFailure>().having(
              (failure) => failure.kind,
              'kind',
              UpdateFailureKind.network,
            ),
          ),
          reason: error.toString(),
        );
      }
    });

    test('uses a safe user agent when the version is empty', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return _jsonResponse(const <Object>[]);
      });

      await GitHubReleaseClient().latestStable(
        currentVersion: '   ',
        client: client,
      );

      expect(seen!.headers['User-Agent'], 'AgentPort/unknown');
    });
  });
}
