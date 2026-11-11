/// Authentication choices use stable values independent of enum names.
enum ProviderAuthMethod {
  apiKey('api_key', null),
  chatGpt('chatgpt', 'https://api.openai.com/v1'),
  openRouter('openrouter', 'https://openrouter.ai/api/v1');

  const ProviderAuthMethod(this.storageValue, this.baseUrl);

  final String storageValue;
  final String? baseUrl;

  static ProviderAuthMethod fromStorage(String value) => switch (value) {
    'chatgpt' => chatGpt,
    'openrouter' => openRouter,
    _ => apiKey,
  };

  /// OAuth credentials must never be sent to a user-configured API endpoint.
  bool allowsBaseUrl(String value) {
    if (this == apiKey) return true;
    final uri = Uri.tryParse(value);
    final expected = Uri.parse(baseUrl!);
    return uri != null &&
        uri.scheme == expected.scheme &&
        uri.host == expected.host &&
        uri.port == expected.port &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path == expected.path || uri.path == '${expected.path}/');
  }
}

/// Sensitive data: serialize only into protected storage, never into backups,
/// logs, provider configuration, or analytics.
class ProviderOAuthCredential {
  ProviderOAuthCredential({
    required this.method,
    required this.accessToken,
    this.clientId,
    this.hostId,
    this.subject,
    this.email,
    this.issuer,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
    List<String> scopes = const [],
  }) : scopes = List.unmodifiable(scopes);

  final ProviderAuthMethod method;
  final String? clientId;
  final String? hostId;
  final String? subject;
  final String? email;
  final String? issuer;
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
  final List<String> scopes;

  Map<String, Object?> toJson() => {
    'method': method.storageValue,
    'client_id': clientId,
    'ext_agent_host_id': hostId,
    'subject': subject,
    'email': email,
    'issuer': issuer,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'id_token': idToken,
    'expires_at': expiresAt?.toUtc().toIso8601String(),
    'scopes': scopes,
  };

  factory ProviderOAuthCredential.fromJson(Map<String, Object?> json) {
    final method = ProviderAuthMethod.fromStorage(json['method'] as String);
    if (method == ProviderAuthMethod.apiKey) {
      throw const FormatException('Invalid OAuth credential method.');
    }
    final token = json['access_token'] as String;
    if (token.isEmpty) {
      throw const FormatException('Missing OAuth credential.');
    }
    return ProviderOAuthCredential(
      method: method,
      clientId: json['client_id'] as String?,
      hostId: json['ext_agent_host_id'] as String?,
      subject: json['subject'] as String?,
      email: json['email'] as String?,
      issuer: json['issuer'] as String?,
      accessToken: token,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String).toUtc(),
      scopes: (json['scopes'] as List<Object?>? ?? const []).cast<String>(),
    );
  }

  @override
  String toString() =>
      'ProviderOAuthCredential(${method.storageValue}, redacted)';
}
