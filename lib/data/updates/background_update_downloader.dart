import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/update_failure.dart';

enum BackgroundDownloadPhase {
  pending,
  running,
  paused,
  successful,
  failed,
  unknown;

  static BackgroundDownloadPhase fromValue(Object? value) {
    return switch (value) {
      'pending' => BackgroundDownloadPhase.pending,
      'running' => BackgroundDownloadPhase.running,
      'paused' => BackgroundDownloadPhase.paused,
      'successful' => BackgroundDownloadPhase.successful,
      'failed' => BackgroundDownloadPhase.failed,
      _ => BackgroundDownloadPhase.unknown,
    };
  }
}

class BackgroundDownloadStatus {
  const BackgroundDownloadStatus({
    required this.phase,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.path,
    this.reason,
  });

  final BackgroundDownloadPhase phase;
  final int downloadedBytes;
  final int? totalBytes;
  final String? path;
  final int? reason;

  bool get isFinished =>
      phase == BackgroundDownloadPhase.successful ||
      phase == BackgroundDownloadPhase.failed;
}

/// Starts and queries APK downloads handled by Android's DownloadManager.
///
/// DownloadManager is a system service, so the transfer keeps running while
/// the screen is off or the app is in the background.
class BackgroundUpdateDownloader {
  BackgroundUpdateDownloader({MethodChannel? channel, bool? isAndroid})
    : _channel =
          channel ?? const MethodChannel('com.iwatman.agentport/downloader'),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _isAndroid;

  Future<int> enqueue({
    required String url,
    required String fileName,
    required String title,
    required String description,
  }) async {
    _ensureSupported();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'enqueue',
        {
          'url': url,
          'fileName': fileName,
          'title': title,
          'description': description,
        },
      );
      final id = result?['id'];
      if (id is int) {
        return id;
      }
      throw const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'Android did not return a download id.',
      );
    } on PlatformException catch (error) {
      throw UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.message ?? error.code,
      );
    } on MissingPluginException {
      throw const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'The background downloader is not available on this device.',
      );
    }
  }

  Future<BackgroundDownloadStatus> query({
    required int id,
    required String fileName,
  }) async {
    _ensureSupported();
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('query', {
        'id': id,
        'fileName': fileName,
      });
      if (result == null) {
        return const BackgroundDownloadStatus(
          phase: BackgroundDownloadPhase.unknown,
        );
      }
      return BackgroundDownloadStatus(
        phase: BackgroundDownloadPhase.fromValue(result['status']),
        downloadedBytes: _readInt(result['downloaded']) ?? 0,
        totalBytes: _readInt(result['total']),
        path: result['path'] is String ? result['path'] as String : null,
        reason: _readInt(result['reason']),
      );
    } on PlatformException catch (error) {
      throw UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.message ?? error.code,
      );
    } on MissingPluginException {
      throw const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'The background downloader is not available on this device.',
      );
    }
  }

  Future<void> remove(int id) async {
    _ensureSupported();
    try {
      await _channel.invokeMethod<void>('remove', {'id': id});
    } on PlatformException catch (error) {
      throw UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.message ?? error.code,
      );
    } on MissingPluginException {
      // Nothing to remove when the platform implementation is absent.
    }
  }

  void _ensureSupported() {
    if (!_isAndroid) {
      throw const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'Background update downloads are only supported on Android.',
      );
    }
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

final backgroundUpdateDownloaderProvider = Provider<BackgroundUpdateDownloader>(
  (ref) => BackgroundUpdateDownloader(),
);
