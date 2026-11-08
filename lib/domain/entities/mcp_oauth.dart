/// OAuth credentials for one MCP server.
///
/// The token set is persisted in the Android Keystore as JSON; secret values
/// never enter the database.
class McpOAuthToken {
  const McpOAuthToken({
    required this.accessToken,
    required this.tokenEndpoint,
    required this.clientId,
    this.refreshToken,
    this.clientSecret,
    this.expiresAt,
    this.scope,
    this.resource,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String tokenEndpoint;
  final String clientId;
  final String? clientSecret;
  final String? scope;
  final String? resource;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return expiry.isBefore(DateTime.now().add(const Duration(seconds: 60)));
  }

  McpOAuthToken copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? scope,
  }) {
    return McpOAuthToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenEndpoint: tokenEndpoint,
      clientId: clientId,
      clientSecret: clientSecret,
      scope: scope ?? this.scope,
      resource: resource,
    );
  }

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt?.millisecondsSinceEpoch,
    'token_endpoint': tokenEndpoint,
    'client_id': clientId,
    'client_secret': clientSecret,
    'scope': scope,
    'resource': resource,
  };

  static McpOAuthToken? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(value);
    final accessToken = map['access_token'];
    final tokenEndpoint = map['token_endpoint'];
    final clientId = map['client_id'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        tokenEndpoint is! String ||
        tokenEndpoint.isEmpty ||
        clientId is! String ||
        clientId.isEmpty) {
      return null;
    }
    final expiry = map['expires_at'];
    return McpOAuthToken(
      accessToken: accessToken,
      refreshToken: map['refresh_token'] is String
          ? map['refresh_token'] as String
          : null,
      expiresAt: expiry is int
          ? DateTime.fromMillisecondsSinceEpoch(expiry)
          : null,
      tokenEndpoint: tokenEndpoint,
      clientId: clientId,
      clientSecret: map['client_secret'] is String
          ? map['client_secret'] as String
          : null,
      scope: map['scope'] is String ? map['scope'] as String : null,
      resource: map['resource'] is String ? map['resource'] as String : null,
    );
  }
}
