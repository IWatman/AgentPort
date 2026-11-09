import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../core/settings/settings_controller.dart';
import '../../core/updates/apk_installer.dart';
import '../../data/updates/background_update_downloader.dart';
import '../../data/updates/github_release_client.dart';
import '../../data/updates/release_downloader.dart';
import '../../domain/entities/app_release.dart';
import '../../domain/entities/pending_update_download.dart';

enum UpdatePhase { idle, checking, downloading, installing }

class UpdateState {
  const UpdateState({
    required this.currentVersion,
    this.release,
    this.phase = UpdatePhase.idle,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes,
    this.downloadedFile,
    this.checksumVerified = false,
    this.lastCheck,
    this.error,
    this.permissionNeeded = false,
  });

  final String currentVersion;
  final AppRelease? release;
  final UpdatePhase phase;
  final double progress;
  final int receivedBytes;
  final int? totalBytes;
  final File? downloadedFile;
  final bool checksumVerified;
  final DateTime? lastCheck;
  final UpdateFailure? error;
  final bool permissionNeeded;

  bool get isBusy =>
      phase == UpdatePhase.checking ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.installing;

  UpdateState copyWith({
    String? currentVersion,
    Object? release = _unset,
    UpdatePhase? phase,
    double? progress,
    int? receivedBytes,
    Object? totalBytes = _unset,
    Object? downloadedFile = _unset,
    bool? checksumVerified,
    Object? lastCheck = _unset,
    Object? error = _unset,
    bool? permissionNeeded,
  }) {
    return UpdateState(
      currentVersion: currentVersion ?? this.currentVersion,
      release: identical(release, _unset)
          ? this.release
          : release as AppRelease?,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: identical(totalBytes, _unset)
          ? this.totalBytes
          : totalBytes as int?,
      downloadedFile: identical(downloadedFile, _unset)
          ? this.downloadedFile
          : downloadedFile as File?,
      checksumVerified: checksumVerified ?? this.checksumVerified,
      lastCheck: identical(lastCheck, _unset)
          ? this.lastCheck
          : lastCheck as DateTime?,
      error: identical(error, _unset) ? this.error : error as UpdateFailure?,
      permissionNeeded: permissionNeeded ?? this.permissionNeeded,
    );
  }
}

const _unset = Object();

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final githubReleaseClientProvider = Provider<GitHubReleaseClient>(
  (ref) => GitHubReleaseClient(),
);

typedef ApkChecksumVerifier = Future<bool> Function(
  File file, {
  required String apkName,
  ReleaseAsset? checksumAsset,
});

final releaseVerifierProvider = Provider<ApkChecksumVerifier>(
  (ref) =>
      (file, {required apkName, checksumAsset}) => verifyDownloadedApk(
        file,
        apkName: apkName,
        checksumAsset: checksumAsset,
      ),
);

final updateDownloadPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 500),
);

final updateControllerProvider =
    AsyncNotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Checks GitHub Releases and drives the download/install flow.
class UpdateController extends AsyncNotifier<UpdateState> {
  var _monitoringDownload = false;

  @override
  Future<UpdateState> build() async {
    final info = await ref.watch(packageInfoProvider.future);
    final lastCheck = await ref
        .read(settingsRepositoryProvider)
        .loadLastUpdateCheck();
    final pending = await ref
        .read(settingsRepositoryProvider)
        .loadPendingUpdateDownload();
    final initial = UpdateState(
      currentVersion: info.version,
      lastCheck: lastCheck,
    );
    if (pending != null) {
      final pendingVersion = AppVersion.tryParse(pending.version);
      final currentVersion = AppVersion.tryParse(info.version);
      if (pendingVersion == null ||
          currentVersion == null ||
          !pendingVersion.isNewerThan(currentVersion)) {
        // The update was already installed or the metadata is stale.
        await ref.read(settingsRepositoryProvider).clearPendingUpdateDownload();
      } else {
        unawaited(_resumePendingDownload(pending));
        return initial.copyWith(phase: UpdatePhase.downloading);
      }
    }
    return initial;
  }

  Future<void> _resumePendingDownload(PendingUpdateDownload pending) async {
    // Let the provider publish the initial state before monitoring updates it.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!ref.mounted) {
      return;
    }
    await _monitorDownload(pending);
  }

  /// Checks for a newer stable release.
  ///
  /// Returns the newer release, or `null` when the installed version is current.
  Future<AppRelease?> check() async {
    final current = state.value;
    if (current == null || current.isBusy) {
      return current?.release;
    }

    state = AsyncData(
      current.copyWith(phase: UpdatePhase.checking, error: null),
    );
    try {
      final release = await ref
          .read(githubReleaseClientProvider)
          .latestStable(currentVersion: current.currentVersion);
      final now = DateTime.now();
      await ref.read(settingsRepositoryProvider).saveLastUpdateCheck(now);
      if (!ref.mounted) {
        return release;
      }
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          phase: UpdatePhase.idle,
          release: release,
          lastCheck: now,
          error: null,
        ),
      );
      return release;
    } on UpdateFailure catch (error) {
      _fail(error);
      rethrow;
    } catch (error) {
      final failure = UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.toString(),
      );
      _fail(failure);
      throw failure;
    }
  }

  /// Runs the automatic check at most once per day when enabled.
  Future<AppRelease?> checkIfDue() async {
    final settings = ref.read(settingsControllerProvider);
    if (!settings.autoUpdateCheck) {
      return null;
    }
    final current = state.value;
    if (current == null) {
      return null;
    }
    final lastCheck = current.lastCheck;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < const Duration(hours: 24)) {
      return null;
    }
    try {
      return await check();
    } on UpdateFailure {
      return null;
    }
  }

  /// Starts a system-managed background download and installs the APK when it
  /// completes. DownloadManager keeps running when the screen is off or the app
  /// is in the background.
  Future<void> downloadAndInstall() async {
    final current = state.value;
    final release = current?.release;
    if (current == null || release == null || current.isBusy) {
      return;
    }

    final asset = selectApkAsset(release.assets);
    if (asset == null) {
      final failure = const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'The release does not contain an APK asset.',
      );
      _fail(failure);
      throw failure;
    }
    final fileName = p.basename(asset.name);
    if (fileName.isEmpty || fileName == '.' || fileName == '..') {
      final failure = const UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: 'The APK asset has an invalid file name.',
      );
      _fail(failure);
      throw failure;
    }

    final installer = ref.read(apkInstallerProvider);
    final allowed = await installer.canInstallPackages();
    if (!allowed) {
      if (ref.mounted) {
        state = AsyncData(
          current.copyWith(
            permissionNeeded: true,
            phase: UpdatePhase.idle,
            error: null,
          ),
        );
      }
      return;
    }

    final settings = ref.read(settingsRepositoryProvider);
    final previous = await settings.loadPendingUpdateDownload();
    if (previous != null) {
      try {
        await ref.read(backgroundUpdateDownloaderProvider).remove(previous.id);
      } on UpdateFailure {
        // The system may already have removed the download.
      }
      await settings.clearPendingUpdateDownload();
    }

    state = AsyncData(
      current.copyWith(
        phase: UpdatePhase.downloading,
        progress: 0,
        receivedBytes: 0,
        totalBytes: null,
        downloadedFile: null,
        checksumVerified: false,
        permissionNeeded: false,
        error: null,
      ),
    );

    try {
      final id = await ref
          .read(backgroundUpdateDownloaderProvider)
          .enqueue(
            url: asset.downloadUrl,
            fileName: fileName,
            title: 'AgentPort update',
            description: 'Downloading AgentPort ${release.version}',
          );
      final pending = PendingUpdateDownload(
        id: id,
        version: release.version,
        fileName: fileName,
        checksumUrl: selectChecksumAsset(release.assets, fileName)?.downloadUrl,
      );
      try {
        await settings.savePendingUpdateDownload(pending);
      } catch (error) {
        try {
          await ref.read(backgroundUpdateDownloaderProvider).remove(id);
        } on UpdateFailure {
          // Best-effort cleanup.
        }
        rethrow;
      }
      await _monitorDownload(pending);
      final failure = state.value?.error;
      if (failure != null) {
        throw failure;
      }
    } on UpdateFailure catch (error) {
      _fail(error);
      rethrow;
    } on ApkInstallFailure catch (error) {
      final failure = UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.message,
      );
      _fail(failure);
      throw failure;
    } catch (error) {
      final failure = UpdateFailure(
        UpdateFailureKind.invalidResponse,
        detail: error.toString(),
      );
      _fail(failure);
      throw failure;
    }
  }

  Future<void> _monitorDownload(PendingUpdateDownload pending) async {
    if (_monitoringDownload) {
      return;
    }
    _monitoringDownload = true;
    final service = ref.read(backgroundUpdateDownloaderProvider);
    final installer = ref.read(apkInstallerProvider);
    final verifier = ref.read(releaseVerifierProvider);
    final settings = ref.read(settingsRepositoryProvider);
    final interval = ref.read(updateDownloadPollIntervalProvider);

    try {
      while (ref.mounted) {
        final status = await service.query(
          id: pending.id,
          fileName: pending.fileName,
        );
        if (!ref.mounted) {
          return;
        }
        switch (status.phase) {
          case BackgroundDownloadPhase.pending:
          case BackgroundDownloadPhase.running:
          case BackgroundDownloadPhase.paused:
            _publishProgress(status);
            await Future<void>.delayed(interval);
          case BackgroundDownloadPhase.successful:
            await _finishDownload(
              pending,
              status,
              installer: installer,
              verifier: verifier,
            );
            await settings.clearPendingUpdateDownload();
            return;
          case BackgroundDownloadPhase.failed:
            await settings.clearPendingUpdateDownload();
            try {
              await service.remove(pending.id);
            } on UpdateFailure {
              // Best-effort cleanup.
            }
            _fail(
              UpdateFailure(
                UpdateFailureKind.network,
                detail: status.reason == null
                    ? 'The background download failed.'
                    : 'The background download failed (code ${status.reason}).',
              ),
            );
            return;
          case BackgroundDownloadPhase.unknown:
            await settings.clearPendingUpdateDownload();
            _fail(
              const UpdateFailure(
                UpdateFailureKind.invalidResponse,
                detail:
                    'The background download was not found. Start the update '
                    'again.',
              ),
            );
            return;
        }
      }
    } on UpdateFailure catch (error) {
      await settings.clearPendingUpdateDownload();
      _fail(error);
    } on ApkInstallFailure catch (error) {
      await settings.clearPendingUpdateDownload();
      if (_isInstallCancelled(error)) {
        final current = state.value;
        if (current != null && ref.mounted) {
          state = AsyncData(
            current.copyWith(phase: UpdatePhase.idle, error: null),
          );
        }
      } else {
        _fail(
          UpdateFailure(
            UpdateFailureKind.invalidResponse,
            detail: error.message,
          ),
        );
      }
    } catch (error) {
      await settings.clearPendingUpdateDownload();
      _fail(
        UpdateFailure(
          UpdateFailureKind.invalidResponse,
          detail: error.toString(),
        ),
      );
    } finally {
      _monitoringDownload = false;
    }
  }

  void _publishProgress(BackgroundDownloadStatus status) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final total = status.totalBytes;
    state = AsyncData(
      current.copyWith(
        phase: UpdatePhase.downloading,
        receivedBytes: status.downloadedBytes,
        totalBytes: total,
        progress: total == null || total <= 0
            ? 0
            : (status.downloadedBytes / total).clamp(0.0, 1.0),
      ),
    );
  }

  bool _isInstallCancelled(ApkInstallFailure error) {
    final message = error.message.toLowerCase();
    return message.contains('install_failed_aborted') ||
        message.contains('user rejected');
  }

  Future<void> _waitForForeground() async {
    while (ref.mounted) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _finishDownload(
    PendingUpdateDownload pending,
    BackgroundDownloadStatus status, {
    required ApkInstaller installer,
    required ApkChecksumVerifier verifier,
  }) async {
    final path = status.path;
    if (path == null) {
      _fail(
        const UpdateFailure(
          UpdateFailureKind.invalidResponse,
          detail: 'Android did not report the downloaded APK path.',
        ),
      );
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      _fail(
        const UpdateFailure(
          UpdateFailureKind.invalidResponse,
          detail: 'The downloaded APK file no longer exists.',
        ),
      );
      return;
    }

    var checksumVerified = false;
    if (pending.checksumUrl != null && pending.checksumUrl!.isNotEmpty) {
      try {
        checksumVerified = await verifier(
          file,
          apkName: pending.fileName,
          checksumAsset: ReleaseAsset(
            name: '${pending.fileName}.sha256',
            downloadUrl: pending.checksumUrl!,
            size: 0,
          ),
        );
      } on UpdateFailure catch (error) {
        if (error.kind == UpdateFailureKind.checksum) {
          try {
            await file.delete();
          } on IOException {
            // Best-effort cleanup of a corrupt download.
          }
        }
        rethrow;
      }
    }

    if (!ref.mounted) {
      return;
    }
    final latest = state.value;
    if (latest != null) {
      state = AsyncData(
        latest.copyWith(
          phase: UpdatePhase.installing,
          downloadedFile: file,
          checksumVerified: checksumVerified,
          progress: 1,
        ),
      );
    }
    await _waitForForeground();
    if (!ref.mounted) {
      return;
    }
    await installer.install(file);
    if (!ref.mounted) {
      return;
    }
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(phase: UpdatePhase.idle, error: null));
    }
  }

  Future<void> openInstallSettings() async {
    await ref.read(apkInstallerProvider).openInstallSettings();
  }

  void dismiss() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        release: null,
        downloadedFile: null,
        permissionNeeded: false,
        error: null,
        phase: UpdatePhase.idle,
      ),
    );
  }

  void clearError() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(error: null, permissionNeeded: false));
  }

  void _fail(UpdateFailure failure) {
    final current = state.value;
    if (current == null || !ref.mounted) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        phase: UpdatePhase.idle,
        error: failure,
        permissionNeeded: false,
      ),
    );
  }
}
