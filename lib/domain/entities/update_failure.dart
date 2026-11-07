/// Categories of failures that can happen while checking for or downloading an
/// update.
enum UpdateFailureKind {
  /// The device could not reach GitHub.
  network,

  /// GitHub or the download server did not respond in time.
  timeout,

  /// The server returned an unexpected HTTP status.
  server,

  /// GitHub rejected the request because the API rate limit was exceeded.
  rateLimited,

  /// The server response was missing data or was malformed.
  invalidResponse,

  /// The downloaded file did not match the published checksum.
  checksum,
}

/// A typed failure raised by the update data layer.
class UpdateFailure implements Exception {
  const UpdateFailure(this.kind, {this.detail, this.statusCode});

  final UpdateFailureKind kind;

  /// A user-presentable explanation, when one is available.
  final String? detail;

  /// The HTTP status code associated with the failure, when applicable.
  final int? statusCode;

  @override
  String toString() {
    return detail == null ? kind.name : '${kind.name}: $detail';
  }
}
