// The file-override store (spec: "reads prefer override files, fall back to
// bundled assets"; "atomic-from-the-user's-perspective writes: a failed
// refresh leaves all previous data intact").
//
// Layout under the [FileStore] root:
//
//   manifest.json                    SnapshotManifest — the commit point
//   generations/<id>/<unit>.json     one directory per successful refresh
//
// A commit writes every blob into a FRESH generation directory first and the
// manifest last. Readers reach blobs only through the manifest, so a failure
// anywhere before the manifest write leaves the previous generation fully
// intact and live — stale-but-working beats fresh-but-broken.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_store.dart';
import 'snapshot_manifest.dart';

class OverrideStore {
  OverrideStore(this._files);

  static const _manifestPath = 'manifest.json';
  static const _probePath = 'probe.json';
  static const _generationsDir = 'generations';

  final FileStore _files;

  /// The committed manifest, or `null` when absent or unparseable — an
  /// unreadable manifest degrades to asset fallback, never to a crash.
  Future<SnapshotManifest?> readManifest() async {
    final json = await _readJsonObject(_manifestPath);
    if (json == null) return null;
    try {
      return SnapshotManifest.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  /// When the refresher last PROBED the feed — recorded on every attempt,
  /// successful or not, so "probe at most once a day" holds even when the
  /// probe finds nothing worth committing (a null on first launch is "never
  /// probed"). Kept apart from the manifest: that one only records completed
  /// refreshes.
  Future<DateTime?> readLastProbeAt() async {
    final json = await _readJsonObject(_probePath);
    final rawAt = json?['probed_at'];
    if (rawAt is! String) return null;
    return DateTime.tryParse(rawAt);
  }

  /// Records a probe attempt at [at] (UTC as stored).
  Future<void> recordProbe(DateTime at) => _files.writeAtomic(
    _probePath,
    jsonEncode({'probed_at': at.toUtc().toIso8601String()}),
  );

  /// Decodes [path] as a JSON object, or null when absent, malformed, or not
  /// an object — corrupt storage degrades to fallbacks, never to a crash.
  Future<Map<String, dynamic>?> _readJsonObject(String path) async {
    final raw = await _files.readOrNull(path);
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// The override blob for [unit] (e.g. `heroes.english.json`) from the
  /// committed generation, or `null` when there is no manifest or the unit
  /// was not part of it — callers fall back to the bundled asset.
  Future<String?> readOrNull(String unit) async {
    final manifest = await readManifest();
    if (manifest == null) return null;
    return _files.readOrNull('${_generationPath(manifest)}/$unit');
  }

  /// Commits a refresh: blobs into a fresh generation dir, manifest last
  /// (the atomic switch), older generations pruned best-effort afterwards.
  /// Throws if any write fails — with every prior read still serving the
  /// previous data.
  Future<void> commit({
    required SnapshotManifest manifest,
    required Map<String, String> blobs,
  }) async {
    final generation = _generationPath(manifest);
    for (final entry in blobs.entries) {
      await _files.write('$generation/${entry.key}', entry.value);
    }
    // The commit point: one atomic write, all-or-nothing.
    await _files.writeAtomic(_manifestPath, jsonEncode(manifest.toJson()));
    await _pruneGenerations(keep: generation);
  }

  /// Generation dirs are named after the manifest's fetch time, so the
  /// manifest alone identifies the live generation — no second index to
  /// fall out of sync.
  String _generationPath(SnapshotManifest manifest) =>
      '$_generationsDir/${manifest.fetchedAt.toUtc().microsecondsSinceEpoch}';

  /// Best-effort cleanup: leftover dirs waste space but can never be read
  /// (only the manifest's generation is served), so a prune failure must
  /// not fail an already-committed refresh.
  Future<void> _pruneGenerations({required String keep}) async {
    try {
      final dirs = await _files.listDirs(_generationsDir);
      for (final dir in dirs) {
        if (dir != keep.split('/').last) {
          await _files.deleteDir('$_generationsDir/$dir');
        }
      }
    } on Exception {
      // Leftovers will be pruned on the next successful commit.
    }
  }
}

/// How features and the refresher reach the override store. Overridden in
/// tests with an [OverrideStore] over the in-memory fake.
final overrideStoreProvider = Provider<OverrideStore>(
  (ref) => OverrideStore(ref.watch(fileStoreProvider)),
);
