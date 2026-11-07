import 'dart:io';

import 'package:agentport/core/updates/apk_installer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.iwatman.agentport/installer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('apk_installer_test_');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await tempDir.delete(recursive: true);
  });

  ApkInstaller createInstaller({bool isAndroid = true}) {
    return ApkInstaller(channel: channel, isAndroid: isAndroid);
  }

  Future<File> createFile(String name) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(const [1, 2, 3]);
    return file;
  }

  Matcher isFailure(ApkInstallFailureKind kind) {
    return isA<ApkInstallFailure>().having(
      (failure) => failure.kind,
      'kind',
      kind,
    );
  }

  group('install', () {
    test('invokes installApk with the APK path', () async {
      final apk = await createFile('update.apk');
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await createInstaller().install(apk);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'installApk');
      expect(calls.single.arguments, apk.path);
    });

    test('maps permission_denied errors', () async {
      final apk = await createFile('update.apk');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'permission_denied',
          message: 'Installing unknown apps is not allowed.',
        );
      });

      await expectLater(
        createInstaller().install(apk),
        throwsA(isFailure(ApkInstallFailureKind.permissionDenied)),
      );
    });

    test('maps file_not_found errors', () async {
      final apk = await createFile('update.apk');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'file_not_found');
      });

      await expectLater(
        createInstaller().install(apk),
        throwsA(isFailure(ApkInstallFailureKind.fileNotFound)),
      );
    });

    test('maps install_failed errors', () async {
      final apk = await createFile('update.apk');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'install_failed', message: 'Rejected.');
      });

      await expectLater(
        createInstaller().install(apk),
        throwsA(isFailure(ApkInstallFailureKind.installFailed)),
      );
    });

    test('maps invalid_file errors', () async {
      final apk = await createFile('update.apk');
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'invalid_file');
      });

      await expectLater(
        createInstaller().install(apk),
        throwsA(isFailure(ApkInstallFailureKind.invalidFile)),
      );
    });

    test('rejects a missing file without calling the channel', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return null;
      });

      final missing = File(
        '${tempDir.path}${Platform.pathSeparator}missing.apk',
      );

      await expectLater(
        createInstaller().install(missing),
        throwsA(isFailure(ApkInstallFailureKind.fileNotFound)),
      );
      expect(calls, 0);
    });

    test('rejects a non-apk file without calling the channel', () async {
      final file = await createFile('update.zip');
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return null;
      });

      await expectLater(
        createInstaller().install(file),
        throwsA(isFailure(ApkInstallFailureKind.invalidFile)),
      );
      expect(calls, 0);
    });
  });

  group('canInstallPackages', () {
    test('returns true when the platform allows installs', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'canInstallPackages');
        return true;
      });

      expect(await createInstaller().canInstallPackages(), isTrue);
    });

    test('returns false when the platform blocks installs', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'canInstallPackages');
        return false;
      });

      expect(await createInstaller().canInstallPackages(), isFalse);
    });
  });

  group('openInstallSettings', () {
    test('invokes the settings method', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      await createInstaller().openInstallSettings();

      expect(calls.single.method, 'openInstallSettings');
    });

    test('maps platform failures', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'install_failed',
          message: 'No settings activity.',
        );
      });

      await expectLater(
        createInstaller().openInstallSettings(),
        throwsA(isFailure(ApkInstallFailureKind.installFailed)),
      );
    });
  });

  group('non-Android platforms', () {
    test('rejects canInstallPackages as unsupported', () async {
      await expectLater(
        createInstaller(isAndroid: false).canInstallPackages(),
        throwsA(isFailure(ApkInstallFailureKind.unsupportedPlatform)),
      );
    });

    test('rejects install as unsupported', () async {
      final apk = await createFile('update.apk');

      await expectLater(
        createInstaller(isAndroid: false).install(apk),
        throwsA(isFailure(ApkInstallFailureKind.unsupportedPlatform)),
      );
    });
  });
}
