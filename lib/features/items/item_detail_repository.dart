import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'item_detail.dart';

export 'item_detail.dart' show itemDetailAssetPath, itemDetailUnitName;

/// Provides one Item's complete detail page data to the Items tab.
///
/// Contract consumed via a Riverpod provider (the spec's single test seam):
/// the UI never touches files or HTTP; reads prefer a committed refresh
/// override and always fall back to the bundled per-Item asset.
abstract interface class ItemDetailRepository {
  /// One Item's detail, always available offline from bundled data.
  Future<ItemDetail> loadItemDetail(int itemId);
}

/// Reads per-Item details through the override-first [SnapshotSource]: a
/// committed refresh wins, the bundled snapshot is the unconditional
/// fallback. No HTTP client exists on this path, so first launch works with
/// no network.
class SnapshotItemDetailRepository implements ItemDetailRepository {
  const SnapshotItemDetailRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<ItemDetail> loadItemDetail(int itemId) async {
    final raw = await _source.readUnit(
      itemDetailUnitName(itemId),
      itemDetailAssetPath(itemId),
    );
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Item detail file $itemId is not a JSON object');
    }
    return ItemDetail.fromJson(json);
  }
}
