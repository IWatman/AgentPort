import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/marketplace.dart';
import 'marketplace_manifest_parser.dart';
import 'marketplace_sources.dart';
import 'mcp_manifest_parser.dart';

class MarketplaceHttpResponse {
  const MarketplaceHttpResponse({
    required this.statusCode,
    this.body,
    this.etag,
  });

  final int statusCode;
  final String? body;
  final String? etag;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  bool get isNotModified => statusCode == 304;

  bool get isNotFound => statusCode == 404;
}

class RemoteMarketplace {
  const RemoteMarketplace({
    required this.reference,
    required this.manifestUrl,
    required this.manifest,
    this.etag,
  });

  final MarketplaceReference reference;
  final String manifestUrl;
  final ParsedMarketplace manifest;
  final String? etag;
}

class MarketplaceApi {
  MarketplaceApi({
    http.Client? client,
    MarketplaceSourceResolver? sourceResolver,
    MarketplaceManifestParser? manifestParser,
    McpManifestParser? mcpParser,
  }) : _client = client ?? http.Client(),
       _sources = sourceResolver ?? const MarketplaceSourceResolver(),
       _manifests = manifestParser ?? const MarketplaceManifestParser(),
       _mcp = mcpParser ?? const McpManifestParser();

  final http.Client _client;
  final MarketplaceSourceResolver _sources;
  final MarketplaceManifestParser _manifests;
  final McpManifestParser _mcp;

  static const _timeout = Duration(seconds: 20);
  static const _maxPayloadBytes = 4 * 1024 * 1024;

  MarketplaceSourceResolver get sources => _sources;

  Future<MarketplaceHttpResponse> get(String url, {String? etag}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent':
                  'AgentPort/0.1 (+https://github.com/IWatman/AgentPort)',
              if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
            },
          )
          .timeout(_timeout);
      if (response.contentLength != null &&
          response.contentLength! > _maxPayloadBytes) {
        throw const MarketplaceFailure(
          MarketplaceFailureKind.invalidManifest,
          'The response is too large.',
        );
      }
      if (response.bodyBytes.length > _maxPayloadBytes) {
        throw const MarketplaceFailure(
          MarketplaceFailureKind.invalidManifest,
          'The response is too large.',
        );
      }
      return MarketplaceHttpResponse(
        statusCode: response.statusCode,
        body: utf8.decode(response.bodyBytes),
        etag: response.headers['etag'],
      );
    } on TimeoutException {
      throw const MarketplaceFailure(
        MarketplaceFailureKind.network,
        'The request timed out.',
      );
    } catch (error) {
      if (error is MarketplaceFailure) {
        rethrow;
      }
      throw MarketplaceFailure(
        MarketplaceFailureKind.network,
        error.toString(),
      );
    }
  }

  Future<RemoteMarketplace?> fetchManifest(
    MarketplaceReference reference, {
    String? etag,
  }) async {
    MarketplaceFailure? lastFailure;
    for (final url in reference.manifestUrls) {
      final response = await get(url, etag: etag);
      if (response.isNotModified) {
        return null;
      }
      if (response.isNotFound) {
        lastFailure = MarketplaceFailure(
          MarketplaceFailureKind.notFound,
          'No marketplace manifest at $url',
        );
        continue;
      }
      if (!response.isSuccess) {
        throw MarketplaceFailure(
          MarketplaceFailureKind.network,
          'HTTP ${response.statusCode} for $url',
        );
      }
      final body = response.body;
      if (body == null) {
        throw const MarketplaceFailure(
          MarketplaceFailureKind.invalidManifest,
          'The manifest response was empty.',
        );
      }
      final manifest = _manifests.parse(body);
      return RemoteMarketplace(
        reference: reference,
        manifestUrl: url,
        manifest: manifest,
        etag: response.etag,
      );
    }

    throw lastFailure ??
        const MarketplaceFailure(
          MarketplaceFailureKind.notFound,
          'No marketplace manifest found.',
        );
  }

  Future<PluginMcpMetadata> fetchMcpMetadata({
    required Marketplace marketplace,
    required PluginSource source,
  }) async {
    if (source.kind == MarketplaceSourceKind.command) {
      return const PluginMcpMetadata(
        status: PluginMcpStatus.unsupported,
        error: 'This plugin is provided by a local command.',
      );
    }

    final url = _sources.rawFileUrl(
      source: source,
      marketplace: marketplace,
      fileName: '.mcp.json',
    );
    if (url == null) {
      return const PluginMcpMetadata(
        status: PluginMcpStatus.unsupported,
        error: 'Unsupported plugin source host.',
      );
    }

    try {
      final response = await get(url);
      if (response.isNotFound) {
        return const PluginMcpMetadata(status: PluginMcpStatus.none);
      }
      if (!response.isSuccess) {
        return PluginMcpMetadata(
          status: PluginMcpStatus.error,
          error: 'HTTP ${response.statusCode}',
        );
      }
      final body = response.body;
      if (body == null || body.trim().isEmpty) {
        return const PluginMcpMetadata(status: PluginMcpStatus.none);
      }
      return _mcp.parse(body);
    } on MarketplaceFailure catch (error) {
      return PluginMcpMetadata(
        status: PluginMcpStatus.error,
        error: error.details ?? error.kind.name,
      );
    }
  }

  String configHash(List<McpServerConfig> servers) => _mcp.configHash(servers);

  void close() => _client.close();
}

final marketplaceApiProvider = Provider<MarketplaceApi>((ref) {
  final api = MarketplaceApi();
  ref.onDispose(api.close);
  return api;
});
