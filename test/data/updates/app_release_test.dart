import 'package:agentport/domain/entities/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

import 'release_test_utils.dart';

void main() {
  group('AppVersion', () {
    test('parses tags with and without a leading v', () {
      expect(AppVersion.parse('0.1.0').toString(), '0.1.0');
      expect(AppVersion.parse('v0.1.0').toString(), '0.1.0');
      expect(AppVersion.parse('V0.1.0').toString(), '0.1.0');
      expect(AppVersion.parse(' 1.2.3 ').toString(), '1.2.3');
    });

    test('parses build metadata without affecting comparison', () {
      final withBuild = AppVersion.parse('v0.1.0+10000');
      expect(withBuild.toString(), '0.1.0+10000');
      expect(withBuild.compareTo(AppVersion.parse('0.1.0')), 0);
      expect(withBuild.isNewerThan(AppVersion.parse('0.1.0+20000')), isFalse);
    });

    test('parses legacy short versions', () {
      expect(AppVersion.parse('1').toString(), '1.0.0');
      expect(AppVersion.parse('v1.2').toString(), '1.2.0');
      expect(AppVersion.parse('0.1').toString(), '0.1.0');
    });

    test('rejects invalid and pre-release versions', () {
      for (final value in [
        '',
        'latest',
        'v',
        '1.2.3.4',
        '1.2.3-beta.1',
        'v1.2.3-rc1',
      ]) {
        expect(AppVersion.tryParse(value), isNull, reason: value);
      }
    });

    test('compareAppVersions compares major, minor, and patch numbers', () {
      expect(compareAppVersions('0.1.1', '0.1.0'), greaterThan(0));
      expect(compareAppVersions('0.2.0', '0.1.9'), greaterThan(0));
      expect(compareAppVersions('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareAppVersions('0.1.0', '0.1.0'), 0);
      expect(compareAppVersions('0.1.0', '0.1.1'), lessThan(0));
      expect(compareAppVersions('1.2', '1.1.9'), greaterThan(0));
      expect(compareAppVersions('2', '1.9.9'), greaterThan(0));
    });

    test('compareAppVersions throws for invalid input', () {
      expect(
        () => compareAppVersions('not-a-version', '0.1.0'),
        throwsFormatException,
      );
    });
  });

  group('AppRelease', () {
    test('parses a stable release and its assets', () {
      final release = AppRelease.fromGitHubJson(
        githubRelease(
          tag: 'v0.2.0',
          name: 'AgentPort 0.2.0',
          body: 'Notes',
          publishedAt: '2026-02-03T04:05:06Z',
          assets: [
            assetJson('AgentPort.apk', size: 42),
            assetJson('AgentPort.apk.sha256', size: 64),
          ],
        ),
      );

      expect(release, isNotNull);
      expect(release!.tagName, 'v0.2.0');
      expect(release.version, '0.2.0');
      expect(release.name, 'AgentPort 0.2.0');
      expect(release.notes, 'Notes');
      expect(
        release.htmlUrl,
        'https://github.com/IWatman/AgentPort/releases/tag/v1.0.0',
      );
      expect(release.publishedAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(release.assets, hasLength(2));
      expect(release.assets.first.name, 'AgentPort.apk');
      expect(release.assets.first.size, 42);
      expect(release.assets.first.downloadUrl, contains('AgentPort.apk'));
    });

    test('preserves build metadata from the tag', () {
      final release = AppRelease.fromGitHubJson(
        githubRelease(tag: 'v0.2.0+10000'),
      );

      expect(release!.version, '0.2.0+10000');
      expect(release.isNewerThan('0.1.9'), isTrue);
      expect(release.isNewerThan('0.2.0'), isFalse);
    });

    test('uses tolerant fallbacks for optional fields', () {
      final release = AppRelease.fromGitHubJson({
        'tag_name': 'v1.0.0',
        'draft': false,
        'prerelease': false,
      });

      expect(release, isNotNull);
      expect(release!.name, 'v1.0.0');
      expect(release.notes, '');
      expect(release.htmlUrl, '');
      expect(release.publishedAt, isNull);
      expect(release.assets, isEmpty);
    });

    test('skips malformed assets but keeps valid ones', () {
      final json = githubRelease();
      json['assets'] = <Object?>[
        {'name': 'missing-url.apk'},
        {'download_url': 'https://example.test/no-name.apk'},
        'not-a-map',
        assetJson('valid.apk', size: -5),
        {
          'name': 'legacy.apk',
          'download_url': 'https://example.test/legacy.apk',
          'size': 7.9,
        },
      ];
      final release = AppRelease.fromGitHubJson(json);

      expect(release!.assets, hasLength(2));
      expect(release.assets.first.name, 'valid.apk');
      expect(release.assets.first.size, 0);
      expect(release.assets.last.name, 'legacy.apk');
      expect(release.assets.last.size, 7);
    });

    test('rejects drafts, pre-releases, and invalid tags', () {
      final cases = [
        githubRelease(draft: true),
        githubRelease(prerelease: true),
        githubRelease(tag: null),
        githubRelease(tag: 'release-1.0.0'),
        githubRelease(tag: 'v1.0.0-rc1'),
        {'tag_name': 'v1.0.0', 'assets': const <Map<String, Object?>>[]},
      ];

      for (final json in cases) {
        expect(AppRelease.fromGitHubJson(json), isNull, reason: '$json');
      }
    });

    test('isNewerThan compares against installed versions', () {
      AppRelease release(String version) {
        return AppRelease(
          tagName: 'v$version',
          version: version,
          name: version,
          notes: '',
          htmlUrl: '',
          publishedAt: null,
          assets: const [],
        );
      }

      expect(release('0.1.1').isNewerThan('0.1.0'), isTrue);
      expect(release('0.2.0').isNewerThan('0.1.9'), isTrue);
      expect(release('1.0.0').isNewerThan('0.9.9'), isTrue);
      expect(release('0.1.0').isNewerThan('v0.1.0'), isFalse);
      expect(release('0.1.0').isNewerThan('0.1.1'), isFalse);
      expect(release('0.1.0+5').isNewerThan('0.1.0+100'), isFalse);
      expect(release('1.2').isNewerThan('1.1.9'), isTrue);
      expect(release('1').isNewerThan('0.9.9'), isTrue);
      expect(release('0.1.0').isNewerThan('unknown'), isFalse);
    });
  });
}
