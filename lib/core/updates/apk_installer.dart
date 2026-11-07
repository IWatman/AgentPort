import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reason an APK installation could not be started.
enum ApkInstallFailureKind {
  permissionDenied,
  fileNotFound,
  invalidFile,
  installFailed,
  unsupportedPlatform,
}

/// A typed failure raised when the APK installer cannot complete a request.
class ApkInstallFailure implements Exception {
  const ApkInstallFailure(this.kind, this.message);

  final ApkInstallFailureKind kind;
  final String message;

  @override
  String toString() => 'ApkInstallFailure(${kind.name}): $message';
}

/// Installs downloaded APKs through the native Android package installer.
///
/// Only Android is supported. The [isAndroid] override exists for tests running on the Dart VM.
class ApkInstaller {
  ApkInstaller({MethodChannel? channel, bool? isAndroid})
    : _channel =
          channel ?? const MethodChannel('com.iwatman.agentport/installer'),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _isAndroid;

  /// Whether the user has allowed this app to install unknown packages.
  Future<bool> canInstallPackages() async {
    _ensureSupported();
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on MissingPluginException {
      throw const ApkInstallFailure(
        ApkInstallFailureKind.installFailed,
        'The APK installer is not available on this device.',
      );
    }
  }

  /// Opens the system screen that allows this app to install unknown packages.
  Future<void> openInstallSettings() async {
    _ensureSupported();
    try {
      await _channel.invokeMethod<bool>('openInstallSettings');
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on MissingPluginException {
      throw const ApkInstallFailure(
        ApkInstallFailureKind.installFailed,
        'The APK installer is not available on this device.',
      );
    }
  }

  /// Starts the installation of [apk].
  ///
  /// The returned future completes once the platform reports a successful install or when the
  /// system package installer screen has been opened as a fallback.
  Future<void> install(File apk) async {
    _ensureSupported();
    if (!await apk.exists()) {
      throw ApkInstallFailure(
        ApkInstallFailureKind.fileNotFound,
        'The APK file does not exist: ${apk.path}',
      );
    }
    if (!apk.path.toLowerCase().endsWith('.apk')) {
      throw ApkInstallFailure(
        ApkInstallFailureKind.invalidFile,
        'The selected file is not an APK: ${apk.path}',
      );
    }

    try {
      await _channel.invokeMethod<void>('installApk', apk.path);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    } on MissingPluginException {
      throw const ApkInstallFailure(
        ApkInstallFailureKind.installFailed,
        'The APK installer is not available on this device.',
      );
    }
  }

  void _ensureSupported() {
    if (_isAndroid) {
      return;
    }
    throw const ApkInstallFailure(
      ApkInstallFailureKind.unsupportedPlatform,
      'APK installation is only supported on Android.',
    );
  }

  ApkInstallFailure _mapPlatformException(PlatformException error) {
    final kind = switch (error.code) {
      'permission_denied' => ApkInstallFailureKind.permissionDenied,
      'file_not_found' => ApkInstallFailureKind.fileNotFound,
      'invalid_file' => ApkInstallFailureKind.invalidFile,
      _ => ApkInstallFailureKind.installFailed,
    };
    return ApkInstallFailure(
      kind,
      error.message ?? 'The APK installer failed (${error.code}).',
    );
  }
}

/// Provides the APK installer used by the in-app updater.
final apkInstallerProvider = Provider<ApkInstaller>((ref) => ApkInstaller());
