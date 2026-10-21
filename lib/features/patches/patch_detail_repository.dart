import 'dart:convert';

import '../../core/data/asset_loader.dart';
import '../../core/data/datafeed_client.dart';
import '../../core/data/file_store.dart';
import '../heroes/hero_index.dart';
import '../heroes/heroes_repository.dart';
import '../items/item_index.dart';
import '../items/items_repository.dart';
import 'patch_detail.dart';
import 'patch_feed_to_detail.dart';

abstract interface class PatchDetailRepository {
  /// Loads one Patch's detail. Reads from permanent file cache or bundled asset
  /// first; fetches on demand from the official patch feed for unbundled older
  /// patches and permanently caches them. Throws on fetch failure so the UI can
  /// show an inline retry.
  Future<PatchDetail> loadPatchDetail(String patchNumber);
}

class LivePatchDetailRepository implements PatchDetailRepository {
  LivePatchDetailRepository({
    required this.fileStore,
    required this.assetLoader,
    required this.feedClient,
    required this.heroesRepository,
    required this.itemsRepository,
    this.locale = 'english',
  });

  final FileStore fileStore;
  final AssetLoader assetLoader;
  final DatafeedClient feedClient;
  final HeroesRepository heroesRepository;
  final ItemsRepository itemsRepository;
  final String locale;

  String _cachePath(String patchNumber) =>
      'patches/patch_$patchNumber.$locale.json';

  @override
  Future<PatchDetail> loadPatchDetail(String patchNumber) async {
    // 1. Permanent offline cache in file store
    final cached = await fileStore.readOrNull(_cachePath(patchNumber));
    if (cached != null) {
      final json = jsonDecode(cached);
      if (json is Map<String, dynamic>) {
        return PatchDetail.fromJson(json);
      }
    }

    // 2. Bundled snapshot asset (e.g. latest patch)
    try {
      final assetPath = patchDetailAssetPath(patchNumber, locale: locale);
      final raw = await assetLoader.readAsString(assetPath);
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return PatchDetail.fromJson(json);
      }
    } catch (_) {
      // Not bundled — fall through to on-demand fetch
    }

    // 3. On-demand fetch from official feed
    final url =
        '$datafeedBaseUrl/patchnotes?version=$patchNumber&language=$locale';
    final feedDoc = await feedClient.fetchJson(url);

    final heroes = await _safeLoadHeroes();
    final items = await _safeLoadItems();
    final heroMap = {for (final h in heroes) h.id: h};
    final itemMap = {for (final i in items) i.id: i};

    final appJson = patchDetailFromFeed(
      feedDoc,
      locale: locale,
      heroNameLookup: (id) => heroMap[id]?.localizedName,
      heroPortraitUrlLookup: (id) => heroMap[id]?.portraitUrl,
      itemNameLookup: (id) => itemMap[id]?.name,
      itemIconUrlLookup: (id) => itemMap[id]?.iconUrl,
    );

    // Save permanently offline
    await fileStore.write(_cachePath(patchNumber), jsonEncode(appJson));

    return PatchDetail.fromJson(appJson);
  }

  Future<List<HeroSummary>> _safeLoadHeroes() async {
    try {
      return await heroesRepository.loadHeroes();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ItemSummary>> _safeLoadItems() async {
    try {
      final index = await itemsRepository.loadItems();
      return index.items;
    } catch (_) {
      return const [];
    }
  }
}
