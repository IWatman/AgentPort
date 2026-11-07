import 'dart:io';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/core/settings/app_settings.dart';
import 'package:agentport/core/settings/settings_controller.dart';
import 'package:agentport/core/updates/apk_installer.dart';
import 'package:agentport/data/updates/github_release_client.dart';
import 'package:agentport/data/updates/release_downloader.dart';
import 'package:agentport/domain/entities/app_release.dart';
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
    String version = '0.1.0',
  }) {
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
        updateTempDirectoryProvider.overrideWith((ref) async => tempDir),
        releaseDownloadProvider.overrideWithValue((
          release, {
          required targetDir,
          onProgress,
        }) async {
          final file = File('${targetDir.path}/${release.version}.apk');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(const [1, 2, 3, 4]);
          onProgress?.call(2, 4);
          onProgress?.call(4, 4);
          return DownloadedRelease(file: file, checksumVerified: true);
        }),
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
    'downloadAndInstall downloads, verifies, and installs the APK',
    () async {
      final installer = _FakeInstaller();
      final container = createContainer(
        releaseClient: _FakeReleaseClient(_release),
        installer: installer,
      );
      await container.read(updateControllerProvider.future);
      final controller = container.read(updateControllerProvider.notifier);
      await controller.check();

      await controller.downloadAndInstall();

      final state = container.read(updateControllerProvider).value!;
      expect(installer.installed, hasLength(1));
      expect(installer.installed.single.existsSync(), isTrue);
      expect(state.checksumVerified, isTrue);
      expect(state.phase, UpdatePhase.idle);
      expect(state.error, isNull);
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
