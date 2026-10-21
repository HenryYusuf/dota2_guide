import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'hero_roles.dart';

export 'hero_roles.dart';

/// Bundled hero roles asset path.
const String heroRolesAssetPath = 'assets/data/hero_roles.json';

/// The override-store unit name for hero roles.
const String heroRolesUnit = 'hero_roles.json';

/// Dedicated repository interface exposing official hero role levels.
abstract interface class HeroRolesRepository {
  /// Loads the full mapping of hero id to official [HeroRoleLevels].
  Future<Map<int, HeroRoleLevels>> loadHeroRoles();
}

/// Reads hero roles from bundled snapshot assets or override files via [SnapshotSource].
class SnapshotHeroRolesRepository implements HeroRolesRepository {
  SnapshotHeroRolesRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<Map<int, HeroRoleLevels>> loadHeroRoles() async {
    final raw = await _source.readUnit(heroRolesUnit, heroRolesAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Hero roles file is not a JSON object');
    }

    final result = <int, HeroRoleLevels>{};
    for (final entry in json.entries) {
      final heroId = int.tryParse(entry.key);
      if (heroId == null) {
        throw FormatException('Invalid hero id in roles file: ${entry.key}');
      }
      final rawLevels = entry.value;
      if (rawLevels is! List) {
        throw FormatException('Role levels for hero $heroId is not a list');
      }
      final intLevels = rawLevels.map((e) => (e as num).toInt()).toList();
      result[heroId] = HeroRoleLevels.fromList(intLevels);
    }

    return Map.unmodifiable(result);
  }
}
