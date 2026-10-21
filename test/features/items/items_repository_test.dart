// Repository seam: the Item index is read override-first — a committed
// refresh override when present, else the bundled file behind an injectable
// loader, never HTTP (spec: usable offline on first launch; "override
// preferred over asset" pinned below).

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/in_memory_file_store.dart';

/// A minimal but schema-complete index, so this test pins repository
/// behaviour (which asset, what comes back) independently of the real
/// fixture, which the parsing test already owns.
const _bundledIndex = '''
{
  "schema_version": 1,
  "locale": "english",
  "items": [
    {
      "id": 1,
      "valve_key": "item_blink",
      "name": "Blink Dagger",
      "shop_category": "weapons",
      "neutral_tier": null,
      "is_recipe": false,
      "icon_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/blink.png"
    },
    {
      "id": 287,
      "valve_key": "item_keen_optic",
      "name": "Keen Optic",
      "shop_category": "neutral",
      "neutral_tier": 0,
      "is_recipe": false,
      "icon_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/keen_optic.png"
    }
  ]
}
''';

/// What a refresh would have committed: same schema, different items —
/// only the pieces the assertions need.
const _refreshedIndex = '''
{
  "schema_version": 1,
  "locale": "english",
  "items": [
    {
      "id": 999,
      "valve_key": "item_refreshed_sword",
      "name": "Refreshed Sword",
      "shop_category": "weapons",
      "neutral_tier": null,
      "is_recipe": false,
      "icon_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/refreshed_sword.png"
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
  SnapshotItemsRepository repository({
    required AssetLoader assets,
    InMemoryFileStore? files,
  }) => SnapshotItemsRepository(
    SnapshotSource(
      overrides: OverrideStore(files ?? InMemoryFileStore()),
      assets: assets,
    ),
  );

  test(
    'returns the item index parsed from the loader\'s asset content',
    () async {
      final repo = repository(assets: _FakeAssetLoader(_bundledIndex));

      final index = await repo.loadItems();

      expect(index.items, hasLength(2));
      expect(index.items.first.id, 1);
      expect(index.items.first.valveKey, 'item_blink');
      expect(index.items.first.name, 'Blink Dagger');
      expect(index.items.first.shopCategory, ShopCategory.weapons);
      expect(index.items.first.neutralTier, isNull);
      expect(index.items.last.shopCategory, ShopCategory.neutral);
      expect(index.items.last.name, 'Keen Optic');
      expect(index.items.last.neutralTier, 0);
    },
  );

  test('reads exactly the bundled English item index', () async {
    final loader = _FakeAssetLoader(_bundledIndex);

    await repository(assets: loader).loadItems();

    expect(loader.requestedPaths, ['assets/data/items.english.json']);
  });

  test('a committed override is preferred over the bundled asset', () async {
    final files = InMemoryFileStore();
    await OverrideStore(files).commit(
      manifest: SnapshotManifest(
        dataVersion: 99,
        fetchedAt: DateTime.utc(2026, 10, 21, 8),
      ),
      blobs: {'items.english.json': _refreshedIndex},
    );

    final repo = repository(
      assets: _FakeAssetLoader(_bundledIndex),
      files: files,
    );

    final index = await repo.loadItems();

    expect(index.items, hasLength(1));
    expect(index.items.single.name, 'Refreshed Sword');
  });
}
