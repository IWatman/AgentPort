import 'dart:convert';

import 'package:agentport/data/marketplace/marketplace_manifest_parser.dart';
import 'package:agentport/domain/entities/marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = '''
{
  "name": "Acme Plugins",
  "description": "A sample marketplace",
  "owner": {
    "name": "Acme Corporation"
  },
  "plugins": [
    {
      "name": "path-plugin",
      "displayName": "Path Plugin",
      "description": "A plugin stored in the repository",
      "source": "./plugins/path-plugin",
      "author": "Alice",
      "category": "development",
      "homepage": "https://example.com/path-plugin",
      "version": "1.2.3"
    },
    {
      "name": "git-plugin",
      "description": "A plugin stored in a git subdirectory",
      "source": {
        "source": "git-subdir",
        "url": "https://github.com/acme/monorepo.git",
        "path": "packages/git-plugin",
        "ref": "main",
        "sha": "abc1234"
      },
      "author": {
        "name": "Bob"
      }
    },
    {
      "name": "url-plugin",
      "source": {
        "source": "url",
        "url": "https://github.com/acme/remote-plugin.git"
      }
    },
    {
      "name": "command-plugin",
      "source": {
        "source": "command",
        "command": "npx"
      }
    },
    {
      "description": "This plugin has no name and is skipped",
      "source": "./plugins/unnamed"
    }
  ]
}
''';

void main() {
  const parser = MarketplaceManifestParser();

  group('MarketplaceManifestParser', () {
    test('parses marketplace metadata and every supported source kind', () {
      final parsed = parser.parse(_manifest);

      expect(parsed.name, 'Acme Plugins');
      expect(parsed.description, 'A sample marketplace');
      expect(parsed.owner, 'Acme Corporation');
      expect(parsed.plugins, hasLength(4));
      expect(parsed.plugins.map((plugin) => plugin.name), [
        'path-plugin',
        'git-plugin',
        'url-plugin',
        'command-plugin',
      ]);

      final pathPlugin = parsed.plugins[0];
      expect(pathPlugin.displayName, 'Path Plugin');
      expect(pathPlugin.description, 'A plugin stored in the repository');
      expect(pathPlugin.author, 'Alice');
      expect(pathPlugin.category, 'development');
      expect(pathPlugin.homepage, 'https://example.com/path-plugin');
      expect(pathPlugin.version, '1.2.3');
      expect(pathPlugin.source.kind, MarketplaceSourceKind.path);
      expect(pathPlugin.source.path, './plugins/path-plugin');
      expect(pathPlugin.source.url, isNull);
      expect(jsonDecode(pathPlugin.source.rawJson), './plugins/path-plugin');

      final gitPlugin = parsed.plugins[1];
      expect(gitPlugin.description, 'A plugin stored in a git subdirectory');
      expect(gitPlugin.author, 'Bob');
      expect(gitPlugin.category, isNull);
      expect(gitPlugin.homepage, isNull);
      expect(gitPlugin.version, isNull);
      expect(gitPlugin.source.kind, MarketplaceSourceKind.gitSubdir);
      expect(gitPlugin.source.url, 'https://github.com/acme/monorepo.git');
      expect(gitPlugin.source.path, 'packages/git-plugin');
      expect(gitPlugin.source.ref, 'main');
      expect(gitPlugin.source.sha, 'abc1234');

      final urlPlugin = parsed.plugins[2];
      expect(urlPlugin.description, '');
      expect(urlPlugin.source.kind, MarketplaceSourceKind.url);
      expect(urlPlugin.source.url, 'https://github.com/acme/remote-plugin.git');

      final commandPlugin = parsed.plugins[3];
      expect(commandPlugin.source.kind, MarketplaceSourceKind.command);
    });

    test('accepts author as a string and as an object', () {
      final parsed = parser.parse('''
{
  "name": "Authors",
  "plugins": [
    {"name": "one", "source": "./one", "author": "  Carol  "},
    {"name": "two", "source": "./two", "author": {"name": "  Dave  "}},
    {"name": "three", "source": "./three", "author": {"email": "x@y.z"}}
  ]
}
''');

      expect(parsed.plugins.map((plugin) => plugin.author), [
        'Carol',
        'Dave',
        null,
      ]);
    });

    test('uses the last value for duplicate JSON keys', () {
      const body = '''
{
  "name": "First Name",
  "name": "Second Name",
  "plugins": [
    {"name": "duplicate-owner", "source": "./plugin", "author": "First"}
  ]
}
''';

      final parsed = parser.parse(body);

      expect(parsed.name, 'Second Name');
      expect(parsed.plugins.single.name, 'duplicate-owner');
    });

    test('skips plugins without a usable name', () {
      final parsed = parser.parse('''
{
  "name": "Skipping",
  "plugins": [
    {"source": "./missing-name"},
    {"name": "   ", "source": "./blank-name"},
    {"name": "  kept  ", "source": "./kept"},
    "not-an-object"
  ]
}
''');

      expect(parsed.plugins, hasLength(1));
      expect(parsed.plugins.single.name, 'kept');
    });

    test('keeps only the first plugin when names are duplicated', () {
      final parsed = parser.parse('''
{
  "name": "Duplicates",
  "plugins": [
    {"name": "same", "description": "first", "source": "./first"},
    {"name": "same", "description": "second", "source": "./second"}
  ]
}
''');

      expect(parsed.plugins, hasLength(1));
      expect(parsed.plugins.single.description, 'first');
    });

    test('uses plugins as an empty list when none are declared', () {
      final parsed = parser.parse('{"name": "Empty", "plugins": []}');

      expect(parsed.name, 'Empty');
      expect(parsed.plugins, isEmpty);
      expect(parsed.owner, isNull);
    });

    test('throws invalidManifest for a missing name', () {
      expect(
        () => parser.parse('{"plugins": []}'),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.invalidManifest,
          ),
        ),
      );
    });

    test('throws invalidManifest for a missing plugins array', () {
      expect(
        () => parser.parse('{"name": "No Plugins"}'),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.invalidManifest,
          ),
        ),
      );
    });

    test('throws invalidManifest for malformed JSON', () {
      expect(
        () => parser.parse('{"name": "Broken",'),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.invalidManifest,
          ),
        ),
      );
    });

    test('throws invalidManifest for a non-object root', () {
      expect(
        () => parser.parse('[]'),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.invalidManifest,
          ),
        ),
      );
    });
  });
}
