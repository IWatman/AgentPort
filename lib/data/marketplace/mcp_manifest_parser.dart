import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/entities/marketplace.dart';

class McpManifestParser {
  const McpManifestParser();

  static final _templateVariable = RegExp(
    r'\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*',
  );
  static const _secretQueryNames = {
    'access_token',
    'api_key',
    'apikey',
    'auth',
    'client_secret',
    'key',
    'password',
    'secret',
    'sig',
    'signature',
    'token',
  };

  PluginMcpMetadata parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      return PluginMcpMetadata(
        status: PluginMcpStatus.error,
        error: 'Invalid JSON: ${error.message}',
      );
    }

    if (decoded is! Map) {
      return const PluginMcpMetadata(
        status: PluginMcpStatus.error,
        error: 'The MCP manifest root must be an object.',
      );
    }

    final root = Map<String, Object?>.from(decoded);
    final rawServers = root['mcpServers'];
    final Map<String, Object?> servers;
    if (rawServers is Map) {
      servers = Map<String, Object?>.from(rawServers);
    } else if (_looksLikeServerMap(root)) {
      servers = root;
    } else {
      servers = const {};
    }

    if (servers.isEmpty) {
      return const PluginMcpMetadata(status: PluginMcpStatus.none);
    }

    final remote = <McpServerConfig>[];
    final unsupported = <String>[];

    for (final entry in servers.entries) {
      final value = entry.value;
      if (value is! Map) {
        unsupported.add(entry.key);
        continue;
      }
      final config = Map<String, Object?>.from(value);
      final server = _parseServer(entry.key, config);
      if (server == null) {
        unsupported.add(entry.key);
      } else {
        remote.add(server);
      }
    }

    final status = remote.isNotEmpty
        ? (unsupported.isEmpty ? PluginMcpStatus.remote : PluginMcpStatus.mixed)
        : (unsupported.isNotEmpty
              ? PluginMcpStatus.stdio
              : PluginMcpStatus.none);

    return PluginMcpMetadata(
      status: status,
      servers: List.unmodifiable(remote),
      unsupportedServers: List.unmodifiable(unsupported),
    );
  }

  McpServerConfig? _parseServer(String name, Map<String, Object?> json) {
    final command = json['command'];
    if (command is String && command.trim().isNotEmpty) {
      return null;
    }

    final url = _string(json['url'])?.trim();
    if (url == null || url.isEmpty) {
      return null;
    }

    final type =
        _string(json['type'])?.trim().toLowerCase() ??
        _string(json['transport'])?.trim().toLowerCase();
    if (type == 'stdio' || type == 'command') {
      return null;
    }

    final transport = McpTransport.fromValue(type);
    if (type != null && transport == null) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') {
      return null;
    }
    if (uri.userInfo.isNotEmpty) {
      return null;
    }
    for (final key in uri.queryParametersAll.keys) {
      if (_secretQueryNames.contains(key.toLowerCase())) {
        return null;
      }
    }

    final headers = json['headers'];
    final headerNames = <String>[];
    final headerTemplates = <String, String>{};
    if (headers is Map) {
      for (final entry in headers.entries) {
        final key = entry.key;
        if (key is! String || key.trim().isEmpty) {
          continue;
        }
        final name = key.trim();
        headerNames.add(name);
        final value = entry.value;
        if (value is String) {
          final variables =
              _templateVariable
                  .allMatches(value)
                  .map((match) => match.group(0)!)
                  .toSet()
                  .toList(growable: false)
                ..sort();
          if (variables.isNotEmpty) {
            headerTemplates[name] = variables.join(' ');
          }
        }
      }
    }
    headerNames.sort();

    final authType = headerNames.isEmpty
        ? McpAuthType.unknown
        : McpAuthType.apiKey;

    return McpServerConfig(
      name: name,
      transport: transport ?? McpTransport.http,
      url: url,
      authType: authType,
      headerNames: List.unmodifiable(headerNames),
      headerTemplates: Map.unmodifiable(headerTemplates),
      rawJson: json,
    );
  }

  bool _looksLikeServerMap(Map<String, Object?> root) {
    if (root.isEmpty) {
      return false;
    }
    var matches = 0;
    for (final value in root.values) {
      if (value is Map &&
          (value.containsKey('url') || value.containsKey('command'))) {
        matches++;
      }
    }
    return matches == root.length;
  }

  String? _string(Object? value) {
    return value is String ? value : null;
  }

  /// Stable, secret-free fingerprint of a server list. Used to detect changed
  /// MCP configuration after a catalog refresh.
  String configHash(List<McpServerConfig> servers) {
    final normalized =
        servers
            .map(
              (server) => {
                'name': server.name,
                'url': server.url,
                'type': server.transport.storageValue,
                'auth': server.authType.storageValue,
                'headers': {
                  for (final key
                      in (server.headerTemplates.keys.toList()..sort()))
                    key: server.headerTemplates[key],
                },
              },
            )
            .toList(growable: false)
          ..sort((a, b) {
            final name = (a['name']! as String).compareTo(b['name']! as String);
            return name != 0
                ? name
                : (a['url']! as String).compareTo(b['url']! as String);
          });
    final text = jsonEncode(normalized);
    return sha256.convert(utf8.encode(text)).toString();
  }
}
