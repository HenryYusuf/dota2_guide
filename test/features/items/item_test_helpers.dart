import 'package:flutter/widgets.dart';

import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_detail_repository.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';

/// Test stub for item icons that avoids network / CDN requests.
Widget stubItemIcon(BuildContext context, String url, String itemName) =>
    SizedBox(key: ValueKey<String>(url));

/// Creates a test [ItemDetail] fixture with sensible defaults.
ItemDetail createTestItemDetail({
  required int id,
  required String name,
  required int totalCost,
  int? combinationCost,
  List<int> components = const [],
  List<ItemAttribute> attributes = const [],
  List<ItemEffect> effects = const [],
  List<String> notes = const [],
  String lore = '',
  ShopCategory shopCategory = ShopCategory.caster,
  int? neutralTier,
}) {
  return ItemDetail(
    schemaVersion: 1,
    locale: 'english',
    item: ItemProfile(
      id: id,
      valveKey: 'item_$id',
      name: name,
      iconUrl:
          'https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/$id.png',
      shopCategory: shopCategory,
      neutralTier: neutralTier,
      totalCost: totalCost,
      combinationCost: combinationCost,
      components: components,
      attributes: attributes,
      effects: effects,
      notes: notes,
      lore: lore,
    ),
  );
}

/// Fake repository backed by an in-memory map of item details.
class FakeItemDetailRepository implements ItemDetailRepository {
  FakeItemDetailRepository([Map<int, ItemDetail>? items])
    : _items = items ?? const {};

  final Map<int, ItemDetail> _items;

  @override
  Future<ItemDetail> loadItemDetail(int itemId) async {
    final item = _items[itemId];
    if (item == null) {
      throw Exception('Item $itemId not found in test repository');
    }
    return item;
  }
}
