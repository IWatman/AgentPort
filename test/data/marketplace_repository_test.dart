import 'dart:convert';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/data/marketplace/marketplace_api.dart';
import 'package:agentport/data/repositories/marketplace_repository.dart';
import 'package:agentport/domain/entities/marketplace.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uuid/uuid.dart';

const _manifestV1 = '''
{
  "name": "Acme Marketplace",
  "description": "Test marketplace",
  "plugins": [
    {
      "name": "alpha",
      "description": "Alpha plugin",
      "source": "./plugins/alpha"
    },
    {
      "name": "beta",
      "description": "Beta plugin",
      "source": {
        "source": "git-subdir",
        "url": "https://github.com/acme/plugins",
        "path": "plugins/beta",
        "ref": "main"
      }
    }
  ]
}
''';

const _manifestV2 = '''
{
  "name": "Acme Marketplace Refreshed",
  "description": "Refreshed marketplace",
  "plugins": [
    {
      "name": "alpha",
      "description": "Alpha plugin refreshed",
      "source": "./plugins/alpha"
    },
    {
      "name": "gamma",
      "description": "Gamma plugin",
      "source": {
        "source": "url",
        "url": "https://github.com/acme/gamma-plugin"
      }
    }
  ]
}
''';

const _alphaMcpJson = r'''
{
  "mcpServers": {
    "alpha-remote": {
      "type": "http",
      "url": "https://mcp.example.com/alpha",
      "headers": {
        "Authorization": "Bearer ${ALPHA_TOKEN}"
      }
    }
  }
}
''';

const _alphaMcpUrl =
    'https://raw.githubusercontent.com/owner/repo/main/'
    'plugins/alpha/.mcp.json';

class _MockMarketplaceServer {
  _MockMarketplaceServer({
    required this.manifest,
    Map<String, String>? mcpFiles,
  }) : mcpFiles = mcpFiles ?? const {};

  String manifest;
  final Map<String, String> mcpFiles;
  final List<Uri> manifestRequests = [];
  final List<Uri> mcpRequests = [];

  MockClient client() {
    return MockClient((request) async {
      _expectLooseHeaders(request);
      final path = request.url.path;

      if (path.endsWith('/.claude-plugin/marketplace.json')) {
        manifestRequests.add(request.url);
        return http.Response(
          manifest,
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (path.endsWith('/.mcp.json')) {
        mcpRequests.add(request.url);
        final body =
            mcpFiles[request.url.toString()] ?? mcpFiles[request.url.path];
        if (body == null) {
          return http.Response(
            '{"error":"not found"}',
            404,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          body,
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        '{"error":"not found"}',
        404,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }
}

void _expectLooseHeaders(http.BaseRequest request) {
  final accept = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'accept')
      .map((entry) => entry.value)
      .join(',')
      .toLowerCase();
  expect(accept, contains('application/json'));

  final userAgent = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'user-agent')
      .map((entry) => entry.value)
      .join(',')
      .toLowerCase();
  expect(userAgent, contains('agentport'));
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  MarketplaceRepository repositoryFor(_MockMarketplaceServer server) {
    final api = MarketplaceApi(client: server.client());
    addTearDown(api.close);
    return MarketplaceRepository(database, api, uuid: const Uuid());
  }

  group('MarketplaceRepository built-in marketplace', () {
    test('creates exactly one built-in row and is idempotent', () async {
      final server = _MockMarketplaceServer(manifest: _manifestV1);
      final repository = repositoryFor(server);

      await repository.ensureBuiltInMarketplace();
      await repository.ensureBuiltInMarketplace();

      final rows = await database.select(database.marketplaceEntries).get();
      expect(rows, hasLength(1));

      final builtIn = rows.single;
      expect(builtIn.id, kOfficialMarketplaceId);
      expect(builtIn.name, 'Claude Plugins Official');
      expect(builtIn.sourceUrl, kOfficialMarketplaceSource);
      expect(builtIn.manifestUrl, kOfficialMarketplaceManifest);
      expect(builtIn.builtIn, isTrue);
      expect(builtIn.enabled, isTrue);
      expect(server.manifestRequests, isEmpty);
    });
  });

  group('MarketplaceRepository.addMarketplace', () {
    test('adds a marketplace and its plugins from owner/repo', () async {
      final server = _MockMarketplaceServer(manifest: _manifestV1);
      final repository = repositoryFor(server);

      final marketplace = await repository.addMarketplace('owner/repo');

      expect(marketplace.sourceUrl, 'https://github.com/owner/repo');
      expect(marketplace.name, 'Acme Marketplace');
      expect(marketplace.description, 'Test marketplace');
      expect(marketplace.builtIn, isFalse);
      expect(marketplace.enabled, isTrue);
      expect(
        marketplace.manifestUrl,
        'https://raw.githubusercontent.com/owner/repo/main/'
        '.claude-plugin/marketplace.json',
      );
      expect(server.manifestRequests, hasLength(1));
      expect(server.manifestRequests.single.host, 'raw.githubusercontent.com');

      final pluginRows = await database
          .select(database.marketplacePluginEntries)
          .get();
      expect(pluginRows, hasLength(2));
      expect(
        pluginRows.map((row) => row.name),
        unorderedEquals(['alpha', 'beta']),
      );
      expect(
        pluginRows.every((row) => row.marketplaceId == marketplace.id),
        isTrue,
      );

      final alpha = pluginRows.singleWhere((row) => row.name == 'alpha');
      expect(alpha.id, repository.pluginIdFor(marketplace.id, 'alpha'));
      expect(alpha.description, 'Alpha plugin');
      expect(alpha.sourceKind, 'path');
      expect(alpha.sourcePath, './plugins/alpha');
      expect(alpha.installed, isFalse);

      final beta = pluginRows.singleWhere((row) => row.name == 'beta');
      expect(beta.sourceKind, 'git-subdir');
      expect(beta.sourceUrl, 'https://github.com/acme/plugins');
      expect(beta.sourcePath, 'plugins/beta');
      expect(beta.sourceRef, 'main');
    });

    test('rejects adding the same marketplace twice', () async {
      final server = _MockMarketplaceServer(manifest: _manifestV1);
      final repository = repositoryFor(server);

      await repository.addMarketplace('owner/repo');

      await expectLater(
        repository.addMarketplace('owner/repo'),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.duplicate,
          ),
        ),
      );

      expect(
        await database.select(database.marketplaceEntries).get(),
        hasLength(1),
      );
      expect(server.manifestRequests, hasLength(2));
    });
  });

  group('MarketplaceRepository.refreshMarketplace', () {
    test(
      'keeps installed state and drops removed uninstalled plugins',
      () async {
        final server = _MockMarketplaceServer(
          manifest: _manifestV1,
          mcpFiles: const {_alphaMcpUrl: _alphaMcpJson},
        );
        final repository = repositoryFor(server);

        final marketplace = await repository.addMarketplace('owner/repo');
        final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');
        final betaId = repository.pluginIdFor(marketplace.id, 'beta');

        await repository.installPlugin(alphaId);
        await repository.setPluginEnabled(alphaId, false);

        server.manifest = _manifestV2;
        await repository.refreshMarketplace(marketplace.id);

        final refreshedMarketplace = await repository.marketplaceById(
          marketplace.id,
        );
        expect(refreshedMarketplace, isNotNull);
        expect(refreshedMarketplace!.name, 'Acme Marketplace Refreshed');
        expect(refreshedMarketplace.description, 'Refreshed marketplace');

        final alpha = await repository.pluginById(alphaId);
        expect(alpha, isNotNull);
        expect(alpha!.installed, isTrue);
        expect(alpha.enabled, isFalse);
        expect(alpha.description, 'Alpha plugin refreshed');

        expect(await repository.pluginById(betaId), isNull);

        final gamma = await repository.pluginById(
          repository.pluginIdFor(marketplace.id, 'gamma'),
        );
        expect(gamma, isNotNull);
        expect(gamma!.installed, isFalse);
        expect(gamma.source.kind, MarketplaceSourceKind.url);

        final pluginRows = await database
            .select(database.marketplacePluginEntries)
            .get();
        expect(
          pluginRows.map((row) => row.name),
          unorderedEquals(['alpha', 'gamma']),
        );

        final serverRows = await database
            .select(database.mcpServerEntries)
            .get();
        expect(serverRows, hasLength(1));
        expect(serverRows.single.pluginId, alphaId);
      },
    );
  });

  group('MarketplaceRepository.installPlugin', () {
    test('installs remote servers and uninstall removes them', () async {
      final server = _MockMarketplaceServer(
        manifest: _manifestV1,
        mcpFiles: const {_alphaMcpUrl: _alphaMcpJson},
      );
      final repository = repositoryFor(server);

      final marketplace = await repository.addMarketplace('owner/repo');
      final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');

      final installed = await repository.installPlugin(alphaId);

      expect(installed.installed, isTrue);
      expect(installed.enabled, isTrue);
      expect(installed.mcpStatus, PluginMcpStatus.remote);
      expect(installed.servers, hasLength(1));
      expect(installed.servers.single.name, 'alpha-remote');
      expect(installed.servers.single.url, 'https://mcp.example.com/alpha');
      expect(installed.servers.single.authType, McpAuthType.apiKey);
      expect(installed.servers.single.headerNames, ['Authorization']);

      expect(server.mcpRequests, hasLength(1));
      expect(server.mcpRequests.single.host, 'raw.githubusercontent.com');
      expect(
        server.mcpRequests.single.path,
        '/owner/repo/main/plugins/alpha/.mcp.json',
      );

      final serverRows = await database.select(database.mcpServerEntries).get();
      expect(serverRows, hasLength(1));

      final serverRow = serverRows.single;
      expect(serverRow.id, '$alphaId/alpha-remote');
      expect(serverRow.pluginId, alphaId);
      expect(serverRow.marketplaceId, marketplace.id);
      expect(serverRow.name, 'alpha-remote');
      expect(serverRow.url, 'https://mcp.example.com/alpha');
      expect(serverRow.transport, 'http');
      expect(serverRow.authType, 'api-key');
      expect(jsonDecode(serverRow.headerNamesJson!), ['Authorization']);
      expect(serverRow.configHash, isNotEmpty);
      expect(serverRow.enabled, isTrue);

      final uninstalled = await repository.uninstallPlugin(alphaId);

      expect(uninstalled.installed, isFalse);
      expect(await database.select(database.mcpServerEntries).get(), isEmpty);

      final pluginRow = await (database.select(
        database.marketplacePluginEntries,
      )..where((table) => table.id.equals(alphaId))).getSingle();
      expect(pluginRow.installed, isFalse);
      expect(pluginRow.mcpConfigJson, isNull);
      expect(pluginRow.mcpCheckedAt, isNull);
    });

    test('install always refreshes a stale cached MCP config', () async {
      final server = _MockMarketplaceServer(
        manifest: _manifestV1,
        mcpFiles: {_alphaMcpUrl: _alphaMcpJson},
      );
      final repository = repositoryFor(server);
      final marketplace = await repository.addMarketplace('owner/repo');
      final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');

      await repository.probePlugin(alphaId);
      server.mcpFiles[_alphaMcpUrl] = _alphaMcpJson.replaceFirst(
        'https://mcp.example.com/alpha',
        'https://mcp.example.com/moved',
      );

      final installed = await repository.installPlugin(alphaId);

      expect(installed.servers.single.url, 'https://mcp.example.com/moved');
      expect(server.mcpRequests, hasLength(2));
    });
  });

  group('MarketplaceRepository reconsent', () {
    test('flags changes, blocks enable, and accepts the new config', () async {
      final server = _MockMarketplaceServer(
        manifest: _manifestV1,
        mcpFiles: {_alphaMcpUrl: _alphaMcpJson},
      );
      final repository = repositoryFor(server);
      final marketplace = await repository.addMarketplace('owner/repo');
      final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');
      await repository.installPlugin(alphaId);

      server.mcpFiles[_alphaMcpUrl] = _alphaMcpJson.replaceFirst(
        'https://mcp.example.com/alpha',
        'https://mcp.example.com/changed',
      );
      final probed = await repository.probePlugin(alphaId);

      expect(probed.needsReconsent, isTrue);
      expect(probed.enabled, isFalse);
      var serverRows = await database.select(database.mcpServerEntries).get();
      expect(serverRows.single.enabled, isFalse);
      expect(serverRows.single.needsReconsent, isTrue);

      await expectLater(
        repository.setPluginEnabled(alphaId, true),
        throwsA(
          isA<MarketplaceFailure>().having(
            (failure) => failure.kind,
            'kind',
            MarketplaceFailureKind.needsReconsent,
          ),
        ),
      );

      final accepted = await repository.acceptPluginConfig(alphaId);

      expect(accepted.needsReconsent, isFalse);
      expect(accepted.enabled, isTrue);
      expect(accepted.installed, isTrue);
      expect(accepted.servers.single.url, 'https://mcp.example.com/changed');
      serverRows = await database.select(database.mcpServerEntries).get();
      expect(serverRows.single.url, 'https://mcp.example.com/changed');
      expect(serverRows.single.enabled, isTrue);
      expect(serverRows.single.needsReconsent, isFalse);
    });

    test('a probe error keeps the last known config', () async {
      final server = _MockMarketplaceServer(
        manifest: _manifestV1,
        mcpFiles: {_alphaMcpUrl: _alphaMcpJson},
      );
      final repository = repositoryFor(server);
      final marketplace = await repository.addMarketplace('owner/repo');
      final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');
      await repository.installPlugin(alphaId);

      server.mcpFiles[_alphaMcpUrl] = '{"mcpServers": {';
      final probed = await repository.probePlugin(alphaId);

      expect(probed.mcpStatus, PluginMcpStatus.error);
      expect(probed.servers.single.url, 'https://mcp.example.com/alpha');
      expect(probed.needsReconsent, isFalse);
      expect(probed.enabled, isTrue);
    });
  });

  group('MarketplaceRepository.setPluginEnabled', () {
    test('toggles the plugin and its installed server rows', () async {
      final server = _MockMarketplaceServer(
        manifest: _manifestV1,
        mcpFiles: const {_alphaMcpUrl: _alphaMcpJson},
      );
      final repository = repositoryFor(server);

      final marketplace = await repository.addMarketplace('owner/repo');
      final alphaId = repository.pluginIdFor(marketplace.id, 'alpha');
      await repository.installPlugin(alphaId);

      final disabled = await repository.setPluginEnabled(alphaId, false);
      expect(disabled.enabled, isFalse);
      var serverRows = await database.select(database.mcpServerEntries).get();
      expect(serverRows.single.enabled, isFalse);

      final enabled = await repository.setPluginEnabled(alphaId, true);
      expect(enabled.enabled, isTrue);
      serverRows = await database.select(database.mcpServerEntries).get();
      expect(serverRows.single.enabled, isTrue);
    });
  });
}
