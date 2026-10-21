// The Items refresh units: feed → app-schema file builders for the item
// index and every listable Item's detail ("one converter, two writers" —
// the same `itemIndexFromFeed` / `itemDetailFromFeed` the snapshot tool
// bundles, so a refreshed override is byte-shape compatible with the bundled
// assets).

import 'dart:convert';

import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/items/items_snapshot_unit.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/fake_datafeed_client.dart';

Map<String, dynamic> _itemlist(List<Map<String, Object?>> items) => {
  'result': {
    'status': 1,
    'meta': {'data_version': 42},
    'data': {'itemabilities': items},
  },
};

Map<String, Object?> _feedItemEntry(
  int id,
  String valveKey,
  String nameLoc, {
  int neutralTier = -1,
  List<dynamic> recipes = const [],
}) => {
  'id': id,
  'name': valveKey,
  'name_loc': nameLoc,
  'name_english_loc': nameLoc,
  'neutral_item_tier': neutralTier,
  'is_pregame_suggested': false,
  'is_earlygame_suggested': false,
  'is_lategame_suggested': false,
  'recipes': recipes,
  'is_innate': false,
};

Map<String, dynamic> _itemdataDoc({
  required int id,
  required String valveKey,
  required String nameLoc,
  int cost = 100,
  int neutralTier = 4294967295,
  String descLoc = '',
  List<dynamic> specialValues = const [],
}) => {
  'result': {
    'status': 1,
    'data': {
      'items': [
        {
          'id': id,
          'name': valveKey,
          'name_loc': nameLoc,
          'desc_loc': descLoc,
          'lore_loc': '',
          'notes_loc': [],
          'special_values': specialValues,
          'item_cost': cost,
          'item_neutral_tier': neutralTier,
        },
      ],
    },
  },
};

void main() {
  late FakeDatafeedClient feed;

  setUp(() => feed = FakeDatafeedClient());

  test(
    'the index unit emits the item catalogue under the bundled unit name',
    () async {
      feed.documents[itemListFeedUrl] = _itemlist([
        _feedItemEntry(1, 'item_blink', 'Blink Dagger'),
      ]);

      final files = await itemsSnapshotUnit.fetch(feed);

      expect(files.keys, [itemIndexUnit]);
      final index = ItemIndex.fromJson(
        jsonDecode(files[itemIndexUnit]!) as Map<String, dynamic>,
      );
      expect(index.items, hasLength(1));
      expect(index.items.single.name, 'Blink Dagger');
      expect(index.items.single.shopCategory, ShopCategory.caster);
    },
  );

  test(
    'the detail unit emits one file per listable Item with resolved costs',
    () async {
      // Recipe item 606 with cost 175, recipe for item 604
      feed.documents[itemListFeedUrl] = _itemlist([
        _feedItemEntry(1, 'item_blink', 'Blink Dagger'),
        _feedItemEntry(
          606,
          'item_recipe_arcane_blink',
          'Arcane Blink Recipe',
          recipes: [
            {
              'items': [1, 58],
            },
          ],
        ),
        _feedItemEntry(604, 'item_arcane_blink', 'Arcane Blink'),
      ]);

      feed.documents[itemDataFeedUrl(1)] = _itemdataDoc(
        id: 1,
        valveKey: 'item_blink',
        nameLoc: 'Blink Dagger',
        cost: 2250,
        descLoc: '<h1>Active: Blink</h1> Teleport 1200 units.',
      );
      feed.documents[itemDataFeedUrl(606)] = _itemdataDoc(
        id: 606,
        valveKey: 'item_recipe_arcane_blink',
        nameLoc: 'Arcane Blink Recipe',
        cost: 175,
      );
      feed.documents[itemDataFeedUrl(604)] = _itemdataDoc(
        id: 604,
        valveKey: 'item_arcane_blink',
        nameLoc: 'Arcane Blink',
        cost: 6800,
        descLoc: '<h1>Active: Arcane Blink</h1> Teleport and heal.',
      );

      final files = await itemDetailSnapshotUnit.fetch(feed);

      // Recipe item 606 is NOT listable, so only 1 and 604 are emitted
      expect(
        files.keys,
        unorderedEquals([itemDetailUnitName(1), itemDetailUnitName(604)]),
      );

      final blinkDetail = ItemDetail.fromJson(
        jsonDecode(files[itemDetailUnitName(1)]!) as Map<String, dynamic>,
      );
      expect(blinkDetail.item.name, 'Blink Dagger');
      expect(blinkDetail.item.totalCost, 2250);
      expect(blinkDetail.item.combinationCost, isNull);

      final arcaneBlinkDetail = ItemDetail.fromJson(
        jsonDecode(files[itemDetailUnitName(604)]!) as Map<String, dynamic>,
      );
      expect(arcaneBlinkDetail.item.name, 'Arcane Blink');
      expect(arcaneBlinkDetail.item.totalCost, 6800);
      expect(arcaneBlinkDetail.item.combinationCost, 175);
      expect(arcaneBlinkDetail.item.components, [1, 58]);
    },
  );
}
