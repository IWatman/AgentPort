import '../../domain/entities/marketplace.dart';

/// A resolved user input for adding a marketplace.
class MarketplaceReference {
  const MarketplaceReference({
    required this.sourceUrl,
    required this.manifestUrls,
  });

  /// Canonical repository or page URL shown in the UI.
  final String sourceUrl;

  /// Candidate manifest URLs, tried in order. GitHub repositories fall back
  /// from `main` to `master`.
  final List<String> manifestUrls;
}

/// Parses marketplace URLs and resolves plugin sources to raw file URLs.
class MarketplaceSourceResolver {
  const MarketplaceSourceResolver();

  static final _ownerRepo = RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');
  static final _githubPath = RegExp(
    r'^/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?(?:/(tree|blob)/([^/]+)(/.*)?)?/?$',
  );
  static final _rawGithub = RegExp(
    r'^/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/([^/]+)(/.*)?$',
  );
  static const _secretQueryNames = {
    'access_token',
    'api_key',
    'apikey',
    'auth',
    'client_secret',
    'key',
    'password',
    'secret',
    'sig',
    'signature',
    'token',
  };

  MarketplaceReference? parseInput(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return null;
    }

    if (_ownerRepo.hasMatch(input) && !input.contains('://')) {
      final parts = input.split('/');
      return _githubRepo(parts[0], _stripGit(parts[1]));
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    if (uri.scheme != 'https') {
      return null;
    }
    if (uri.userInfo.isNotEmpty) {
      return null;
    }
    for (final key in uri.queryParametersAll.keys) {
      if (_secretQueryNames.contains(key.toLowerCase())) {
        return null;
      }
    }

    if (uri.host == 'raw.githubusercontent.com') {
      final match = _rawGithub.firstMatch(uri.path);
      if (match == null) {
        return null;
      }
      final owner = match.group(1)!;
      final repo = match.group(2)!;
      return MarketplaceReference(
        sourceUrl: 'https://github.com/$owner/$repo',
        manifestUrls: [input],
      );
    }

    if (uri.host == 'github.com') {
      final match = _githubPath.firstMatch(uri.path);
      if (match == null) {
        return null;
      }
      final owner = match.group(1)!;
      final repo = match.group(2)!;
      final mode = match.group(3);
      final ref = match.group(4);
      final rest = match.group(5) ?? '';
      if (mode == 'blob' && ref != null && rest.endsWith('.json')) {
        final path = _cleanPath(rest);
        if (path == null) {
          return null;
        }
        return MarketplaceReference(
          sourceUrl: 'https://github.com/$owner/$repo',
          manifestUrls: [
            'https://raw.githubusercontent.com/$owner/$repo/$ref/$path',
          ],
        );
      }
      if (mode == 'tree' && ref != null) {
        final path = _cleanPath(rest);
        if (path == null) {
          return null;
        }
        final suffix = path.isEmpty
            ? '.claude-plugin/marketplace.json'
            : '$path/.claude-plugin/marketplace.json';
        return MarketplaceReference(
          sourceUrl: 'https://github.com/$owner/$repo',
          manifestUrls: [
            'https://raw.githubusercontent.com/$owner/$repo/$ref/$suffix',
          ],
        );
      }
      return _githubRepo(owner, repo);
    }

    if (uri.path.toLowerCase().endsWith('.json')) {
      return MarketplaceReference(sourceUrl: input, manifestUrls: [input]);
    }

    return null;
  }

  MarketplaceReference _githubRepo(String owner, String repo) {
    final base = 'https://github.com/$owner/$repo';
    return MarketplaceReference(
      sourceUrl: base,
      manifestUrls: [
        'https://raw.githubusercontent.com/$owner/$repo/main/.claude-plugin/marketplace.json',
        'https://raw.githubusercontent.com/$owner/$repo/master/.claude-plugin/marketplace.json',
      ],
    );
  }

  /// Returns the raw-content base URL for a plugin source, or `null` when the
  /// source cannot be represented by a supported raw host.
  String? rawBaseUrl({
    required PluginSource source,
    required Marketplace marketplace,
  }) {
    switch (source.kind) {
      case MarketplaceSourceKind.path:
        // Relative paths are resolved against the directory that contains the
        // marketplace manifest, not the repository root.
        final manifestBase = _rawManifestBase(marketplace.manifestUrl);
        if (manifestBase != null) {
          final path = _joinPath(manifestBase.basePath, source.path ?? '');
          if (path == null) {
            return null;
          }
          return manifestBase.url(path);
        }
        final repo = _parseRepo(marketplace.sourceUrl);
        final fallbackPath = _safePath(source.path ?? '');
        if (repo == null || fallbackPath == null) {
          return null;
        }
        return _rawBase(repo, ref: repo.defaultRef, path: fallbackPath);
      case MarketplaceSourceKind.gitSubdir:
        final repo = _parseRepo(source.url ?? '');
        if (repo == null) {
          return null;
        }
        final ref = _safeRef(source.sha ?? source.ref ?? repo.defaultRef);
        final path = _safePath(source.path ?? '');
        if (ref == null || path == null) {
          return null;
        }
        return _rawBase(repo, ref: ref, path: path);
      case MarketplaceSourceKind.url:
        final repo = _parseRepo(source.url ?? '');
        if (repo == null) {
          return null;
        }
        final ref = _safeRef(source.sha ?? source.ref ?? repo.defaultRef);
        if (ref == null) {
          return null;
        }
        return _rawBase(repo, ref: ref, path: '');
      case MarketplaceSourceKind.command:
      case MarketplaceSourceKind.unsupported:
        return null;
    }
  }

  /// Returns the URL of a file inside a plugin directory.
  String? rawFileUrl({
    required PluginSource source,
    required Marketplace marketplace,
    required String fileName,
  }) {
    final base = rawBaseUrl(source: source, marketplace: marketplace);
    if (base == null) {
      return null;
    }
    return '$base/$fileName';
  }

  _Repo? _parseRepo(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      if (_ownerRepo.hasMatch(trimmed)) {
        final parts = trimmed.split('/');
        return _Repo(
          host: 'github.com',
          owner: parts[0],
          name: _stripGit(parts[1]),
        );
      }
      return null;
    }

    if (uri.host == 'raw.githubusercontent.com') {
      final match = _rawGithub.firstMatch(uri.path);
      if (match == null) {
        return null;
      }
      return _Repo(
        host: 'github.com',
        owner: match.group(1)!,
        name: match.group(2)!,
      );
    }

    if (uri.host == 'github.com') {
      final match = _githubPath.firstMatch(uri.path);
      if (match == null) {
        return null;
      }
      return _Repo(
        host: 'github.com',
        owner: match.group(1)!,
        name: match.group(2)!,
      );
    }

    if (uri.host == 'gitlab.com') {
      final segments = uri.pathSegments;
      if (segments.length < 2) {
        return null;
      }
      return _Repo(
        host: 'gitlab.com',
        owner: segments[0],
        name: _stripGit(segments[1]),
        defaultRef: 'main',
      );
    }

    if (uri.host == 'bitbucket.org') {
      final segments = uri.pathSegments;
      if (segments.length < 2) {
        return null;
      }
      return _Repo(
        host: 'bitbucket.org',
        owner: segments[0],
        name: _stripGit(segments[1]),
        defaultRef: 'master',
      );
    }

    return null;
  }

  String? _rawBase(_Repo repo, {required String ref, required String path}) {
    final suffix = path.isEmpty ? '' : '/$path';
    return switch (repo.host) {
      'github.com' =>
        'https://raw.githubusercontent.com/${repo.owner}/${repo.name}/$ref$suffix',
      'gitlab.com' =>
        'https://gitlab.com/${repo.owner}/${repo.name}/-/raw/$ref$suffix',
      'bitbucket.org' =>
        'https://bitbucket.org/${repo.owner}/${repo.name}/raw/$ref$suffix',
      _ => null,
    };
  }

  _RawManifest? _rawManifestBase(String manifestUrl) {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null) {
      return null;
    }

    if (uri.host == 'raw.githubusercontent.com') {
      final match = _rawGithub.firstMatch(uri.path);
      if (match == null) {
        return null;
      }
      final ref = _safeRef(match.group(3));
      if (ref == null) {
        return null;
      }
      return _RawManifest(
        repo: _Repo(
          host: 'github.com',
          owner: match.group(1)!,
          name: match.group(2)!,
        ),
        ref: ref,
        basePath: _manifestDirectory(match.group(4) ?? ''),
      );
    }

    final segments = uri.pathSegments;
    if (uri.host == 'gitlab.com' &&
        segments.length >= 5 &&
        segments[2] == '-' &&
        segments[3] == 'raw') {
      final ref = _safeRef(segments[4]);
      if (ref == null) {
        return null;
      }
      return _RawManifest(
        repo: _Repo(
          host: 'gitlab.com',
          owner: segments[0],
          name: _stripGit(segments[1]),
        ),
        ref: ref,
        basePath: _manifestDirectory(segments.skip(5).join('/')),
      );
    }

    if (uri.host == 'bitbucket.org' &&
        segments.length >= 4 &&
        segments[2] == 'raw') {
      final ref = _safeRef(segments[3]);
      if (ref == null) {
        return null;
      }
      return _RawManifest(
        repo: _Repo(
          host: 'bitbucket.org',
          owner: segments[0],
          name: _stripGit(segments[1]),
        ),
        ref: ref,
        basePath: _manifestDirectory(segments.skip(4).join('/')),
      );
    }

    return null;
  }

  String _manifestDirectory(String manifestPath) {
    final path = _safePath(manifestPath);
    if (path == null || path.isEmpty) {
      return '';
    }
    const suffix = '.claude-plugin/marketplace.json';
    if (path == suffix) {
      return '';
    }
    if (path.endsWith('/$suffix')) {
      return path.substring(0, path.length - suffix.length - 1);
    }
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  String? _joinPath(String base, String relative) {
    final path = _safePath(relative);
    if (path == null) {
      return null;
    }
    if (base.isEmpty) {
      return path;
    }
    if (path.isEmpty) {
      return base;
    }
    return '$base/$path';
  }

  String? _safeRef(String? value) {
    final ref = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(ref)) {
      return null;
    }
    return ref;
  }

  String? _safePath(String value) {
    var path = value.trim().replaceAll(r'\', '/');
    while (path.startsWith('./')) {
      path = path.substring(2);
    }
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) {
      return '';
    }
    final segments = path.split('/');
    for (final segment in segments) {
      if (segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('?') ||
          segment.contains('#')) {
        return null;
      }
    }
    return path;
  }

  String? _cleanPath(String value) => _safePath(value);

  String _stripGit(String value) {
    return value.endsWith('.git')
        ? value.substring(0, value.length - 4)
        : value;
  }
}

class _Repo {
  const _Repo({
    required this.host,
    required this.owner,
    required this.name,
    this.defaultRef = 'main',
  });

  final String host;
  final String owner;
  final String name;
  final String defaultRef;
}

class _RawManifest {
  const _RawManifest({
    required this.repo,
    required this.ref,
    required this.basePath,
  });

  final _Repo repo;
  final String ref;
  final String basePath;

  String url(String path) {
    final suffix = path.isEmpty ? '' : '/$path';
    return switch (repo.host) {
      'github.com' =>
        'https://raw.githubusercontent.com/${repo.owner}/${repo.name}/$ref$suffix',
      'gitlab.com' =>
        'https://gitlab.com/${repo.owner}/${repo.name}/-/raw/$ref$suffix',
      'bitbucket.org' =>
        'https://bitbucket.org/${repo.owner}/${repo.name}/raw/$ref$suffix',
      _ => '',
    };
  }
}
