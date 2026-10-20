// Repository seam: the Hero roster is read asset-first — a bundled file behind
// an injectable loader, never HTTP (spec: usable offline on first launch;
// issue 03 layers the override store onto this same read path).

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('returns the roster parsed from the loader\'s asset content', () async {
    final repository = AssetHeroesRepository(_FakeAssetLoader(_bundledIndex));

    final heroes = await repository.loadHeroes();

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

    await AssetHeroesRepository(loader).loadHeroes();

    expect(loader.requestedPaths, ['assets/data/heroes.english.json']);
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
