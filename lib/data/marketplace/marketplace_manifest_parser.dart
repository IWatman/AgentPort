import 'dart:convert';

import '../../domain/entities/marketplace.dart';

class ParsedMarketplace {
  const ParsedMarketplace({
    required this.name,
    required this.description,
    required this.plugins,
    this.owner,
  });

  final String name;
  final String description;
  final String? owner;
  final List<ParsedMarketplacePlugin> plugins;
}

class ParsedMarketplacePlugin {
  const ParsedMarketplacePlugin({
    required this.name,
    required this.description,
    required this.source,
    this.displayName,
    this.author,
    this.category,
    this.homepage,
    this.version,
  });

  final String name;
  final String? displayName;
  final String description;
  final String? author;
  final String? category;
  final String? homepage;
  final String? version;
  final PluginSource source;
}

class MarketplaceManifestParser {
  const MarketplaceManifestParser();

  ParsedMarketplace parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw MarketplaceFailure(
        MarketplaceFailureKind.invalidManifest,
        'Invalid JSON: ${error.message}',
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.invalidManifest,
        'The manifest root must be an object.',
      );
    }

    final name = _string(decoded['name']);
    if (name == null || name.isEmpty) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.invalidManifest,
        'The manifest has no name.',
      );
    }

    final rawPlugins = decoded['plugins'];
    if (rawPlugins is! List) {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.invalidManifest,
        'The manifest has no plugins array.',
      );
    }

    final plugins = <ParsedMarketplacePlugin>[];
    final seenNames = <String>{};
    for (final item in rawPlugins) {
      if (item is! Map) {
        continue;
      }
      final plugin = _parsePlugin(Map<String, Object?>.from(item));
      if (plugin != null && seenNames.add(plugin.name)) {
        plugins.add(plugin);
      }
    }

    return ParsedMarketplace(
      name: name,
      description: _string(decoded['description']) ?? '',
      owner: _authorName(decoded['owner']) ?? _authorName(decoded['author']),
      plugins: plugins,
    );
  }

  ParsedMarketplacePlugin? _parsePlugin(Map<String, Object?> json) {
    final name = _string(json['name'])?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }

    final rawSource = json['source'];
    final source = _parseSource(rawSource);

    return ParsedMarketplacePlugin(
      name: name,
      displayName: _string(json['displayName'])?.trim(),
      description: _string(json['description'])?.trim() ?? '',
      author: _authorName(json['author']),
      category: _string(json['category'])?.trim(),
      homepage: _string(json['homepage'])?.trim(),
      version: _string(json['version'])?.trim(),
      source: source,
    );
  }

  PluginSource _parseSource(Object? raw) {
    if (raw is String) {
      return PluginSource(
        kind: MarketplaceSourceKind.path,
        path: raw,
        rawJson: jsonEncode(raw),
      );
    }

    if (raw is Map) {
      final map = Map<String, Object?>.from(raw);
      final kind = _string(map['source'])?.trim();
      final parsedKind = switch (kind) {
        'path' => MarketplaceSourceKind.path,
        'git-subdir' => MarketplaceSourceKind.gitSubdir,
        'url' => MarketplaceSourceKind.url,
        'command' => MarketplaceSourceKind.command,
        _ => MarketplaceSourceKind.unsupported,
      };
      return PluginSource(
        kind: parsedKind,
        rawJson: jsonEncode(map),
        url: _string(map['url'])?.trim(),
        path: _string(map['path'])?.trim(),
        ref: _string(map['ref'])?.trim(),
        sha: _string(map['sha'])?.trim(),
      );
    }

    return PluginSource(
      kind: MarketplaceSourceKind.unsupported,
      rawJson: jsonEncode(raw),
    );
  }

  String? _authorName(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final name = _string(value['name']);
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }
    return null;
  }

  String? _string(Object? value) {
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }
}
