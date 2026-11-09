/// Marketplace and MCP plugin domain model.
///
/// The shapes mirror the Claude plugin marketplace schema. Only remote MCP
/// servers are installable on Android; command-based servers are catalogued but
/// marked unsupported.
library;

enum MarketplaceSourceKind {
  path,
  gitSubdir,
  url,
  command,
  unsupported;

  static MarketplaceSourceKind fromStorage(String value) {
    return switch (value) {
      'path' => MarketplaceSourceKind.path,
      'git-subdir' => MarketplaceSourceKind.gitSubdir,
      'url' => MarketplaceSourceKind.url,
      'command' => MarketplaceSourceKind.command,
      _ => MarketplaceSourceKind.unsupported,
    };
  }

  String get storageValue => switch (this) {
    MarketplaceSourceKind.path => 'path',
    MarketplaceSourceKind.gitSubdir => 'git-subdir',
    MarketplaceSourceKind.url => 'url',
    MarketplaceSourceKind.command => 'command',
    MarketplaceSourceKind.unsupported => 'unsupported',
  };
}

class PluginSource {
  const PluginSource({
    required this.kind,
    required this.rawJson,
    this.url,
    this.path,
    this.ref,
    this.sha,
  });

  final MarketplaceSourceKind kind;
  final String rawJson;
  final String? url;
  final String? path;
  final String? ref;
  final String? sha;
}

enum PluginMcpStatus {
  unknown,
  none,
  remote,
  stdio,
  mixed,
  unsupported,
  error;

  static PluginMcpStatus fromStorage(String value) {
    return PluginMcpStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PluginMcpStatus.unknown,
    );
  }

  String get storageValue => name;

  bool get hasRemoteServers =>
      this == PluginMcpStatus.remote || this == PluginMcpStatus.mixed;
}

enum McpTransport {
  http,
  sse;

  static McpTransport? fromValue(String? value) {
    return switch (value?.toLowerCase()) {
      'http' || 'streamable-http' || 'streamable_http' => McpTransport.http,
      'sse' => McpTransport.sse,
      _ => null,
    };
  }

  String get storageValue => name;
}

enum McpAuthType {
  oauth,
  apiKey,
  none,
  unknown;

  static McpAuthType fromStorage(String value) {
    return switch (value) {
      'oauth' => McpAuthType.oauth,
      'api-key' => McpAuthType.apiKey,
      'none' => McpAuthType.none,
      _ => McpAuthType.unknown,
    };
  }

  String get storageValue => switch (this) {
    McpAuthType.oauth => 'oauth',
    McpAuthType.apiKey => 'api-key',
    McpAuthType.none => 'none',
    McpAuthType.unknown => 'unknown',
  };
}

enum TrustLevel { anthropic, verifiedPartner, community }

class Marketplace {
  const Marketplace({
    required this.id,
    required this.name,
    required this.description,
    required this.sourceUrl,
    required this.manifestUrl,
    required this.builtIn,
    required this.enabled,
    required this.createdAt,
    this.pluginCount = 0,
    this.lastSyncedAt,
    this.lastError,
    this.etag,
  });

  final String id;
  final String name;
  final String description;
  final String sourceUrl;
  final String manifestUrl;
  final bool builtIn;
  final bool enabled;
  final int pluginCount;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final String? etag;
  final DateTime createdAt;

  Marketplace copyWith({
    String? name,
    String? description,
    String? manifestUrl,
    int? pluginCount,
    DateTime? lastSyncedAt,
    String? lastError,
    String? etag,
    bool clearError = false,
  }) {
    return Marketplace(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceUrl: sourceUrl,
      manifestUrl: manifestUrl ?? this.manifestUrl,
      builtIn: builtIn,
      enabled: enabled,
      pluginCount: pluginCount ?? this.pluginCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      etag: etag ?? this.etag,
      createdAt: createdAt,
    );
  }
}

class MarketplacePlugin {
  const MarketplacePlugin({
    required this.id,
    required this.marketplaceId,
    required this.marketplaceName,
    required this.name,
    required this.description,
    required this.source,
    required this.installed,
    required this.enabled,
    required this.mcpStatus,
    required this.lastSeenAt,
    this.displayName,
    this.author,
    this.category,
    this.homepage,
    this.version,
    this.servers = const [],
    this.installedServers = const [],
    this.mcpCheckedAt,
    this.needsReconsent = false,
    this.lastError,
  });

  final String id;
  final String marketplaceId;
  final String marketplaceName;
  final String name;
  final String? displayName;
  final String description;
  final String? author;
  final String? category;
  final String? homepage;
  final String? version;
  final PluginSource source;
  final bool installed;
  final bool enabled;
  final PluginMcpStatus mcpStatus;
  final List<McpServerConfig> servers;

  /// Servers captured when the plugin was installed or re-consented. This is
  /// the baseline for detecting configuration changes.
  final List<McpServerConfig> installedServers;
  final DateTime? mcpCheckedAt;
  final bool needsReconsent;
  final String? lastError;
  final DateTime lastSeenAt;

  String get title =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : name;

  String get qualifiedName => '$name@$marketplaceName';

  bool get hasRemoteServers => mcpStatus.hasRemoteServers;

  bool get supportsAndroid => hasRemoteServers;

  /// Whether the plugin should be listed on Android. Installed plugins stay
  /// visible so they can be managed or removed even if a catalog changed.
  bool get isAvailableOnAndroid => installed || supportsAndroid;

  TrustLevel get trustLevel {
    // Trust is determined by the marketplace we resolved the plugin from, not
    // by free-text author fields that a manifest can spoof.
    if (marketplaceId != kOfficialMarketplaceId) {
      return TrustLevel.community;
    }
    final normalized = author?.trim().toLowerCase();
    return normalized == 'anthropic'
        ? TrustLevel.anthropic
        : TrustLevel.verifiedPartner;
  }
}

/// One MCP server declaration from `.mcp.json`.
class McpServerConfig {
  const McpServerConfig({
    required this.name,
    required this.transport,
    required this.url,
    required this.authType,
    this.headerNames = const [],
    this.headerTemplates = const {},
    this.rawJson = const {},
  });

  final String name;
  final McpTransport transport;
  final String url;
  final McpAuthType authType;
  final List<String> headerNames;

  /// Header names mapped to non-secret `${VAR}` templates declared by the
  /// marketplace. Literal header values are never retained.
  final Map<String, String> headerTemplates;
  final Map<String, Object?> rawJson;

  bool get isRemote => url.isNotEmpty;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': transport.storageValue,
    'url': url,
    'authType': authType.storageValue,
    if (headerNames.isNotEmpty) 'headerNames': headerNames,
    if (headerTemplates.isNotEmpty) 'headerTemplates': headerTemplates,
  };

  static McpServerConfig? fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final url = json['url'];
    if (name is! String || url is! String || url.isEmpty) {
      return null;
    }
    final transport = McpTransport.fromValue(json['type'] as String?);
    final auth = McpAuthType.fromStorage(
      (json['authType'] as String?) ?? 'unknown',
    );
    final headers = (json['headerNames'] as List<Object?>?)
        ?.whereType<String>()
        .toList(growable: false);
    final templates = <String, String>{};
    final rawTemplates = json['headerTemplates'];
    if (rawTemplates is Map) {
      for (final entry in rawTemplates.entries) {
        if (entry.key is String && entry.value is String) {
          templates[entry.key! as String] = entry.value! as String;
        }
      }
    }
    return McpServerConfig(
      name: name,
      transport: transport ?? McpTransport.http,
      url: url,
      authType: auth,
      headerNames: headers ?? const [],
      headerTemplates: Map.unmodifiable(templates),
    );
  }
}

/// Metadata resolved from a plugin's `.mcp.json`.
class PluginMcpMetadata {
  const PluginMcpMetadata({
    required this.status,
    this.servers = const [],
    this.unsupportedServers = const [],
    this.error,
  });

  final PluginMcpStatus status;
  final List<McpServerConfig> servers;

  /// Server names that use stdio or unknown transports.
  final List<String> unsupportedServers;
  final String? error;

  static const unknown = PluginMcpMetadata(status: PluginMcpStatus.unknown);
}

class MarketplaceCatalog {
  const MarketplaceCatalog({required this.marketplaces, required this.plugins});

  final List<Marketplace> marketplaces;
  final List<MarketplacePlugin> plugins;

  List<MarketplacePlugin> get installed =>
      plugins.where((plugin) => plugin.installed).toList(growable: false);
}

/// Failure categories exposed by the marketplace layer.
class MarketplaceFailure implements Exception {
  const MarketplaceFailure(this.kind, [this.details]);

  final MarketplaceFailureKind kind;
  final String? details;

  @override
  String toString() => details == null ? kind.name : '${kind.name}: $details';
}

enum MarketplaceFailureKind {
  invalidInput,
  network,
  notFound,
  invalidManifest,
  noRemoteMcp,
  unsupportedSource,
  unsupportedPlatform,
  duplicate,
  needsReconsent,
  storage,
}

const kOfficialMarketplaceId = 'builtin.claude-plugins-official';
const kOfficialMarketplaceSource =
    'https://github.com/anthropics/claude-plugins-official';
const kOfficialMarketplaceManifest =
    'https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json';
