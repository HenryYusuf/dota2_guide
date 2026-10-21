// Repository seam: one Item's detail is read override-first — a committed
// refresh override when present, else the bundled per-Item asset behind an
// injectable loader, never HTTP ("refreshed data wins" is pinned below;
// the schema itself is pinned by the parsing test over the real fixture).

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_detail_repository.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/in_memory_file_store.dart';

String _detailFile(String name, {int id = 1, int totalCost = 2250}) =>
    '''
{
  "schema_version": 1,
  "locale": "english",
  "item": {
    "id": $id,
    "valve_key": "item_blink",
    "name": "$name",
    "icon_url": "https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/blink.png",
    "shop_category": "weapons",
    "neutral_tier": null,
    "total_cost": $totalCost,
    "combination_cost": null,
    "components": [],
    "attributes": [],
    "effects": [
      {
        "kind": "active",
        "title": "Blink",
        "text": "Teleport to a target point up to 1200 units away."
      }
    ],
    "notes": [],
    "lore": "A cunning dagger used to sneak into enemy territory."
  }
}
''';

class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.contentByPath);

  final Map<String, String> contentByPath;
  final List<String> requestedPaths = [];

  @override
  Future<String> readAsString(String assetPath) async {
    requestedPaths.add(assetPath);
    final content = contentByPath[assetPath];
    if (content == null) {
      throw StateError('Asset not in fake: $assetPath');
    }
    return content;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SnapshotItemDetailRepository repository({
    required AssetLoader assets,
    InMemoryFileStore? files,
  }) => SnapshotItemDetailRepository(
    SnapshotSource(
      overrides: OverrideStore(files ?? InMemoryFileStore()),
      assets: assets,
    ),
  );

  test(
    'returns the Item detail parsed from the loader\'s asset content',
    () async {
      final repo = repository(
        assets: _FakeAssetLoader({
          'assets/data/item_1.english.json': _detailFile('Blink Dagger', id: 1),
        }),
      );

      final detail = await repo.loadItemDetail(1);

      expect(detail.item.id, 1);
      expect(detail.item.name, 'Blink Dagger');
      expect(detail.item.shopCategory, ShopCategory.weapons);
      expect(detail.item.totalCost, 2250);
      expect(detail.item.effects, hasLength(1));
      expect(detail.item.effects.first.kind, ItemEffectKind.active);
      expect(detail.item.effects.first.title, 'Blink');
    },
  );

  test('reads exactly the requested Item\'s detail file', () async {
    final loader = _FakeAssetLoader({
      'assets/data/item_1.english.json': _detailFile('Blink Dagger', id: 1),
    });

    await repository(assets: loader).loadItemDetail(1);

    expect(loader.requestedPaths, ['assets/data/item_1.english.json']);
  });

  test('a committed override is preferred over the bundled asset', () async {
    final files = InMemoryFileStore();
    await OverrideStore(files).commit(
      manifest: SnapshotManifest(
        dataVersion: 99,
        fetchedAt: DateTime.utc(2026, 10, 21, 8),
      ),
      blobs: {'item_1.english.json': _detailFile('Refreshed Dagger', id: 1)},
    );

    final repo = repository(
      assets: _FakeAssetLoader({
        'assets/data/item_1.english.json': _detailFile('Bundled Dagger', id: 1),
      }),
      files: files,
    );

    final detail = await repo.loadItemDetail(1);

    expect(detail.item.name, 'Refreshed Dagger');
  });
}
