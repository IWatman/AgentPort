import 'dart:io';

import 'package:agentport/core/db/app_database.dart';
import 'package:agentport/core/security/secure_store.dart';
import 'package:agentport/core/settings/app_settings.dart';
import 'package:agentport/core/settings/settings_controller.dart';
import 'package:agentport/core/updates/apk_installer.dart';
import 'package:agentport/data/updates/github_release_client.dart';
import 'package:agentport/domain/entities/app_release.dart';
import 'package:agentport/features/updates/update_controller.dart';
import 'package:agentport/features/updates/update_prompt_host.dart';
import 'package:agentport/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
  @override
  Future<AppRelease?> latestStable({
    required String currentVersion,
    dynamic client,
  }) async {
    const release = AppRelease(
      tagName: 'v0.2.0',
      version: '0.2.0',
      name: 'Version 0.2.0',
      notes: 'Fixes and improvements.',
      htmlUrl: '',
      publishedAt: null,
      assets: [],
    );
    return release.isNewerThan(currentVersion) ? release : null;
  }
}

void main() {
  testWidgets('update tile finds a release and opens the dialog', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final tempDir = Directory.systemTemp.createTempSync('agentport_tile_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    await tester.pumpWidget(
      ProviderScope(
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
              version: '0.1.0',
              buildNumber: '10000',
            ),
          ),
          githubReleaseClientProvider.overrideWithValue(_FakeReleaseClient()),
          apkInstallerProvider.overrideWithValue(
            ApkInstaller(isAndroid: false),
          ),
          updateTempDirectoryProvider.overrideWith((ref) async => tempDir),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: UpdateCheckTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Installed version 0.1.0'), findsOneWidget);

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Update available: v0.2.0'), findsWidgets);
    expect(find.text('Download and install'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available: v0.2.0'), findsNothing);
  });
}
