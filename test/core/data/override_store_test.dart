// OverrideStore: the file-override store (spec: "reads prefer override
// files, fall back to bundled assets" + "atomic-from-the-user's-perspective
// writes: a failed refresh leaves all previous data intact").
//
// Layout under the FileStore root:
//   manifest.json                      — SnapshotManifest (the commit point)
//   generations/<fetchedAt>/…json      — one dir per successful refresh
//
// Blobs land in a fresh generation dir first; only the manifest write makes
// them visible. A crash mid-commit leaves the old manifest → old data.

import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_file_store.dart';

void main() {
  late InMemoryFileStore files;
  late OverrideStore store;

  final at1 = DateTime.utc(2026, 10, 21, 8);
  final at2 = DateTime.utc(2026, 10, 21, 20);

  SnapshotManifest manifestAt(int? version, DateTime at) =>
      SnapshotManifest(dataVersion: version, fetchedAt: at);

  setUp(() {
    files = InMemoryFileStore();
    store = OverrideStore(files);
  });

  test('readManifest is null when nothing was ever committed', () async {
    expect(await store.readManifest(), isNull);
  });

  test('commit round-trips the manifest', () async {
    await store.commit(manifest: manifestAt(42, at1), blobs: const {});

    final manifest = await store.readManifest();
    expect(manifest?.dataVersion, 42);
    expect(manifest?.fetchedAt, at1);
  });

  test('readOrNull is null before any override (asset fallback)', () async {
    expect(await store.readOrNull('heroes.english.json'), isNull);
  });

  test('committed blobs are readable via readOrNull', () async {
    await store.commit(
      manifest: manifestAt(42, at1),
      blobs: {'heroes.english.json': '{"heroes":[]}'},
    );

    expect(await store.readOrNull('heroes.english.json'), '{"heroes":[]}');
  });

  test(
    'readOrNull misses (null) for a unit the commit did not include',
    () async {
      await store.commit(
        manifest: manifestAt(42, at1),
        blobs: {'heroes.english.json': 'x'},
      );

      expect(await store.readOrNull('other.json'), isNull);
    },
  );

  test(
    'a second commit supersedes the first and prunes the old generation',
    () async {
      await store.commit(
        manifest: manifestAt(42, at1),
        blobs: {'heroes.english.json': 'old'},
      );
      await store.commit(
        manifest: manifestAt(43, at2),
        blobs: {'heroes.english.json': 'new'},
      );

      expect(await store.readOrNull('heroes.english.json'), 'new');
      final generations = await files.listDirs('generations');
      expect(generations, hasLength(1));
    },
  );

  test('corrupt manifest degrades to asset fallback, not a crash', () async {
    await files.write('manifest.json', '{not json');

    expect(await store.readManifest(), isNull);
    expect(await store.readOrNull('heroes.english.json'), isNull);
  });

  test('no probe stamp reads as never probed', () async {
    expect(await store.readLastProbeAt(), isNull);
  });

  test('recordProbe round-trips the probe time', () async {
    await store.recordProbe(at2);

    expect(await store.readLastProbeAt(), at2);
  });

  test('a corrupt probe stamp degrades to never-probed, not a crash', () async {
    await files.write('probe.json', 'garbage');

    expect(await store.readLastProbeAt(), isNull);
  });

  test('failed blob write keeps the previous refresh fully intact', () async {
    await store.commit(
      manifest: manifestAt(42, at1),
      blobs: {'heroes.english.json': 'old'},
    );
    files.failWritesContaining = 'heroes';

    expect(
      () => store.commit(
        manifest: manifestAt(43, at2),
        blobs: {'heroes.english.json': 'new'},
      ),
      throwsException,
    );

    final manifest = await store.readManifest();
    expect(manifest?.dataVersion, 42);
    expect(await store.readOrNull('heroes.english.json'), 'old');
  });

  test(
    'failed manifest write leaves new blobs invisible (stale preserved)',
    () async {
      await store.commit(
        manifest: manifestAt(42, at1),
        blobs: {'heroes.english.json': 'old'},
      );
      files.failWritesContaining = 'manifest';

      expect(
        () => store.commit(
          manifest: manifestAt(43, at2),
          blobs: {'heroes.english.json': 'new'},
        ),
        throwsException,
      );

      final manifest = await store.readManifest();
      expect(manifest?.dataVersion, 42);
      expect(await store.readOrNull('heroes.english.json'), 'old');
    },
  );
}
