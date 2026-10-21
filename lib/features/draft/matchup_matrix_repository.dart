import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'matchup_matrix.dart';

export 'matchup_matrix.dart';

/// Bundled hero matchups asset path.
const String heroMatchupsAssetPath = 'assets/data/hero_matchups.json';

/// The override-store unit name for the matchup matrix.
const String heroMatchupsUnit = 'hero_matchups.json';

/// Dedicated repository interface exposing the precomputed Matchup Matrix.
abstract interface class MatchupMatrixRepository {
  /// Loads the full Matchup Matrix, cached in memory after first read.
  Future<MatchupMatrix> loadMatchupMatrix();
}

/// Reads the matchup matrix from bundled snapshot assets or override files via [SnapshotSource].
class SnapshotMatchupMatrixRepository implements MatchupMatrixRepository {
  SnapshotMatchupMatrixRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<MatchupMatrix> loadMatchupMatrix() async {
    final raw = await _source.readUnit(heroMatchupsUnit, heroMatchupsAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Hero matchups file is not a JSON object');
    }
    return MatchupMatrix.fromJson(json);
  }
}
