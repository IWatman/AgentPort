import 'dart:io';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/core/settings/app_settings.dart';
import 'package:agentport/core/settings/settings_controller.dart';
import 'package:agentport/core/updates/apk_installer.dart';
import 'package:agentport/data/updates/background_update_downloader.dart';
import 'package:agentport/data/updates/github_release_client.dart';
import 'package:agentport/domain/entities/app_release.dart';
import 'package:agentport/domain/entities/pending_update_download.dart';
import 'package:agentport/features/updates/update_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MemorySecureStore extends SecureStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class _FakeReleaseClient extends GitHubReleaseClient {
  _FakeReleaseClient(this.release);

  final AppRelease? release;
  var calls = 0;

  @override
  Future<AppRelease?> latestStable({
    required String currentVersion,
    dynamic client,
  }) async {
    calls++;
    final candidate = release;
    if (candidate == null || !candidate.isNewerThan(currentVersion)) {
      return null;
    }
    return candidate;
  }
}

class _FakeInstaller extends ApkInstaller {
  _FakeInstaller({this.allowed = true}) : super(isAndroid: true);

  final bool allowed;
  final List<File> installed = [];

  @override
  Future<bool> canInstallPackages() async => allowed;

  @override
  Future<void> install(File apk) async {
    installed.add(apk);
  }
}

class _FakeBackgroundDownloader extends BackgroundUpdateDownloader {
  _FakeBackgroundDownloader({required this.filePath, this.statuses = const []})
    : super(isAndroid: true);

  final String filePath;
  final List<BackgroundDownloadStatus> statuses;
  final List<Map<String, String>> enqueued = [];
  final List<int> removed = [];
  var nextId = 7;
  var _queryIndex = 0;

  @override
  Future<int> enqueue({
    required String url,
    required String fileName,
    required String title,
    required String description,
  }) async {
    enqueued.add({
      'url': url,
      'fileName': fileName,
      'title': title,
      'description': description,
    });
    return nextId;
  }

  @override
  Future<BackgroundDownloadStatus> query({
    required int id,
    required String fileName,
  }) async {
    final list = statuses.isEmpty
        ? [
            BackgroundDownloadStatus(
              phase: BackgroundDownloadPhase.successful,
              downloadedBytes: 4,
              totalBytes: 4,
              path: filePath,
            ),
          ]
        : statuses;
    final index = _queryIndex < list.length ? _queryIndex : list.length - 1;
    _queryIndex++;
    return list[index];
  }

  @override
  Future<void> remove(int id) async {
    removed.add(id);
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not met in time.');
}

const _release = AppRelease(
  tagName: 'v0.2.0',
  version: '0.2.0',
  name: 'Version 0.2.0',
  notes: 'Fixes and improvements.',
  htmlUrl: 'https://example.com/release',
  publishedAt: null,
  assets: [
    ReleaseAsset(
      name: 'agentport-v0.2.0.apk',
      downloadUrl: 'https://example.com/agentport-v0.2.0.apk',
      size: 4,
    ),
    ReleaseAsset(
      name: 'agentport-v0.2.0.apk.sha256',
      downloadUrl: 'https://example.com/agentport-v0.2.0.apk.sha256',
      size: 64,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late Directory tempDir;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tempDir = Directory.systemTemp.createTempSync('agentport_updates_');
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ProviderContainer createContainer({
    required _FakeReleaseClient releaseClient,
    _FakeInstaller? installer,
    _FakeBackgroundDownloader? downloader,
    ApkChecksumVerifier? verifier,
    String version = '0.1.0',
  }) {
    final apk = File('${tempDir.path}/agentport-v0.2.0.apk');
    if (!apk.existsSync()) {
      apk.writeAsBytesSync(const [1, 2, 3, 4]);
    }
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(_MemorySecureStore()),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(onboardingComplete: true),
        ),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'AgentPort',
            packageName: 'com.iwatman.agentport',
            version: version,
            buildNumber: '10000',
          ),
        ),
        githubReleaseClientProvider.overrideWithValue(releaseClient),
        apkInstallerProvider.overrideWithValue(installer ?? _FakeInstaller()),
        backgroundUpdateDownloaderProvider.overrideWithValue(
          downloader ?? _FakeBackgroundDownloader(filePath: apk.path),
        ),
        updateDownloadPollIntervalProvider.overrideWithValue(Duration.zero),
        releaseVerifierProvider.overrideWithValue(
          verifier ?? (file, {required apkName, checksumAsset}) async => true,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'check exposes a newer stable release and persists the check time',
    () async {
      final client = _FakeReleaseClient(_release);
      final container = createContainer(releaseClient: client);
      await container.read(updateControllerProvider.future);
      final controller = container.read(updateControllerProvider.notifier);

      final found = await controller.check();
      final state = container.read(updateControllerProvider).value!;

      expect(found?.version, '0.2.0');
      expect(state.release?.version, '0.2.0');
      expect(state.phase, UpdatePhase.idle);
      final lastCheck = await container
          .read(settingsRepositoryProvider)
          .loadLastUpdateCheck();
      expect(lastCheck, isNotNull);
    },
  );

  test('check returns null when the installed version is current', () async {
    final container = createContainer(
      releaseClient: _FakeReleaseClient(_release),
      version: '0.2.0',
    );
    await container.read(updateControllerProvider.future);
    final controller = container.read(updateControllerProvider.notifier);

    final found = await controller.check();

    expect(found, isNull);
    expect(container.read(updateControllerProvider).value!.release, isNull);
  });

  test('checkIfDue skips a recent automatic check', () async {
    final client = _FakeReleaseClient(_release);
    final container = createContainer(releaseClient: client);
    await container
        .read(settingsRepositoryProvider)
        .saveLastUpdateCheck(DateTime.now());
    await container.read(updateControllerProvider.future);

    final found = await container
        .read(updateControllerProvider.notifier)
        .checkIfDue();

    expect(found, isNull);
    expect(client.calls, 0);
  });

  test(
    'downloadAndInstall uses the background downloader, verifies, and installs',
    () async {
      final apkPath = '${tempDir.path}/agentport-v0.2.0.apk';
      final downloader = _FakeBackgroundDownloader(
        filePath: apkPath,
        statuses: [
          const BackgroundDownloadStatus(
            phase: BackgroundDownloadPhase.running,
            downloadedBytes: 2,
            totalBytes: 4,
          ),
          BackgroundDownloadStatus(
            phase: BackgroundDownloadPhase.successful,
            downloadedBytes: 4,
            totalBytes: 4,
            path: apkPath,
          ),
        ],
      );
      final installer = _FakeInstaller();
      final container = createContainer(
        releaseClient: _FakeReleaseClient(_release),
        installer: installer,
        downloader: downloader,
      );
      await container.read(updateControllerProvider.future);
      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      await controller.downloadAndInstall();

      final state = container.read(updateControllerProvider).value!;
      expect(downloader.enqueued, hasLength(1));
      expect(
        downloader.enqueued.single['url'],
        'https://example.com/agentport-v0.2.0.apk',
      );
      expect(downloader.enqueued.single['fileName'], 'agentport-v0.2.0.apk');
      expect(installer.installed, hasLength(1));
      expect(installer.installed.single.path, apkPath);
      expect(state.checksumVerified, isTrue);
      expect(state.phase, UpdatePhase.idle);
      expect(state.error, isNull);
      expect(
        await container
            .read(settingsRepositoryProvider)
            .loadPendingUpdateDownload(),
        isNull,
      );
    },
  );

  test('resumes a background download after the app restarts', () async {
    final apkPath = '${tempDir.path}/agentport-v0.2.0.apk';
    File(apkPath).writeAsBytesSync(const [1, 2, 3, 4]);
    final downloader = _FakeBackgroundDownloader(filePath: apkPath);
    final installer = _FakeInstaller();
    final container = createContainer(
      releaseClient: _FakeReleaseClient(_release),
      installer: installer,
      downloader: downloader,
    );
    await container
        .read(settingsRepositoryProvider)
        .savePendingUpdateDownload(
          const PendingUpdateDownload(
            id: 42,
            version: '0.2.0',
            fileName: 'agentport-v0.2.0.apk',
          ),
        );

    await container.read(updateControllerProvider.future);
    await _waitUntil(() => installer.installed.isNotEmpty);

    expect(installer.installed.single.path, apkPath);
    expect(
      await container
          .read(settingsRepositoryProvider)
          .loadPendingUpdateDownload(),
      isNull,
    );
    expect(
      container.read(updateControllerProvider).value!.phase,
      UpdatePhase.idle,
    );
  });

  test(
    'reports a failed background download and clears its metadata',
    () async {
      final downloader = _FakeBackgroundDownloader(
        filePath: '${tempDir.path}/agentport-v0.2.0.apk',
        statuses: const [
          BackgroundDownloadStatus(
            phase: BackgroundDownloadPhase.failed,
            reason: 1006,
          ),
        ],
      );
      final installer = _FakeInstaller();
      final container = createContainer(
        releaseClient: _FakeReleaseClient(_release),
        installer: installer,
        downloader: downloader,
      );
      await container.read(updateControllerProvider.future);
      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      await expectLater(
        controller.downloadAndInstall(),
        throwsA(isA<UpdateFailure>()),
      );

      expect(installer.installed, isEmpty);
      expect(downloader.removed, contains(7));
      expect(
        await container
            .read(settingsRepositoryProvider)
            .loadPendingUpdateDownload(),
        isNull,
      );
      expect(container.read(updateControllerProvider).value!.error, isNotNull);
    },
  );

  test('downloadAndInstall asks for install permission first', () async {
    final installer = _FakeInstaller(allowed: false);
    final container = createContainer(
      releaseClient: _FakeReleaseClient(_release),
      installer: installer,
    );
    await container.read(updateControllerProvider.future);
    final controller = container.read(updateControllerProvider.notifier);
    await controller.check();

    await controller.downloadAndInstall();

    final state = container.read(updateControllerProvider).value!;
    expect(state.permissionNeeded, isTrue);
    expect(installer.installed, isEmpty);
  });
}
