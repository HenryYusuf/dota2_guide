import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'hero_detail.dart';

export 'hero_detail.dart' show heroDetailAssetPath, heroDetailUnitName;

/// Provides one Hero's complete detail page data to the Heroes tab.
///
/// Contract consumed via a Riverpod provider (the spec's single test seam):
/// the UI never touches files or HTTP; reads prefer a committed refresh
/// override and always fall back to the bundled per-Hero asset.
abstract interface class HeroDetailRepository {
  /// One Hero's detail, always available offline from bundled data.
  Future<HeroDetail> loadHeroDetail(int heroId);
}

/// Reads per-Hero details through the override-first [SnapshotSource]: a
/// committed refresh wins, the bundled snapshot is the unconditional
/// fallback. No HTTP client exists on this path (issue 03's posture), so
/// first launch works with no network.
class SnapshotHeroDetailRepository implements HeroDetailRepository {
  const SnapshotHeroDetailRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<HeroDetail> loadHeroDetail(int heroId) async {
    final raw = await _source.readUnit(
      heroDetailUnitName(heroId),
      heroDetailAssetPath(heroId),
    );
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Hero detail file $heroId is not a JSON object');
    }
    return HeroDetail.fromJson(json);
  }
}
