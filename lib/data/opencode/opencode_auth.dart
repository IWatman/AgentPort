import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/opencode.dart';
import 'opencode_endpoints.dart';

/// Redeems a single-use OpenCode pairing code for an access token.
class OpenCodeAuth {
  OpenCodeAuth({OpenCodeHttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const requestTimeout = Duration(seconds: 20);

  final OpenCodeHttpClientFactory _clientFactory;

  /// Exchanges [code] for a token at `GET /auth/connect/:code`.
  ///
  /// When [client] is provided the caller owns it and this method does not
  /// close it.
  Future<String> redeem({
    required String baseUrl,
    required String code,
    http.Client? client,
  }) async {
    final uri = openCodeConnectUri(baseUrl, code);
    final ownedClient = client == null;
    final httpClient = client ?? _clientFactory();

    try {
      final request = http.Request('GET', uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        });

      final streamed = await httpClient.send(request).timeout(requestTimeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failureFor(response.statusCode, response.body);
      }

      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidResponse,
          detail: 'The OpenCode server returned malformed JSON.',
        );
      }
      if (decoded is! Map) {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidResponse,
          detail: 'The OpenCode server did not return a token.',
        );
      }
      final token = decoded['token'];
      if (token is! String || token.trim().isEmpty) {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidResponse,
          detail: 'The OpenCode server did not return a token.',
        );
      }
      return token;
    } on OpenCodeFailure {
      rethrow;
    } on TimeoutException {
      throw const OpenCodeFailure(
        OpenCodeFailureKind.timeout,
        detail: 'The OpenCode server took too long to respond.',
      );
    } on IOException catch (error) {
      throw OpenCodeFailure(
        OpenCodeFailureKind.network,
        detail: error.toString(),
      );
    } on http.ClientException catch (error) {
      throw OpenCodeFailure(OpenCodeFailureKind.network, detail: error.message);
    } finally {
      if (ownedClient) {
        httpClient.close();
      }
    }
  }

  OpenCodeFailure _failureFor(int statusCode, String body) {
    final kind = switch (statusCode) {
      401 || 403 || 404 => OpenCodeFailureKind.unauthorized,
      408 || 504 => OpenCodeFailureKind.timeout,
      >= 500 => OpenCodeFailureKind.server,
      _ => OpenCodeFailureKind.invalidResponse,
    };
    return OpenCodeFailure(
      kind,
      statusCode: statusCode,
      detail: statusCode == 404
          ? 'The pairing code is invalid or has expired.'
          : _errorDetail(body),
    );
  }

  String? _errorDetail(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } on FormatException {
      // Fall through to the raw body.
    }
    return body.length > 300 ? body.substring(0, 300) : body;
  }
}
