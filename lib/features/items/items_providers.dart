import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import 'item_detail.dart';
import 'item_detail_repository.dart';
import 'item_index.dart';
import 'items_repository.dart';
import 'widgets/item_icon.dart';

/// Builds the widget that shows one Item's icon.
///
/// Injected through a provider so widget tests can stand in for the Valve CDN
/// (media streams at runtime and is never bundled — ADR-0001; spec: widget
/// tests must not touch HTTP, assets, or CDN).
typedef ItemIconBuilder = Widget Function(
  BuildContext context,
  String url,
  String itemName,
);

/// The Item catalogue contract the Items tab consumes (the spec's single test
/// seam: UI → repository provider, never UI → HTTP/files). Reads prefer a
/// committed refresh override and fall back to the bundled snapshot.
final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => SnapshotItemsRepository(ref.watch(snapshotSourceProvider)),
);

/// The bundled Item index, parsed once per app run — plus re-read after every
/// successful refresh (epoch bump), so a version bump shows up live.
final itemsProvider = FutureProvider<ItemIndex>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(itemsRepositoryProvider).loadItems();
});

/// One Item's detail page data, read through the override-first source —
/// same contract as the index, one file per Item.
final itemDetailRepositoryProvider = Provider<ItemDetailRepository>(
  (ref) => SnapshotItemDetailRepository(ref.watch(snapshotSourceProvider)),
);

/// One Item's detail, re-read after every successful refresh so a version
/// bump shows up on the detail page too, not just the list.
final itemDetailProvider = FutureProvider.family<ItemDetail, int>((
  ref,
  itemId,
) {
  ref.watch(refreshEpochProvider);
  return ref.watch(itemDetailRepositoryProvider).loadItemDetail(itemId);
});

/// Default icon: streams from the CDN with a quiet fallback while loading or
/// when offline (same posture as the heroes' [portraitBuilderProvider]).
final itemIconBuilderProvider = Provider<ItemIconBuilder>(
  (ref) =>
      (context, url, itemName) => ItemIcon(url: url, itemName: itemName),
);
