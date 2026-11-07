import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/app_release.dart';
import '../../domain/entities/update_failure.dart';

export '../../domain/entities/update_failure.dart';

/// Reads stable AgentPort releases from the public GitHub Releases API.
class GitHubReleaseClient {
  GitHubReleaseClient({
    this.client,
    Uri? releasesUri,
    this.timeout = const Duration(seconds: 20),
  }) : releasesUri = releasesUri ?? Uri.parse(defaultReleasesUrl);

  /// The endpoint used to list recent releases.
  static const defaultReleasesUrl =
      'https://api.github.com/repos/IWatman/AgentPort/releases?per_page=20';

  static const _accept = 'application/vnd.github+json';
  static const _apiVersion = '2022-11-28';

  final http.Client? client;
  final Uri releasesUri;
  final Duration timeout;

  /// Returns the newest stable release when it is newer than [currentVersion].
  ///
  /// Draft and pre-release entries are ignored. A release is selected by its
  /// `published_at` timestamp. The method returns `null` when there is no
  /// stable release or when the newest stable release is not newer than the
  /// installed version.
  Future<AppRelease?> latestStable({
    required String currentVersion,
    http.Client? client,
  }) async {
    final activeClient = client ?? this.client ?? http.Client();
    final ownsClient = client == null && this.client == null;

    try {
      final response = await activeClient
          .get(
            releasesUri,
            headers: {
              'Accept': _accept,
              'X-GitHub-Api-Version': _apiVersion,
              'User-Agent': _userAgent(currentVersion),
            },
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _failureForResponse(response);
      }

      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const UpdateFailure(
          UpdateFailureKind.invalidResponse,
          detail: 'GitHub returned malformed JSON.',
        );
      }

      if (decoded is! List) {
        throw const UpdateFailure(
          UpdateFailureKind.invalidResponse,
          detail: 'GitHub did not return a release list.',
        );
      }

      AppRelease? latest;
      for (final value in decoded) {
        if (value is! Map) {
          continue;
        }
        final release = AppRelease.fromGitHubJson(
          Map<String, Object?>.from(value),
        );
        if (release == null) {
          continue;
        }
        if (latest == null || _publishedAfter(release, latest)) {
          latest = release;
        }
      }

      if (latest == null || !latest.isNewerThan(currentVersion)) {
        return null;
      }
      return latest;
    } on UpdateFailure {
      rethrow;
    } on TimeoutException {
      throw const UpdateFailure(
        UpdateFailureKind.timeout,
        detail: 'GitHub did not respond in time.',
      );
    } on http.ClientException catch (error) {
      throw UpdateFailure(UpdateFailureKind.network, detail: error.message);
    } on IOException catch (error) {
      throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
    } on Exception catch (error) {
      throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
    } finally {
      if (ownsClient) {
        activeClient.close();
      }
    }
  }

  String _userAgent(String currentVersion) {
    final version = currentVersion.trim();
    return 'AgentPort/${version.isEmpty ? 'unknown' : version}';
  }

  bool _publishedAfter(AppRelease candidate, AppRelease current) {
    final candidateDate = candidate.publishedAt;
    if (candidateDate == null) {
      return false;
    }
    final currentDate = current.publishedAt;
    return currentDate == null || candidateDate.isAfter(currentDate);
  }

  UpdateFailure _failureForResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode == 403 || statusCode == 429) {
      return UpdateFailure(
        UpdateFailureKind.rateLimited,
        statusCode: statusCode,
        detail: _rateLimitDetail(response),
      );
    }
    return UpdateFailure(
      UpdateFailureKind.server,
      statusCode: statusCode,
      detail: 'GitHub Releases returned HTTP $statusCode.',
    );
  }

  String _rateLimitDetail(http.Response response) {
    final parts = <String>['GitHub rate limit exceeded.'];

    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    if (retryAfter != null && retryAfter >= 0) {
      parts.add('Try again in $retryAfter seconds.');
    } else if (reset != null && reset > 0) {
      final resetTime = DateTime.fromMillisecondsSinceEpoch(
        reset * 1000,
        isUtc: true,
      ).toLocal();
      parts.add('Try again after ${resetTime.toIso8601String()}.');
    } else {
      parts.add('Try again later.');
    }

    final message = _messageFromBody(response.body);
    if (message != null) {
      parts.add(message);
    }
    return parts.join(' ');
  }

  String? _messageFromBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Ignore non-JSON error bodies.
    }
    return null;
  }
}

/// Convenience wrapper around [GitHubReleaseClient.latestStable] for one-off
/// update checks.
Future<AppRelease?> latestStable({
  required String currentVersion,
  http.Client? client,
  Duration timeout = const Duration(seconds: 20),
}) {
  return GitHubReleaseClient(
    client: client,
    timeout: timeout,
  ).latestStable(currentVersion: currentVersion);
}
