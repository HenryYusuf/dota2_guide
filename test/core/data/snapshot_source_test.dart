// SnapshotSource: the override-first read path (spec: "reads prefer override
// files, fall back to bundled assets"). Features hand it a unit name (their
// override blob) and the bundled asset path to fall back to, so the layering
// rule holds: features never import core's storage, core never imports
// feature schemas.

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_file_store.dart';

class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.content);

  final String content;
  final List<String> requestedPaths = [];

  @override
  Future<String> readAsString(String assetPath) async {
    requestedPaths.add(assetPath);
    return content;
  }
}

void main() {
  final at = DateTime.utc(2026, 10, 21, 8);

  late InMemoryFileStore files;
  late _FakeAssetLoader assets;
  late SnapshotSource source;

  setUp(() {
    files = InMemoryFileStore();
    assets = _FakeAssetLoader('{"from":"asset"}');
    source = SnapshotSource(overrides: OverrideStore(files), assets: assets);
  });

  test('falls back to the bundled asset when no override exists', () async {
    final read = await source.readUnit('heroes.english.json', 'assets/x.json');

    expect(read, '{"from":"asset"}');
    expect(assets.requestedPaths, ['assets/x.json']);
  });

  test('a committed override wins over the bundled asset', () async {
    await OverrideStore(files).commit(
      manifest: SnapshotManifest(dataVersion: 7, fetchedAt: at),
      blobs: {'heroes.english.json': '{"from":"override"}'},
    );

    final read = await source.readUnit('heroes.english.json', 'assets/x.json');

    expect(read, '{"from":"override"}');
    expect(assets.requestedPaths, isEmpty);
  });

  test(
    'other units still fall back to their assets after a partial commit',
    () async {
      await OverrideStore(files).commit(
        manifest: SnapshotManifest(dataVersion: 7, fetchedAt: at),
        blobs: {'heroes.english.json': '{"from":"override"}'},
      );

      final read = await source.readUnit('items.json', 'assets/items.json');

      expect(read, '{"from":"asset"}');
      expect(assets.requestedPaths, ['assets/items.json']);
    },
  );

  test(
    'a corrupt manifest degrades to the bundled asset, not a crash',
    () async {
      await files.write('manifest.json', 'garbage');

      final read = await source.readUnit(
        'heroes.english.json',
        'assets/x.json',
      );

      expect(read, '{"from":"asset"}');
    },
  );
}
