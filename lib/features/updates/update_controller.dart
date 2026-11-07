import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/updates/apk_installer.dart';
import '../../data/updates/github_release_client.dart';
import '../../data/updates/release_downloader.dart';
import '../../domain/entities/app_release.dart';

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

typedef ReleaseDownload = Future<DownloadedRelease> Function(
  AppRelease release, {
  required Directory targetDir,
  void Function(int received, int? total)? onProgress,
});

final releaseDownloadProvider = Provider<ReleaseDownload>(
  (ref) =>
      (release, {required targetDir, onProgress}) =>
          downloadApk(release, targetDir: targetDir, onProgress: onProgress),
);

final updateTempDirectoryProvider = FutureProvider<Directory>(
  (ref) => getTemporaryDirectory(),
);

final updateControllerProvider =
    AsyncNotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Checks GitHub Releases and drives the download/install flow.
class UpdateController extends AsyncNotifier<UpdateState> {
  @override
  Future<UpdateState> build() async {
    final info = await ref.watch(packageInfoProvider.future);
    final lastCheck = await ref
        .read(settingsRepositoryProvider)
        .loadLastUpdateCheck();
    return UpdateState(currentVersion: info.version, lastCheck: lastCheck);
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

  /// Downloads the pending release and starts the system installer.
  Future<void> downloadAndInstall() async {
    final current = state.value;
    final release = current?.release;
    if (current == null || release == null || current.isBusy) {
      return;
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
      final temp = await ref.read(updateTempDirectoryProvider.future);
      final target = Directory('${temp.path}/updates');
      final downloaded = await ref.read(releaseDownloadProvider)(
        release,
        targetDir: target,
        onProgress: (received, total) {
          if (!ref.mounted) {
            return;
          }
          final latest = state.value;
          if (latest == null) {
            return;
          }
          state = AsyncData(
            latest.copyWith(
              receivedBytes: received,
              totalBytes: total,
              progress: total == null || total <= 0
                  ? 0
                  : (received / total).clamp(0, 1),
            ),
          );
        },
      );

      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        state.value!.copyWith(
          phase: UpdatePhase.installing,
          downloadedFile: downloaded.file,
          checksumVerified: downloaded.checksumVerified,
          progress: 1,
        ),
      );
      await installer.install(downloaded.file);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(
        state.value!.copyWith(phase: UpdatePhase.idle, error: null),
      );
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
