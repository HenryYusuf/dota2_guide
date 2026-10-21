// Ability demo-video cache (spec: "ability demo videos (WebM) via
// video_player, disk-cached on first play through a cache-manager with a
// ~300 MB cap, never preloaded, never bundled" — ADR-0001).
//
// The feed carries no video field, so the CDN URL is built by convention
// ([CdnUrls.abilityDemoVideo]) and existence is discovered on first play:
// a missing demo (404) is a normal state, surfaced as
// [VideoUnavailableException] for the UI's small inline degraded state —
// never an error screen.
//
// Cache layout under `cacheDir`, mirroring the CDN's own two-level path:
//
//   <heroFolder>/<fullAbilityName>.webm
//
// First play downloads and persists; every replay — including across app
// restarts — is a pure disk read with no network (airplane mode safe).
// Past [abilityVideoCacheMaxBytes] (~300 MB) the least-recently-played
// file is evicted first; replaying a video moves it to the back of that
// order.

import 'dart:io';

import 'package:http/http.dart' as http;

/// The disk budget for cached demo videos (spec: "~300 MB cap"). With
/// demos at roughly 4–15 MB each this holds a couple of dozen Heroes'
/// kits comfortably.
const int abilityVideoCacheMaxBytes = 300 * 1024 * 1024;

/// The demo-video repository seam: the UI asks for a playable local file
/// and never touches HTTP or paths itself. Widget tests substitute a fake.
abstract interface class AbilityVideoRepository {
  /// The local WebM file for the demo video at [cdnUrl], downloading it
  /// into the disk cache on first play.
  ///
  /// Throws [VideoUnavailableException] when the CDN serves no video at
  /// that URL (a missing demo — expected, degrade quietly), and
  /// [VideoDownloadException] for transport/server failures (also degrade;
  /// a later play may succeed).
  Future<File> videoFileFor(String cdnUrl);
}

/// Every way fetching a demo can fail, in one family: the UI degrades for
/// all of them the same small, quiet way — never an error screen.
abstract interface class AbilityVideoException implements Exception {}

/// The CDN has no video at this URL: an ability without a demo. The UI
/// shows its small inline degraded state — this is not an error.
class VideoUnavailableException implements AbilityVideoException {
  VideoUnavailableException(this.url);

  final String url;

  @override
  String toString() => 'No demo video at $url';
}

/// The download failed (offline, CDN error, unwritable cache): degrade now,
/// retry on a later play.
class VideoDownloadException implements AbilityVideoException {
  VideoDownloadException(this.url, this.cause);

  final String url;
  final Object cause;

  @override
  String toString() => 'Demo download failed for $url: $cause';
}

/// [AbilityVideoRepository] over the Valve CDN with a size-capped disk
/// cache. Injectable clock so eviction order is testable without sleeping.
class CdnAbilityVideoRepository implements AbilityVideoRepository {
  CdnAbilityVideoRepository({
    required this._client,
    required this._cacheDir,
    this._maxCacheBytes = abilityVideoCacheMaxBytes,
    this._clock = DateTime.now,
  });

  final http.Client _client;
  final Directory _cacheDir;
  final int _maxCacheBytes;
  final DateTime Function() _clock;

  @override
  Future<File> videoFileFor(String cdnUrl) async {
    final file = _fileFor(cdnUrl);
    if (await file.exists()) {
      await _touch(file);
      return file;
    }
    await _download(cdnUrl, file);
    await _touch(file);
    await _enforceCap();
    return file;
  }

  /// The cache mirrors the CDN's two-level path, so one file maps to one
  /// URL and stays debuggable by eye.
  File _fileFor(String cdnUrl) {
    final uri = Uri.parse(cdnUrl);
    final segments = uri.pathSegments;
    if (segments.length < 2) {
      // Not a URL shape this cache can key on — treat as absent.
      throw VideoUnavailableException(cdnUrl);
    }
    final relative = segments.sublist(segments.length - 2).join('/');
    return File('${_cacheDir.path}/$relative');
  }

  Future<void> _download(String cdnUrl, File file) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(cdnUrl));
    } on Exception catch (error) {
      throw VideoDownloadException(cdnUrl, error);
    }
    if (response.statusCode == 404) {
      throw VideoUnavailableException(cdnUrl);
    }
    if (response.statusCode != 200) {
      throw VideoDownloadException(cdnUrl, 'HTTP ${response.statusCode}');
    }
    // Download to a temp name, then rename: a crash mid-write must never
    // leave a truncated file that later replays would trust (same
    // atomicity posture as the override store's writes). Disk failures
    // (full storage, permissions) degrade like transport failures — the
    // card must never see a raw FileSystemException.
    try {
      final temp = File('${file.path}.part');
      await temp.parent.create(recursive: true);
      await temp.writeAsBytes(response.bodyBytes, flush: true);
      await temp.rename(file.path);
    } on FileSystemException catch (error) {
      throw VideoDownloadException(cdnUrl, error);
    }
  }

  /// Records a replay in the file's modified time — the eviction order's
  /// "least recently played" clock. Best-effort: a touch that fails only
  /// makes the file evict slightly earlier.
  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(_clock());
    } on FileSystemException {
      // Some filesystems refuse; eviction then falls back to download time.
    }
  }

  /// Evicts least-recently-played files until the cache fits the cap.
  /// Best-effort by design: failing to evict wastes disk, never breaks
  /// playback.
  Future<void> _enforceCap() async {
    try {
      if (!await _cacheDir.exists()) return;
      final files = await _cacheDir
          .list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      var total = 0;
      final sizes = <File, int>{};
      final modified = <File, DateTime>{};
      for (final file in files) {
        sizes[file] = await file.length();
        total += sizes[file]!;
        // A stat failure sorts oldest (evicts first): we cannot prove it
        // was recently played.
        try {
          modified[file] = await file.lastModified();
        } on FileSystemException {
          modified[file] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
      if (total <= _maxCacheBytes) return;
      // Oldest modified time = least recently played = evicted first.
      final byAge = files.toList()
        ..sort((a, b) => modified[a]!.compareTo(modified[b]!));
      for (final file in byAge) {
        if (total <= _maxCacheBytes) break;
        await file.delete();
        total -= sizes[file]!;
      }
    } on FileSystemException {
      // Leftover space is reclaimed on the next successful eviction.
    }
  }
}
