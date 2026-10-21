import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'item_index.dart';

/// Bundled English item index. Locale lives in the file name so future UI
/// languages are one more snapshot file, not a code change; the app reads the
/// English one (v1 is English-only, per spec).
const String itemIndexAssetPath = 'assets/data/items.english.json';

/// The override-store unit for the index: same base name as the asset, so a
/// refreshed file is the same document, one generation newer.
const String itemIndexUnit = 'items.english.json';

/// Provides the Item catalogue to the Items tab.
///
/// Contract consumed via a Riverpod provider (the spec's single test seam):
/// the UI never touches files or HTTP; reads prefer a committed refresh
/// override and always fall back to the bundled asset.
abstract interface class ItemsRepository {
  /// The whole Item index, always available offline from bundled data.
  Future<ItemIndex> loadItems();
}

/// Reads the index through the override-first [SnapshotSource]: a committed
/// refresh wins, the bundled snapshot is the unconditional fallback.
///
/// No HTTP client exists on this path, which is what makes first launch work
/// with no network; refreshes write through a separate path (the refresher)
/// and are invisible here until committed.
class SnapshotItemsRepository implements ItemsRepository {
  const SnapshotItemsRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<ItemIndex> loadItems() async {
    final raw = await _source.readUnit(itemIndexUnit, itemIndexAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Item index file is not a JSON object');
    }
    return ItemIndex.fromJson(json);
  }
}
