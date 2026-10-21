// The Items feature's refresh units: feed → app-schema file builders for the
// item index and every listable Item's detail page, emitting the same schema
// the snapshot tool bundles (one converter pair: `item_feed_to_index.dart`,
// `item_feed_to_detail.dart`), so an override is a fresher copy of the asset —
// nothing downstream changes.
//
// v1 is English-only (per spec): the units read the English feeds and store
// under the same unit names as the bundled assets' base names.

import 'dart:convert';

import '../../core/data/concurrent_map.dart';
import '../../core/data/datafeed_client.dart';
import '../../core/data/snapshot_refresher.dart';
import 'item_detail.dart';
import 'item_feed_to_detail.dart';
import 'item_feed_to_index.dart';
import 'item_index.dart';
import 'items_repository.dart';

/// The item index, registered with the refresher.
const SnapshotUnit itemsSnapshotUnit = SnapshotUnit(fetch: _fetchItemsIndex);

/// One detail file per LISTABLE Item (`item_<id>.english.json`) — recipe
/// price entries and unnamed internal entries emit nothing (their data is
/// folded into the Item they belong to). Fan-out budget is
/// [itemDetailFetchConcurrency]; a failure in any fetch throws and the whole
/// refresh cycle commits nothing (stale data preserved).
const SnapshotUnit itemDetailSnapshotUnit = SnapshotUnit(
  fetch: _fetchItemDetails,
);

Future<Map<String, String>> _fetchItemsIndex(DatafeedClient feed) async {
  final itemlist = await feed.fetchJson(itemListFeedUrl);
  return {
    itemIndexUnit: jsonEncode(itemIndexFromFeed(itemlist, locale: 'english')),
  };
}

Future<Map<String, String>> _fetchItemDetails(DatafeedClient feed) async {
  final itemlist = await feed.fetchJson(itemListFeedUrl);
  final index = ItemIndex.fromJson(
    itemIndexFromFeed(itemlist, locale: 'english'),
  );
  final entries = itemlistEntries(itemlist, locale: 'english');

  // One itemdata document per feed entry — including the `item_recipe_*`
  // entries, which are never emitted but whose `item_cost` IS what a build's
  // combination cost comes from.
  final docsByKey = Map.fromEntries(
    await mapConcurrently(entries, itemDetailFetchConcurrency, (entry) async {
      final valveKey = _required<String>(entry, 'name');
      final id = _required<num>(entry, 'id').toInt();
      return MapEntry(valveKey, await feed.fetchJson(itemDataFeedUrl(id)));
    }),
  );
  final costs = <String, int>{
    for (final (valveKey, cost) in docsByKey.values.map(itemCostFromFeed))
      valveKey: cost,
  };
  final recipes = itemRecipesFromItemlist(entries, costs);

  final files = index.items
      .where((item) => item.isListable)
      .map((item) {
        final detail = itemDetailFromFeed(
          docsByKey[item.valveKey]!,
          locale: 'english',
          recipe: recipes[item.valveKey],
        );
        return MapEntry(itemDetailUnitName(item.id), jsonEncode(detail));
      })
      .toList(growable: false);
  return Map.fromEntries(files);
}

T _required<T>(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! T) {
    throw FormatException(
      'Feed shape drift: "$key" missing or not $T',
      map.toString(),
    );
  }
  return value;
}
