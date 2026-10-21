import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'hero_patch_deltas.dart';

export 'hero_patch_deltas.dart';

/// Repository interface providing typed patch delta records per hero.
abstract interface class HeroPatchDeltaRepository {
  /// Loads patch history for one hero across recent patches.
  Future<HeroPatchHistory> loadHeroPatchHistory(int heroId);
}

/// Snapshot-backed implementation of [HeroPatchDeltaRepository] that reads
/// from bundled snapshot assets or override files via [SnapshotSource].
class SnapshotHeroPatchDeltaRepository implements HeroPatchDeltaRepository {
  SnapshotHeroPatchDeltaRepository(this._source, {this.locale = 'english'});

  final SnapshotSource _source;
  final String locale;

  Map<String, dynamic>? _cachedMap;

  @override
  Future<HeroPatchHistory> loadHeroPatchHistory(int heroId) async {
    if (_cachedMap == null) {
      try {
        final raw = await _source.readUnit(
          heroPatchDeltasUnitName(locale: locale),
          heroPatchDeltasAssetPath(locale: locale),
        );
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          _cachedMap = json;
        }
      } catch (_) {
        // Fall back to empty history
      }
    }

    final heroes = _cachedMap?['heroes'];
    if (heroes is Map) {
      final heroData = heroes[heroId.toString()] ?? heroes[heroId];
      if (heroData is Map<String, dynamic>) {
        return HeroPatchHistory.fromJson(heroId, heroData);
      }
    }

    return HeroPatchHistory(heroId: heroId, deltas: const []);
  }
}
