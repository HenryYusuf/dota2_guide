// Repository seam: the Hero roster is read override-first — a committed
// refresh override when present, else the bundled file behind an injectable
// loader, never HTTP (spec: usable offline on first launch; "override
// preferred over asset" pinned below).

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/in_memory_file_store.dart';

/// A minimal but schema-complete index, so this test pins repository
/// behaviour (which asset, what comes back) independently of the real
/// fixture, which the parsing test already owns.
const _bundledIndex = '''
{
  "schema_version": 1,
  "locale": "english",
  "heroes": [
    {
      "id": 1,
      "valve_key": "npc_dota_hero_antimage",
      "localized_name": "Anti-Mage",
      "primary_attribute": "agility",
      "complexity": 1,
      "portrait_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png"
    },
    {
      "id": 2,
      "valve_key": "npc_dota_hero_axe",
      "localized_name": "Axe",
      "primary_attribute": "strength",
      "complexity": 1,
      "portrait_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/axe.png"
    }
  ]
}
''';

/// What a refresh would have committed: same schema, different roster —
/// only the pieces the assertions need.
const _refreshedIndex = '''
{
  "schema_version": 1,
  "locale": "english",
  "heroes": [
    {
      "id": 99,
      "valve_key": "npc_dota_hero_refreshed",
      "localized_name": "Refreshed Mage",
      "primary_attribute": "intelligence",
      "complexity": 2,
      "portrait_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/refreshed.png"
    }
  ]
}
''';

/// In-memory stand-in for the asset bundle: records what was asked for and
/// serves canned content. No Flutter binding, no file system, no network.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a repository over a fake asset bundle and a (optionally
  /// pre-committed) override store — the same fakes the refresh tests use.
  SnapshotHeroesRepository repository({
    required AssetLoader assets,
    InMemoryFileStore? files,
  }) => SnapshotHeroesRepository(
    SnapshotSource(
      overrides: OverrideStore(files ?? InMemoryFileStore()),
      assets: assets,
    ),
  );

  test('returns the roster parsed from the loader\'s asset content', () async {
    final repo = repository(assets: _FakeAssetLoader(_bundledIndex));

    final heroes = await repo.loadHeroes();

    expect(heroes, hasLength(2));
    expect(heroes.first.id, 1);
    expect(heroes.first.valveKey, 'npc_dota_hero_antimage');
    expect(heroes.first.localizedName, 'Anti-Mage');
    expect(heroes.first.primaryAttribute, PrimaryAttribute.agility);
    expect(heroes.first.complexity, 1);
    expect(heroes.last.localizedName, 'Axe');
    expect(heroes.last.primaryAttribute, PrimaryAttribute.strength);
  });

  test('reads exactly the bundled English hero index', () async {
    final loader = _FakeAssetLoader(_bundledIndex);

    await repository(assets: loader).loadHeroes();

    expect(loader.requestedPaths, ['assets/data/heroes.english.json']);
  });

  test('a committed override is preferred over the bundled asset', () async {
    final files = InMemoryFileStore();
    await OverrideStore(files).commit(
      manifest: SnapshotManifest(
        dataVersion: 99,
        fetchedAt: DateTime.utc(2026, 10, 21, 8),
      ),
      blobs: {'heroes.english.json': _refreshedIndex},
    );

    final repo = repository(
      assets: _FakeAssetLoader(_bundledIndex),
      files: files,
    );

    final heroes = await repo.loadHeroes();

    expect(heroes, hasLength(1));
    expect(heroes.single.localizedName, 'Refreshed Mage');
  });

  test(
    'the production loader serves the asset the app actually bundles',
    () async {
      // Pins the pubspec wiring: if the snapshot file is missing from the asset
      // bundle, first launch would hit the repository's error path instead of
      // rendering the roster offline.
      final content = await const BundleAssetLoader().readAsString(
        heroIndexAssetPath,
      );

      expect(content, contains('"schema_version"'));
      expect(content, contains('"npc_dota_hero_antimage"'));
    },
  );
}
