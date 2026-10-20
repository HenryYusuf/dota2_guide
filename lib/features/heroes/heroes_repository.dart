import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'hero_index.dart';

/// Bundled English hero index. Locale lives in the file name so future UI
/// languages are one more snapshot file, not a code change; the app reads the
/// English one (v1 is English-only, per spec).
const String heroIndexAssetPath = 'assets/data/heroes.english.json';

/// The override-store unit for the roster: same base name as the asset, so a
/// refreshed file is the same document, one generation newer.
const String heroIndexUnit = 'heroes.english.json';

/// Provides the Hero roster to the Heroes tab.
///
/// Contract consumed via a Riverpod provider (the spec's single test seam):
/// the UI never touches files or HTTP; reads prefer a committed refresh
/// override and always fall back to the bundled asset (issue 03).
abstract interface class HeroesRepository {
  /// The full roster, always available offline from bundled data.
  Future<List<HeroSummary>> loadHeroes();
}

/// Reads the roster through the override-first [SnapshotSource]: a committed
/// refresh wins, the bundled snapshot is the unconditional fallback.
///
/// No HTTP client exists on this path, which is what makes first launch work
/// with no network; refreshes write through a separate path (the refresher)
/// and are invisible here until committed.
class SnapshotHeroesRepository implements HeroesRepository {
  const SnapshotHeroesRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<List<HeroSummary>> loadHeroes() async {
    final raw = await _source.readUnit(heroIndexUnit, heroIndexAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Hero index file is not a JSON object');
    }
    return HeroIndex.fromJson(json).heroes;
  }
}
