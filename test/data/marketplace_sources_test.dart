import 'package:agentport/data/marketplace/marketplace_sources.dart';
import 'package:agentport/domain/entities/marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

Marketplace _marketplace({
  String sourceUrl = 'https://github.com/acme/plugins',
  String manifestUrl =
      'https://raw.githubusercontent.com/acme/plugins/main/'
      '.claude-plugin/marketplace.json',
}) {
  return Marketplace(
    id: 'test-marketplace',
    name: 'Test Marketplace',
    description: '',
    sourceUrl: sourceUrl,
    manifestUrl: manifestUrl,
    builtIn: false,
    enabled: true,
    createdAt: DateTime(2026),
  );
}

PluginSource _source(
  MarketplaceSourceKind kind, {
  String? url,
  String? path,
  String? ref,
  String? sha,
}) {
  return PluginSource(
    kind: kind,
    rawJson: '{}',
    url: url,
    path: path,
    ref: ref,
    sha: sha,
  );
}

void main() {
  const resolver = MarketplaceSourceResolver();

  group('MarketplaceSourceResolver.parseInput', () {
    test('resolves owner/repo to GitHub main and master candidates', () {
      final reference = resolver.parseInput(
        'anthropics/claude-plugins-official',
      );

      expect(reference, isNotNull);
      expect(
        reference!.sourceUrl,
        'https://github.com/anthropics/claude-plugins-official',
      );
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/anthropics/'
            'claude-plugins-official/main/.claude-plugin/marketplace.json',
        'https://raw.githubusercontent.com/anthropics/'
            'claude-plugins-official/master/.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a GitHub HTTPS URL', () {
      final reference = resolver.parseInput('https://github.com/owner/repo');

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/main/'
            '.claude-plugin/marketplace.json',
        'https://raw.githubusercontent.com/owner/repo/master/'
            '.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a GitHub HTTPS URL with a .git suffix', () {
      final reference = resolver.parseInput(
        'https://github.com/owner/repo.git',
      );

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/main/'
            '.claude-plugin/marketplace.json',
        'https://raw.githubusercontent.com/owner/repo/master/'
            '.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a GitHub tree URL to a repository subdirectory', () {
      final reference = resolver.parseInput(
        'https://github.com/owner/repo/tree/dev/plugins/catalog/',
      );

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/dev/'
            'plugins/catalog/.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a GitHub tree URL without a subdirectory', () {
      final reference = resolver.parseInput(
        'https://github.com/owner/repo/tree/dev',
      );

      expect(reference, isNotNull);
      expect(reference!.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/dev/'
            '.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a GitHub blob URL pointing at a JSON manifest', () {
      final reference = resolver.parseInput(
        'https://github.com/owner/repo/blob/main/'
        '.claude-plugin/marketplace.json',
      );

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/main/'
            '.claude-plugin/marketplace.json',
      ]);
    });

    test('strips .git from a shorthand repository input', () {
      final reference = resolver.parseInput('owner/repo.git');

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [
        'https://raw.githubusercontent.com/owner/repo/main/'
            '.claude-plugin/marketplace.json',
        'https://raw.githubusercontent.com/owner/repo/master/'
            '.claude-plugin/marketplace.json',
      ]);
    });

    test('resolves a raw.githubusercontent.com manifest URL', () {
      const url =
          'https://raw.githubusercontent.com/owner/repo/main/'
          '.claude-plugin/marketplace.json';
      final reference = resolver.parseInput(url);

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, 'https://github.com/owner/repo');
      expect(reference.manifestUrls, [url]);
    });

    test('accepts a direct JSON manifest URL on another host', () {
      const url = 'https://marketplace.example.com/catalog.json';
      final reference = resolver.parseInput(url);

      expect(reference, isNotNull);
      expect(reference!.sourceUrl, url);
      expect(reference.manifestUrls, [url]);
    });

    test('returns null for invalid or unsupported inputs', () {
      final invalidInputs = [
        '',
        '   ',
        './local/marketplace.json',
        '../plugins/marketplace.json',
        'C:\\Users\\me\\marketplace.json',
        'ftp://github.com/owner/repo',
        'ssh://github.com/owner/repo',
        'http://github.com/owner/repo',
        'http://raw.githubusercontent.com/owner/repo/main/catalog.json',
        'https://user:pass@github.com/owner/repo',
        'https://example.com/catalog.json?token=secret',
        'https://example.com/plugins',
        'https://github.com/owner',
        'not a marketplace reference',
      ];

      for (final input in invalidInputs) {
        expect(
          resolver.parseInput(input),
          isNull,
          reason: 'Expected "$input" to be rejected',
        );
      }
    });
  });

  group('MarketplaceSourceResolver.rawFileUrl', () {
    test('path source follows the marketplace manifest branch', () {
      final marketplace = _marketplace(
        manifestUrl:
            'https://raw.githubusercontent.com/acme/plugins/master/'
            '.claude-plugin/marketplace.json',
      );
      final url = resolver.rawFileUrl(
        source: _source(MarketplaceSourceKind.path, path: './plugins/alpha/'),
        marketplace: marketplace,
        fileName: '.mcp.json',
      );

      expect(
        url,
        'https://raw.githubusercontent.com/acme/plugins/master/'
        'plugins/alpha/.mcp.json',
      );
    });

    test('path source falls back to main without a raw manifest URL', () {
      final marketplace = _marketplace(
        manifestUrl: 'https://marketplace.example.com/catalog.json',
      );
      final url = resolver.rawFileUrl(
        source: _source(MarketplaceSourceKind.path, path: '/plugins/alpha'),
        marketplace: marketplace,
        fileName: '.mcp.json',
      );

      expect(
        url,
        'https://raw.githubusercontent.com/acme/plugins/main/'
        'plugins/alpha/.mcp.json',
      );
    });

    test('path source resolves relative to a subdirectory manifest', () {
      final marketplace = _marketplace(
        manifestUrl:
            'https://raw.githubusercontent.com/acme/plugins/main/'
            'catalogs/team/.claude-plugin/marketplace.json',
      );
      final url = resolver.rawFileUrl(
        source: _source(MarketplaceSourceKind.path, path: './plugins/alpha'),
        marketplace: marketplace,
        fileName: '.mcp.json',
      );

      expect(
        url,
        'https://raw.githubusercontent.com/acme/plugins/main/'
        'catalogs/team/plugins/alpha/.mcp.json',
      );
    });

    test('rejects path traversal and unsafe refs', () {
      final marketplace = _marketplace();
      expect(
        resolver.rawFileUrl(
          source: _source(MarketplaceSourceKind.path, path: '../outside'),
          marketplace: marketplace,
          fileName: '.mcp.json',
        ),
        isNull,
      );
      expect(
        resolver.rawFileUrl(
          source: _source(
            MarketplaceSourceKind.gitSubdir,
            url: 'https://github.com/acme/tools.git',
            path: 'server',
            ref: '../../main',
          ),
          marketplace: marketplace,
          fileName: '.mcp.json',
        ),
        isNull,
      );
    });

    test('git-subdir source prefers sha over ref and keeps its path', () {
      final url = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.gitSubdir,
          url: 'https://github.com/acme/tools.git',
          path: '/packages/server/',
          ref: 'main',
          sha: 'abc1234',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );

      expect(
        url,
        'https://raw.githubusercontent.com/acme/tools/abc1234/'
        'packages/server/.mcp.json',
      );
    });

    test('git-subdir source falls back to ref and then to main', () {
      final withRef = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.gitSubdir,
          url: 'https://github.com/acme/tools',
          path: 'packages/server',
          ref: 'v1.2.0',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );
      expect(
        withRef,
        'https://raw.githubusercontent.com/acme/tools/v1.2.0/'
        'packages/server/.mcp.json',
      );

      final withoutRef = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.gitSubdir,
          url: 'https://github.com/acme/tools',
          path: 'packages/server',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );
      expect(
        withoutRef,
        'https://raw.githubusercontent.com/acme/tools/main/'
        'packages/server/.mcp.json',
      );
    });

    test('url source uses sha or ref without appending a path', () {
      final withSha = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.url,
          url: 'https://github.com/acme/remote',
          path: 'ignored/path',
          sha: 'deadbeef',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );
      expect(
        withSha,
        'https://raw.githubusercontent.com/acme/remote/deadbeef/.mcp.json',
      );

      final withDefaultRef = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.url,
          url: 'https://github.com/acme/remote',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );
      expect(
        withDefaultRef,
        'https://raw.githubusercontent.com/acme/remote/main/.mcp.json',
      );
    });

    test('command and unsupported sources return null', () {
      expect(
        resolver.rawFileUrl(
          source: _source(MarketplaceSourceKind.command),
          marketplace: _marketplace(),
          fileName: '.mcp.json',
        ),
        isNull,
      );
      expect(
        resolver.rawFileUrl(
          source: _source(MarketplaceSourceKind.unsupported),
          marketplace: _marketplace(),
          fileName: '.mcp.json',
        ),
        isNull,
      );
    });

    test('resolves GitLab sources', () {
      final url = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.url,
          url: 'https://gitlab.com/group/project',
          ref: 'v2.0.0',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );

      expect(url, 'https://gitlab.com/group/project/-/raw/v2.0.0/.mcp.json');
    });

    test('resolves Bitbucket sources with the master default branch', () {
      final url = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.gitSubdir,
          url: 'https://bitbucket.org/team/repo.git',
          path: 'pkg/server',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );

      expect(
        url,
        'https://bitbucket.org/team/repo/raw/master/pkg/server/.mcp.json',
      );
    });

    test('returns null when the plugin source host is unsupported', () {
      final url = resolver.rawFileUrl(
        source: _source(
          MarketplaceSourceKind.url,
          url: 'https://example.com/plugin',
        ),
        marketplace: _marketplace(),
        fileName: '.mcp.json',
      );

      expect(url, isNull);
    });
  });
}
