import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/asset_loader.dart';
import '../../core/data/file_store.dart';
import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_refresher.dart';
import '../../core/data/snapshot_source.dart';
import '../heroes/heroes_providers.dart';
import '../heroes/widgets/hero_portrait.dart';
import '../items/items_providers.dart';
import '../items/widgets/item_icon.dart';
import 'patch_detail.dart';
import 'patch_detail_repository.dart';
import 'patch_index.dart';
import 'patches_repository.dart';

/// Contract consumed by the Patches tab for listing patches.
final patchesRepositoryProvider = Provider<PatchesRepository>(
  (ref) => SnapshotPatchesRepository(ref.watch(snapshotSourceProvider)),
);

/// The bundled Patch index, parsed once per app run, plus re-read after
/// every successful refresh (epoch bump).
final patchesProvider = FutureProvider<PatchIndex>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(patchesRepositoryProvider).loadPatchIndex();
});

/// One Patch's detail repository: fetches on-demand older patches, caches
/// permanently in fileStore, reads bundled latest from assets.
final patchDetailRepositoryProvider = Provider<PatchDetailRepository>(
  (ref) => LivePatchDetailRepository(
    fileStore: ref.watch(fileStoreProvider),
    assetLoader: ref.watch(assetLoaderProvider),
    feedClient: ref.watch(datafeedClientProvider),
    heroesRepository: ref.watch(heroesRepositoryProvider),
    itemsRepository: ref.watch(itemsRepositoryProvider),
  ),
);

/// One Patch's detail page data.
final patchDetailProvider = FutureProvider.family<PatchDetail, String>((
  ref,
  patchNumber,
) {
  return ref.watch(patchDetailRepositoryProvider).loadPatchDetail(patchNumber);
});

/// Injected Hero icon builder for patch change groups.
typedef PatchHeroIconBuilder = Widget Function(
  BuildContext context,
  String? url,
  String heroName,
);

/// Injected Item icon builder for patch change groups.
typedef PatchItemIconBuilder = Widget Function(
  BuildContext context,
  String? url,
  String itemName,
);

final patchHeroIconBuilderProvider = Provider<PatchHeroIconBuilder>(
  (ref) =>
      (context, url, heroName) =>
          HeroPortrait(url: url ?? '', heroName: heroName),
);

final patchItemIconBuilderProvider = Provider<PatchItemIconBuilder>(
  (ref) =>
      (context, url, itemName) => ItemIcon(url: url ?? '', itemName: itemName),
);
