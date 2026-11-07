import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentport/data/updates/release_downloader.dart';
import 'package:agentport/domain/entities/app_release.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

AppRelease _release(List<ReleaseAsset> assets) {
  return AppRelease(
    tagName: 'v1.0.0',
    version: '1.0.0',
    name: 'AgentPort 1.0.0',
    notes: '',
    htmlUrl: 'https://example.test/release',
    publishedAt: DateTime.utc(2026),
    assets: assets,
  );
}

ReleaseAsset _asset(String name, {String? url}) {
  return ReleaseAsset(
    name: name,
    downloadUrl: url ?? 'https://example.test/$name',
    size: 0,
  );
}

http.StreamedResponse _streamed(
  List<List<int>> chunks, {
  int statusCode = 200,
  int? contentLength,
}) {
  return http.StreamedResponse(
    Stream.fromIterable(chunks),
    statusCode,
    contentLength:
        contentLength ??
        chunks.fold<int>(0, (sum, chunk) => sum + chunk.length),
  );
}

http.StreamedResponse _bodyResponse(String body, {int statusCode = 200}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream.value(bytes),
    statusCode,
    contentLength: bytes.length,
  );
}

void main() {
  group('selectApkAsset', () {
    test('returns null when no asset ends with .apk', () {
      expect(
        selectApkAsset([_asset('AgentPort.apk.sha256'), _asset('notes.txt')]),
        isNull,
      );
    });

    test('prefers an arm64-v8a release APK', () {
      final selected = selectApkAsset([
        _asset('AgentPort-armeabi-v7a-release.apk'),
        _asset('AgentPort-arm64-v8a-release.apk'),
        _asset('AgentPort-x86_64-release.apk'),
      ]);

      expect(selected?.name, 'AgentPort-arm64-v8a-release.apk');
    });

    test('prefers a release build over a non-release APK', () {
      final selected = selectApkAsset([
        _asset('AgentPort-arm64-v8a.apk'),
        _asset('AgentPort-release.apk'),
      ]);

      expect(selected?.name, 'AgentPort-release.apk');
    });

    test('falls back to the first APK', () {
      final selected = selectApkAsset([
        _asset('AgentPort-one.apk'),
        _asset('AgentPort-two.apk'),
      ]);

      expect(selected?.name, 'AgentPort-one.apk');
    });

    test('matches the extension case-insensitively', () {
      expect(selectApkAsset([_asset('AgentPort.APK')])?.name, 'AgentPort.APK');
    });
  });

  group('checksum helpers', () {
    test('prefers the APK-specific .sha256 asset over SHA256SUMS', () {
      final selected = selectChecksumAsset([
        _asset('SHA256SUMS'),
        _asset('AgentPort.apk.sha256'),
      ], 'AgentPort.apk');

      expect(selected?.name, 'AgentPort.apk.sha256');
    });

    test('falls back to SHA256SUMS', () {
      final selected = selectChecksumAsset([
        _asset('notes.txt'),
        _asset('SHA256SUMS'),
      ], 'AgentPort.apk');

      expect(selected?.name, 'SHA256SUMS');
    });

    test('returns null when no checksum asset exists', () {
      expect(
        selectChecksumAsset([_asset('AgentPort.apk')], 'AgentPort.apk'),
        isNull,
      );
    });

    test('parses bare hashes and GNU checksum lines', () {
      final hash = 'a' * 64;
      expect(parseChecksumText(hash), hash);
      expect(parseChecksumText('$hash  AgentPort.apk'), hash);
      expect(parseChecksumText('$hash *AgentPort.apk'), hash);
    });

    test('parses BSD checksum lines', () {
      final hash = 'b' * 64;
      expect(parseChecksumText('SHA256 (AgentPort.apk) = $hash'), hash);
    });

    test('selects the matching file from a multi-entry checksum file', () {
      final first = 'c' * 64;
      final second = 'd' * 64;
      final text = '$first  other.apk\n$second  AgentPort.apk\n';

      expect(parseChecksumText(text, fileName: 'AgentPort.apk'), second);
      expect(parseChecksumText(text, fileName: 'missing.apk'), isNull);
    });

    test('returns null for malformed checksum text', () {
      expect(parseChecksumText('not a checksum'), isNull);
      expect(parseChecksumText(''), isNull);
    });
  });

  group('downloadApk', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'agentport_updates_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streams the APK to disk and reports progress', () async {
      final bytes = utf8.encode('fake apk content');
      final progress = <({int received, int? total})>[];
      final requests = <Uri>[];
      final client = MockClient.streaming((request, body) async {
        requests.add(request.url);
        return _streamed([
          bytes.sublist(0, 4),
          bytes.sublist(4),
        ], contentLength: bytes.length);
      });

      final result = await downloadApk(
        _release([_asset('AgentPort-arm64-v8a-release.apk')]),
        targetDir: tempDir,
        client: client,
        onProgress: (received, total) {
          progress.add((received: received, total: total));
        },
      );

      expect(result.checksumVerified, isFalse);
      expect(await result.file.readAsBytes(), bytes);
      expect(p.basename(result.file.path), 'AgentPort-arm64-v8a-release.apk');
      expect(progress.map((event) => event.received), [4, bytes.length]);
      expect(progress.last.total, bytes.length);
      expect(requests, hasLength(1));
      expect(
        (await tempDir.list().toList()).map((entry) => p.basename(entry.path)),
        ['AgentPort-arm64-v8a-release.apk'],
      );
    });

    test('verifies a .sha256 asset with filename and hash', () async {
      final bytes = utf8.encode('apk payload');
      final hash = sha256.convert(bytes).toString();
      final requests = <Uri>[];
      final client = MockClient.streaming((request, body) async {
        requests.add(request.url);
        if (request.url.path.endsWith('.sha256')) {
          return _bodyResponse('$hash  AgentPort.apk\n');
        }
        return _streamed([bytes], contentLength: bytes.length);
      });

      final result = await downloadApk(
        _release([_asset('AgentPort.apk'), _asset('AgentPort.apk.sha256')]),
        targetDir: tempDir,
        client: client,
      );

      expect(result.checksumVerified, isTrue);
      expect(await result.file.readAsBytes(), bytes);
      expect(requests, hasLength(2));
    });

    test('accepts a .sha256 asset containing only the hash', () async {
      final bytes = utf8.encode('apk payload');
      final hash = sha256.convert(bytes).toString();
      final client = MockClient.streaming((request, body) async {
        if (request.url.path.endsWith('.sha256')) {
          return _bodyResponse(hash);
        }
        return _streamed([bytes], contentLength: bytes.length);
      });

      final result = await downloadApk(
        _release([_asset('AgentPort.apk'), _asset('AgentPort.apk.sha256')]),
        targetDir: tempDir,
        client: client,
      );

      expect(result.checksumVerified, isTrue);
    });

    test('verifies the matching line in SHA256SUMS', () async {
      final bytes = utf8.encode('apk payload');
      final hash = sha256.convert(bytes).toString();
      final otherHash = 'e' * 64;
      final client = MockClient.streaming((request, body) async {
        if (request.url.path.endsWith('/SHA256SUMS')) {
          return _bodyResponse('$otherHash  other.apk\n$hash  AgentPort.apk\n');
        }
        return _streamed([bytes], contentLength: bytes.length);
      });

      final result = await downloadApk(
        _release([_asset('AgentPort.apk'), _asset('SHA256SUMS')]),
        targetDir: tempDir,
        client: client,
      );

      expect(result.checksumVerified, isTrue);
    });

    test('throws a checksum failure and removes the partial file', () async {
      final bytes = utf8.encode('apk payload');
      final wrongHash = 'f' * 64;
      final client = MockClient.streaming((request, body) async {
        if (request.url.path.endsWith('.sha256')) {
          return _bodyResponse('$wrongHash  AgentPort.apk\n');
        }
        return _streamed([bytes], contentLength: bytes.length);
      });

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk'), _asset('AgentPort.apk.sha256')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.checksum,
          ),
        ),
      );

      expect(await tempDir.list().toList(), isEmpty);
    });

    test('throws invalidResponse for a malformed checksum file', () async {
      final bytes = utf8.encode('apk payload');
      final client = MockClient.streaming((request, body) async {
        if (request.url.path.endsWith('.sha256')) {
          return _bodyResponse('not a hash');
        }
        return _streamed([bytes], contentLength: bytes.length);
      });

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk'), _asset('AgentPort.apk.sha256')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.invalidResponse,
          ),
        ),
      );

      expect(await tempDir.list().toList(), isEmpty);
    });

    test('cleans up when the response stream fails midway', () async {
      Stream<List<int>> failingStream() async* {
        yield const [1, 2, 3];
        throw http.ClientException('connection lost');
      }

      final client = MockClient.streaming(
        (request, body) async =>
            http.StreamedResponse(failingStream(), 200, contentLength: 10),
      );

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.network,
          ),
        ),
      );

      expect(await tempDir.list().toList(), isEmpty);
    });

    test('maps a failed APK response to server and creates no file', () async {
      final client = MockClient.streaming(
        (request, body) async =>
            http.StreamedResponse(Stream.fromIterable(const []), 500),
      );

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                UpdateFailureKind.server,
              )
              .having((failure) => failure.statusCode, 'statusCode', 500),
        ),
      );

      expect(await tempDir.list().toList(), isEmpty);
    });

    test('maps a request timeout to timeout and cleans up', () async {
      final client = MockClient.streaming(
        (request, body) async => throw TimeoutException('slow'),
      );

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.timeout,
          ),
        ),
      );

      expect(await tempDir.list().toList(), isEmpty);
    });

    test('throws invalidResponse when the release has no APK', () async {
      final client = MockClient(
        (request) async => fail('no HTTP request was expected'),
      );

      await expectLater(
        downloadApk(
          _release([_asset('AgentPort.apk.sha256')]),
          targetDir: tempDir,
          client: client,
        ),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.invalidResponse,
          ),
        ),
      );
    });
  });
}
