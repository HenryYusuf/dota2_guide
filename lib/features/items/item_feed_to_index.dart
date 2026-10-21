// Valve itemlist feed → app-schema item index.
//
// Shared by the snapshot tool (bundled asset, `tool/snapshot.dart`) and the
// refresh unit (`items_snapshot_unit.dart`): both MUST emit the same schema,
// or a refreshed override would be unreadable by the parser that reads the
// bundled asset. One converter, two writers — drift is impossible by
// construction.
//
// Empirical notes (verified live 2026-10-21):
// - The feed answers under `result.data.itemabilities[]`, NOT `items[]` —
//   544 entries, same slim shape the ability list serves.
// - There is no shop category, cost, or effect text here: costs and texts
//   come from the per-Item `itemdata` feed (`item_feed_to_detail.dart`), and
//   the shop tab comes from the curated table (`shop_categories.dart`).

import '../../core/cdn/cdn_urls.dart';
import 'item_index.dart';
import 'shop_categories.dart';

/// Converts a whole itemlist feed document into the app-schema index the app
/// parses (same shape as the bundled asset).
Map<String, Object?> itemIndexFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
}) => {
  'schema_version': itemIndexSchemaVersion,
  'locale': locale,
  'items': itemlistEntries(feed, locale: locale).map(_itemToAppSchema).toList(),
};

Map<String, Object?> _itemToAppSchema(Map<String, dynamic> item) {
  final valveKey = _required<String>(item, 'name');
  final feedTier = _required<num>(item, 'neutral_item_tier').toInt();
  if (feedTier < nonNeutralTier) {
    throw FormatException(
      'Feed shape drift: neutral_item_tier $feedTier below $nonNeutralTier '
      'for $valveKey',
      valveKey,
    );
  }
  final isNeutral = feedTier >= 0;
  return {
    'id': _required<num>(item, 'id').toInt(),
    'valve_key': valveKey,
    'name': _stringOrEmpty(item, 'name_loc'),
    'shop_category': shopCategoryFor(
      valveKey: valveKey,
      neutralTier: feedTier,
    ).wireName,
    'neutral_tier': isNeutral ? feedTier : null,
    'is_recipe': isRecipeItemKey(valveKey),
    'icon_url': CdnUrls.itemIcon(valveKey),
  };
}

List<Map<String, dynamic>> itemlistEntries(
  Map<String, dynamic> feed, {
  required String locale,
}) {
  final result = feed['result'];
  if (result is! Map<String, dynamic>) {
    throw const FormatException('Feed shape drift: "result" missing');
  }
  switch (result['data']?['itemabilities']) {
    case final List<dynamic> list:
      return list.cast<Map<String, dynamic>>();
    case _ when result.containsKey('status'):
      throw FormatException(
        'Feed rejected language=$locale (status ${result['status']}). '
        'Use a Valve language token such as english, schinese, koreana, russian.',
      );
    case _:
      throw const FormatException(
        'Feed shape drift: result.data.itemabilities missing',
      );
  }
}

String _stringOrEmpty(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : '';
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
