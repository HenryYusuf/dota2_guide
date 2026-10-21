// Repository seam: one Hero's detail is read override-first — a committed
// refresh override when present, else the bundled per-Hero asset behind an
// injectable loader, never HTTP ("refreshed data wins" is pinned below;
// the schema itself is pinned by the parsing test over the real fixture).

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/heroes/hero_detail_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/in_memory_file_store.dart';

/// A schema-complete detail file (Anti-Mage, trimmed) — enough for the
/// repository test to pin which document comes back, independently of the
/// real fixture the parsing test owns.
String _detailFile(String localizedName, {int id = 1}) =>
    '''
{
  "schema_version": 1,
  "locale": "english",
  "hero": {
    "id": $id,
    "valve_key": "npc_dota_hero_test",
    "localized_name": "$localizedName",
    "one_liner": "A test hero.",
    "primary_attribute": "agility",
    "complexity": 1,
    "portrait_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/test.png",
    "attributes": {
      "strength": {"base": 20, "gain": 2.0},
      "agility": {"base": 24, "gain": 2.5},
      "intelligence": {"base": 15, "gain": 1.5}
    },
    "combat": {
      "damage_min": 50,
      "damage_max": 56,
      "attack_rate": 1.5,
      "attack_range": 150,
      "projectile_speed": 0,
      "armor": 5.0,
      "magic_resistance": 25,
      "movement_speed": 300,
      "turn_rate": 0.6,
      "sight_range_day": 1800,
      "sight_range_night": 800
    },
    "bio": "A pilgrim survived."
  },
  "abilities": [],
  "talents": ["+1 Damage", "+1 Armor", "+1 Damage", "+1 Armor", "+1 Damage", "+1 Armor", "+1 Damage", "+1 Armor"],
  "facets": []
}
''';

/// A minimal but schema-complete asset loader, serving one canned file per
/// requested path.
class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.contentByPath);

  final Map<String, String> contentByPath;
  final List<String> requestedPaths = [];

  @override
  Future<String> readAsString(String assetPath) async {
    requestedPaths.add(assetPath);
    final content = contentByPath[assetPath];
    if (content == null) {
      throw Exception('No canned asset for $assetPath');
    }
    return content;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a repository over a fake asset bundle and a (optionally
  /// pre-committed) override store — the same fakes the refresh tests use.
  SnapshotHeroDetailRepository repository({
    required AssetLoader assets,
    InMemoryFileStore? files,
  }) => SnapshotHeroDetailRepository(
    SnapshotSource(
      overrides: OverrideStore(files ?? InMemoryFileStore()),
      assets: assets,
    ),
  );

  Map<String, String> bundled({String name = 'Bundled Hero'}) => {
    heroDetailAssetPath(1): _detailFile(name),
  };

  test('reads the bundled per-Hero asset and parses it', () async {
    final loader = _FakeAssetLoader(bundled());

    final detail = await repository(assets: loader).loadHeroDetail(1);

    expect(loader.requestedPaths, ['assets/data/hero_1.english.json']);
    expect(detail.hero.id, 1);
    expect(detail.hero.localizedName, 'Bundled Hero');
    expect(detail.talents, hasLength(8));
  });

  test(
    'a committed override wins over the bundled asset (refreshed data)',
    () async {
      final files = InMemoryFileStore();
      await OverrideStore(files).commit(
        manifest: SnapshotManifest(
          dataVersion: 99,
          fetchedAt: DateTime.utc(2026, 10, 21, 8),
        ),
        blobs: {heroDetailUnitName(1): _detailFile('Refreshed Hero')},
      );

      final detail = await repository(
        assets: _FakeAssetLoader(bundled()),
        files: files,
      ).loadHeroDetail(1);

      expect(detail.hero.localizedName, 'Refreshed Hero');
    },
  );

  test('an override for another Hero never leaks into this one', () async {
    final files = InMemoryFileStore();
    await OverrideStore(files).commit(
      manifest: SnapshotManifest(
        dataVersion: 99,
        fetchedAt: DateTime.utc(2026, 10, 21, 8),
      ),
      blobs: {heroDetailUnitName(2): _detailFile('Other Hero', id: 2)},
    );

    final detail = await repository(
      assets: _FakeAssetLoader({
        ...bundled(),
        heroDetailAssetPath(2): _detailFile('Bundled Other', id: 2),
      }),
      files: files,
    ).loadHeroDetail(2);

    // Hero 2 has a committed override…
    expect(detail.hero.localizedName, 'Other Hero');
    // …and Hero 1 still reads its bundled asset (no cross-Hero bleed).
    final antiMage = await repository(
      assets: _FakeAssetLoader(bundled()),
      files: files,
    ).loadHeroDetail(1);
    expect(antiMage.hero.localizedName, 'Bundled Hero');
  });

  test(
    'the production loader serves the asset the app actually bundles',
    () async {
      // Pins the pubspec wiring for every Hero file the roster references:
      // a missing asset would make the detail page error on first launch
      // offline.
      final index = await const BundleAssetLoader().readAsString(
        'assets/data/heroes.english.json',
      );
      final ids = RegExp(r'"id":\s*(\d+)')
          .allMatches(index)
          .map((match) => int.parse(match.group(1)!));

      for (final id in ids) {
        final content = await const BundleAssetLoader().readAsString(
          heroDetailAssetPath(id),
        );
        expect(
          content,
          contains('"schema_version"'),
          reason: 'hero_$id.english.json must be bundled',
        );
      }
    },
  );
}
