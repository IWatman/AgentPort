/// A stable application release published on GitHub.
///
/// Instances are created from the GitHub Releases API. Draft and pre-release
/// entries are filtered out before an [AppRelease] is constructed.
class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  /// The original release tag, for example `v0.2.0`.
  final String tagName;

  /// The normalized version without a leading `v`.
  ///
  /// Build metadata is preserved when present (`0.1.0+10000`), but it does not
  /// participate in version comparisons.
  final String version;

  /// The human-readable release title.
  final String name;

  /// The release notes in Markdown, or an empty string when absent.
  final String notes;

  /// The browser URL of the release page.
  final String htmlUrl;

  /// The publication timestamp reported by GitHub, when available.
  final DateTime? publishedAt;

  /// Files attached to the release.
  final List<ReleaseAsset> assets;

  /// Parses a release from the GitHub Releases API.
  ///
  /// Returns `null` when the release is a draft, a pre-release, is missing its
  /// tag, or has a tag that is not a supported semantic version.
  static AppRelease? fromGitHubJson(Map<String, Object?> json) {
    if (json['draft'] != false || json['prerelease'] != false) {
      return null;
    }

    final tagName = _readNonEmptyString(json['tag_name']);
    if (tagName == null) {
      return null;
    }
    final version = AppVersion.tryParse(tagName);
    if (version == null) {
      return null;
    }

    final notes = json['body'];
    final assets = <ReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final rawAsset in rawAssets) {
        if (rawAsset is! Map) {
          continue;
        }
        final asset = ReleaseAsset.fromGitHubJson(
          Map<String, Object?>.from(rawAsset),
        );
        if (asset != null) {
          assets.add(asset);
        }
      }
    }

    return AppRelease(
      tagName: tagName,
      version: version.toString(),
      name: _readNonEmptyString(json['name']) ?? tagName,
      notes: notes is String ? notes : '',
      htmlUrl: _readNonEmptyString(json['html_url']) ?? '',
      publishedAt: DateTime.tryParse(
        _readNonEmptyString(json['published_at']) ?? '',
      ),
      assets: List.unmodifiable(assets),
    );
  }

  /// Whether this release is newer than [currentVersion].
  ///
  /// Returns `false` when either version cannot be parsed. Build metadata is
  /// ignored and only the major, minor, and patch numbers are compared.
  bool isNewerThan(String currentVersion) {
    final current = AppVersion.tryParse(currentVersion);
    final candidate = AppVersion.tryParse(version);
    if (current == null || candidate == null) {
      return false;
    }
    return candidate.isNewerThan(current);
  }
}

/// A downloadable file attached to a release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  /// The file name reported by GitHub.
  final String name;

  /// The direct browser download URL.
  final String downloadUrl;

  /// The file size in bytes, or `0` when GitHub did not report one.
  final int size;

  /// Parses an asset, returning `null` when required fields are missing.
  static ReleaseAsset? fromGitHubJson(Map<String, Object?> json) {
    final name = _readNonEmptyString(json['name']);
    final downloadUrl =
        _readNonEmptyString(json['browser_download_url']) ??
        _readNonEmptyString(json['download_url']) ??
        _readNonEmptyString(json['url']);
    if (name == null || downloadUrl == null) {
      return null;
    }

    final rawSize = json['size'];
    final size = rawSize is int
        ? rawSize
        : rawSize is num
        ? rawSize.toInt()
        : 0;
    return ReleaseAsset(
      name: name,
      downloadUrl: downloadUrl,
      size: size < 0 ? 0 : size,
    );
  }
}

/// A parsed semantic version with optional legacy short forms.
///
/// Accepted inputs are `1.2.3`, `v1.2.3`, `V1.2.3`, optional `+build`
/// metadata, and short forms such as `1.2` or `1` (missing components default
/// to zero). Pre-release suffixes are intentionally rejected because the
/// update channel is stable-only.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
  });

  static final _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  final int major;
  final int minor;
  final int patch;

  /// Optional build metadata, which never affects ordering.
  final String? build;

  /// Parses [input], returning `null` when it is not a supported version.
  static AppVersion? tryParse(String input) {
    final match = _pattern.firstMatch(input.trim());
    if (match == null) {
      return null;
    }
    final major = int.tryParse(match.group(1)!);
    final minor = match.group(2) == null ? 0 : int.tryParse(match.group(2)!);
    final patch = match.group(3) == null ? 0 : int.tryParse(match.group(3)!);
    if (major == null || minor == null || patch == null) {
      return null;
    }
    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: match.group(4),
    );
  }

  /// Parses [input] and throws [FormatException] when it is invalid.
  static AppVersion parse(String input) {
    final version = tryParse(input);
    if (version == null) {
      throw FormatException('Invalid version: $input');
    }
    return version;
  }

  /// Compares the major, minor, and patch numbers in that order.
  @override
  int compareTo(AppVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    return patch.compareTo(other.patch);
  }

  /// Whether this version is newer than [other].
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() {
    final suffix = build == null ? '' : '+$build';
    return '$major.$minor.$patch$suffix';
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        build == other.build;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build);
}

/// Compares two version strings numerically.
///
/// Throws [FormatException] when either value is not a supported version.
int compareAppVersions(String a, String b) {
  return AppVersion.parse(a).compareTo(AppVersion.parse(b));
}

String? _readNonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
