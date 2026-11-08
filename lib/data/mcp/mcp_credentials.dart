import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/secure_store.dart';
import '../../domain/entities/mcp_oauth.dart';

/// Stores MCP header values in the Android Keystore.
///
/// Database rows only keep header names and non-secret templates.
class McpCredentialStore {
  McpCredentialStore(this._secureStore);

  final SecureStore _secureStore;

  String _key(String serverId) => 'agentport.mcp.$serverId.headers.v1';

  String _oauthKey(String serverId) => 'agentport.mcp.$serverId.oauth.v1';

  Future<Map<String, String>> headers(String serverId) async {
    final raw = await _secureStore.read(_key(serverId));
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const {};
      }
      final result = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is String && entry.value is String) {
          result[entry.key! as String] = entry.value! as String;
        }
      }
      return result;
    } on FormatException {
      return const {};
    }
  }

  Future<void> saveHeaders(String serverId, Map<String, String> headers) async {
    await _secureStore.write(_key(serverId), jsonEncode(headers));
  }

  Future<void> deleteHeaders(String serverId) async {
    await _secureStore.delete(_key(serverId));
  }

  Future<McpOAuthToken?> oauthToken(String serverId) async {
    final raw = await _secureStore.read(_oauthKey(serverId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return McpOAuthToken.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> saveOAuthToken(String serverId, McpOAuthToken token) async {
    await _secureStore.write(_oauthKey(serverId), jsonEncode(token.toJson()));
  }

  Future<void> deleteOAuthToken(String serverId) async {
    await _secureStore.delete(_oauthKey(serverId));
  }
}

final mcpCredentialStoreProvider = Provider<McpCredentialStore>((ref) {
  return McpCredentialStore(ref.watch(secureStoreProvider));
});
