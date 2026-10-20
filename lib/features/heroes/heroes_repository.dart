import 'dart:convert';

import '../../core/data/asset_loader.dart';
import 'hero_index.dart';

/// Bundled English hero index. Locale lives in the file name so future UI
/// languages are one more snapshot file, not a code change; the app reads the
/// English one (v1 is English-only, per spec).
const String heroIndexAssetPath = 'assets/data/heroes.english.json';

/// Provides the Hero roster to the Heroes tab.
///
/// Contract consumed via a Riverpod provider (the spec's single test seam):
/// the UI never touches files, and implementations may later prefer refresh
/// overrides over bundled assets without the screen knowing (issue 03).
abstract interface class HeroesRepository {
  /// The full roster, always available offline from bundled data.
  Future<List<HeroSummary>> loadHeroes();
}

/// Reads the roster straight from the bundled snapshot via an [AssetLoader].
///
/// Asset-first by construction: no HTTP client exists on this path, which is
/// what makes first launch work with no network.
class AssetHeroesRepository implements HeroesRepository {
  const AssetHeroesRepository(this._loader);

  final AssetLoader _loader;

  @override
  Future<List<HeroSummary>> loadHeroes() async {
    final raw = await _loader.readAsString(heroIndexAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Hero index file is not a JSON object');
    }
    return HeroIndex.fromJson(json).heroes;
  }
}
