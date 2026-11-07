/// Builders shared by the update data-layer tests.
Map<String, Object?> githubRelease({
  String? tag = 'v1.0.0',
  String? name = 'AgentPort 1.0.0',
  String? body = 'Release notes',
  String? htmlUrl = 'https://github.com/IWatman/AgentPort/releases/tag/v1.0.0',
  String? publishedAt = '2026-01-01T00:00:00Z',
  bool? draft = false,
  bool? prerelease = false,
  List<Map<String, Object?>>? assets,
}) {
  return <String, Object?>{
    'tag_name': ?tag,
    'name': ?name,
    'body': ?body,
    'html_url': ?htmlUrl,
    'published_at': ?publishedAt,
    'draft': ?draft,
    'prerelease': ?prerelease,
    'assets':
        assets ??
        <Map<String, Object?>>[assetJson('AgentPort-arm64-v8a-release.apk')],
  };
}

Map<String, Object?> assetJson(String name, {String? url, int size = 1024}) {
  return <String, Object?>{
    'name': name,
    'browser_download_url':
        url ??
        'https://github.com/IWatman/AgentPort/releases/download/v1.0.0/$name',
    'size': size,
  };
}
