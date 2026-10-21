/// Pairwise matchup win/loss aggregates for a single hero vs an opposing hero.
class MatchupRecord {
  const MatchupRecord({required this.wins, required this.totalGames});

  final int wins;
  final int totalGames;

  /// Win rate against this opponent (0.0 to 1.0). Defaults to 0.50 if no games.
  double get winRate => totalGames > 0 ? wins / totalGames : 0.50;
}

/// Precomputed pairwise dataset recording wins and games played between hero pairs,
/// plus precomputed baseline win rates for all heroes.
class MatchupMatrix {
  MatchupMatrix({required this.matchups, required this.baselineWinRates});

  /// Pairwise lookup: `matchups[heroId][opponentHeroId]`.
  final Map<int, Map<int, MatchupRecord>> matchups;

  /// Empirical baseline win rate per hero across all matchups.
  final Map<int, double> baselineWinRates;

  /// Empty matrix fallback.
  factory MatchupMatrix.empty() =>
      MatchupMatrix(matchups: const {}, baselineWinRates: const {});

  /// Deserializes from compact JSON mapping hero IDs to opponent record pairs `[wins, total_games]`.
  factory MatchupMatrix.fromJson(Map<String, dynamic> json) {
    final parsedMatchups = <int, Map<int, MatchupRecord>>{};
    final computedBaselines = <int, double>{};

    for (final entry in json.entries) {
      final heroId = int.tryParse(entry.key);
      if (heroId == null || entry.value is! Map) continue;

      final opponentMap = entry.value as Map;
      final heroRecords = <int, MatchupRecord>{};
      int heroTotalWins = 0;
      int heroTotalGames = 0;

      for (final oppEntry in opponentMap.entries) {
        final oppId = int.tryParse(oppEntry.key.toString());
        if (oppId == null || oppEntry.value is! List) continue;

        final stats = oppEntry.value as List;
        if (stats.length >= 2 && stats[0] is num && stats[1] is num) {
          final wins = (stats[0] as num).toInt();
          final games = (stats[1] as num).toInt();
          heroRecords[oppId] = MatchupRecord(wins: wins, totalGames: games);
          heroTotalWins += wins;
          heroTotalGames += games;
        }
      }

      parsedMatchups[heroId] = heroRecords;
      if (heroTotalGames > 0) {
        computedBaselines[heroId] = heroTotalWins / heroTotalGames;
      }
    }

    return MatchupMatrix(
      matchups: parsedMatchups,
      baselineWinRates: computedBaselines,
    );
  }

  /// Returns matchup record for [heroId] against [opponentHeroId], if known.
  MatchupRecord? getMatchup(int heroId, int opponentHeroId) {
    return matchups[heroId]?[opponentHeroId];
  }

  /// Returns empirical baseline win rate for [heroId]. Defaults to 0.50 if unknown.
  double getBaseWinRate(int heroId) {
    return baselineWinRates[heroId] ?? 0.50;
  }
}
