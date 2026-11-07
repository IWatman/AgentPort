import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../domain/entities/app_release.dart';
import '../../domain/entities/update_failure.dart';

export '../../domain/entities/update_failure.dart';

/// A downloaded release APK together with its verification status.
class DownloadedRelease {
  const DownloadedRelease({required this.file, required this.checksumVerified});

  /// The APK written to the target directory.
  final File file;

  /// Whether the APK matched a published SHA-256 checksum.
  ///
  /// This is `false` when the release did not publish a checksum asset.
  final bool checksumVerified;
}

/// Downloads and verifies the best APK attached to [release].
///
/// The response is streamed to disk instead of being buffered in memory.
/// [onProgress] receives the cumulative byte count and the total size from the
/// `content-length` header, when the server provides one.
///
/// When the release contains `<apkName>.sha256` or `SHA256SUMS`, the checksum
/// is fetched and verified. The partial file is removed on any failure.
Future<DownloadedRelease> downloadApk(
  AppRelease release, {
  required Directory targetDir,
  void Function(int received, int? total)? onProgress,
  http.Client? client,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final asset = selectApkAsset(release.assets);
  if (asset == null) {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The release does not contain an APK asset.',
    );
  }

  final downloadUri = Uri.tryParse(asset.downloadUrl);
  if (downloadUri == null || !downloadUri.hasScheme) {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The APK asset has an invalid download URL.',
    );
  }

  final fileName = p.basename(asset.name);
  if (fileName.isEmpty || fileName == '.' || fileName == '..') {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The APK asset has an invalid file name.',
    );
  }

  final activeClient = client ?? http.Client();
  final ownsClient = client == null;
  var completed = false;
  File? partialFile;

  try {
    await targetDir.create(recursive: true);
    final targetFile = File(p.join(targetDir.path, fileName));
    partialFile = File('${targetFile.path}.part');

    await _downloadAsset(
      activeClient,
      downloadUri,
      partialFile,
      onProgress,
      timeout,
    );

    final checksumAsset = selectChecksumAsset(release.assets, fileName);
    var checksumVerified = false;
    if (checksumAsset != null) {
      final expected = await _fetchChecksum(
        activeClient,
        checksumAsset,
        fileName,
        timeout,
      );
      final actual = await _fileSha256(partialFile);
      if (actual != expected) {
        throw const UpdateFailure(
          UpdateFailureKind.checksum,
          detail:
              'The downloaded APK does not match the published SHA-256 '
              'checksum.',
        );
      }
      checksumVerified = true;
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final downloadedFile = await partialFile.rename(targetFile.path);
    completed = true;
    return DownloadedRelease(
      file: downloadedFile,
      checksumVerified: checksumVerified,
    );
  } finally {
    if (!completed && partialFile != null) {
      try {
        if (await partialFile.exists()) {
          await partialFile.delete();
        }
      } on FileSystemException {
        // Best-effort cleanup; the original failure is more useful.
      }
    }
    if (ownsClient) {
      activeClient.close();
    }
  }
}

/// Selects the APK asset to download.
///
/// When multiple APKs are attached, an `arm64-v8a` release build is preferred,
/// then any release build, then any arm64 build, and finally the first APK.
/// Matching is case-insensitive.
ReleaseAsset? selectApkAsset(Iterable<ReleaseAsset> assets) {
  final apks = assets
      .where((asset) => asset.name.toLowerCase().endsWith('.apk'))
      .toList(growable: false);
  if (apks.isEmpty) {
    return null;
  }

  for (final asset in apks) {
    final name = asset.name.toLowerCase();
    if (name.contains('arm64-v8a') && name.contains('release')) {
      return asset;
    }
  }
  for (final asset in apks) {
    if (asset.name.toLowerCase().contains('release')) {
      return asset;
    }
  }
  for (final asset in apks) {
    final name = asset.name.toLowerCase();
    if (name.contains('arm64') || name.contains('aarch64')) {
      return asset;
    }
  }
  return apks.first;
}

/// Selects the checksum asset for [apkName].
///
/// An asset named `<apkName>.sha256` takes priority, followed by an asset
/// named `SHA256SUMS`.
ReleaseAsset? selectChecksumAsset(
  Iterable<ReleaseAsset> assets,
  String apkName,
) {
  final expected = '$apkName.sha256'.toLowerCase();
  ReleaseAsset? sums;
  for (final asset in assets) {
    final name = asset.name.toLowerCase();
    if (name == expected) {
      return asset;
    }
    if (name == 'sha256sums' && sums == null) {
      sums = asset;
    }
  }
  return sums;
}

/// Extracts a SHA-256 hash from a checksum file.
///
/// Supports a bare 64-character hash, the GNU format (`hash  file` or
/// `hash *file`), and the BSD format (`SHA256 (file) = hash`). When
/// [fileName] is supplied, a line naming that file is preferred; otherwise
/// the first valid hash is returned. Returns `null` when no valid hash exists.
String? parseChecksumText(String text, {String? fileName}) {
  String? firstHash;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    String? hash;
    String? namedFile;

    final bsd = _bsdPattern.firstMatch(line);
    if (bsd != null) {
      namedFile = bsd.group(1)?.trim();
      hash = bsd.group(2);
    } else {
      final gnu = _gnuPattern.firstMatch(line);
      if (gnu != null) {
        hash = gnu.group(1);
        namedFile = gnu.group(2)?.trim();
      } else {
        final bare = _bareHashPattern.firstMatch(line);
        if (bare != null) {
          hash = bare.group(1);
        }
      }
    }

    if (hash == null) {
      continue;
    }
    final normalized = hash.toLowerCase();
    if (namedFile == null || namedFile.isEmpty) {
      return normalized;
    }
    firstHash ??= normalized;
    if (fileName != null && _sameFileName(namedFile, fileName)) {
      return normalized;
    }
  }

  // When a file name is requested, do not verify against a hash that names a
  // different file. A bare hash is still accepted above.
  return fileName == null ? firstHash : null;
}

Future<void> _downloadAsset(
  http.Client client,
  Uri uri,
  File file,
  void Function(int received, int? total)? onProgress,
  Duration timeout,
) async {
  final request = http.Request('GET', uri);
  http.StreamedResponse response;
  try {
    response = await client.send(request).timeout(timeout);
  } on TimeoutException {
    throw const UpdateFailure(
      UpdateFailureKind.timeout,
      detail: 'The APK download timed out.',
    );
  } on http.ClientException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.message);
  } on IOException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  } on Exception catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _failureForStatus(response.statusCode);
  }

  final total = response.contentLength;
  final sink = file.openWrite();
  var received = 0;

  try {
    await for (final chunk in response.stream.timeout(timeout)) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.flush();
  } on TimeoutException {
    throw const UpdateFailure(
      UpdateFailureKind.timeout,
      detail: 'The APK download stopped responding.',
    );
  } on http.ClientException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.message);
  } on IOException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  } on Exception catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  } finally {
    try {
      await sink.close();
    } on IOException {
      // The original failure is more useful than a close error.
    }
  }
}

Future<String> _fetchChecksum(
  http.Client client,
  ReleaseAsset asset,
  String apkName,
  Duration timeout,
) async {
  final uri = Uri.tryParse(asset.downloadUrl);
  if (uri == null || !uri.hasScheme) {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The checksum asset has an invalid download URL.',
    );
  }

  http.Response response;
  try {
    response = await client.get(uri).timeout(timeout);
  } on TimeoutException {
    throw const UpdateFailure(
      UpdateFailureKind.timeout,
      detail: 'The checksum download timed out.',
    );
  } on http.ClientException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.message);
  } on IOException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  } on Exception catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _failureForStatus(response.statusCode);
  }

  final String text;
  try {
    text = utf8.decode(response.bodyBytes);
  } on FormatException {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The checksum file is not valid UTF-8 text.',
    );
  }

  final hash = parseChecksumText(text, fileName: apkName);
  if (hash == null) {
    throw const UpdateFailure(
      UpdateFailureKind.invalidResponse,
      detail: 'The checksum file does not contain a SHA-256 hash.',
    );
  }
  return hash;
}

Future<String> _fileSha256(File file) async {
  try {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  } on IOException catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  } on Exception catch (error) {
    throw UpdateFailure(UpdateFailureKind.network, detail: error.toString());
  }
}

UpdateFailure _failureForStatus(int statusCode) {
  if (statusCode == 403 || statusCode == 429) {
    return UpdateFailure(
      UpdateFailureKind.rateLimited,
      statusCode: statusCode,
      detail: 'GitHub rate limit exceeded while downloading the release.',
    );
  }
  return UpdateFailure(
    UpdateFailureKind.server,
    statusCode: statusCode,
    detail: 'The download server returned HTTP $statusCode.',
  );
}

bool _sameFileName(String candidate, String expected) {
  final normalized = candidate.replaceAll('\\', '/');
  return p.basename(normalized) == expected;
}

final _bareHashPattern = RegExp(r'^([0-9a-fA-F]{64})$');
final _gnuPattern = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$');
final _bsdPattern = RegExp(
  r'^SHA256\s*\((.+)\)\s*=\s*([0-9a-fA-F]{64})$',
  caseSensitive: false,
);
