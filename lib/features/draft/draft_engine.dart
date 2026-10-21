import '../heroes/hero_index.dart';
import 'matchup_matrix.dart';

/// Candidate hero evaluated for draft recommendations.
class DraftCandidate {
  const DraftCandidate({
    required this.hero,
    required this.baseWinRate,
    this.advantageScore,
    this.isAssigned = false,
  });

  final HeroSummary hero;
  final double baseWinRate;
  final double? advantageScore;
  final bool isAssigned;

  bool get hasAdvantageScore => advantageScore != null;

  /// Formatted baseline win rate, e.g. "52.4%".
  String get baseWinRatePercentage =>
      '${(baseWinRate * 100).toStringAsFixed(1)}%';

  /// Alias for backward compatibility.
  String get winRatePercentage => baseWinRatePercentage;

  /// Formatted advantage badge, e.g. "+3.4%" or "-1.8%".
  String get advantagePercentage {
    final score = advantageScore ?? 0.0;
    final sign = score < 0 ? '-' : '+';
    final absVal = (score.abs() * 100).toStringAsFixed(1);
    return '$sign$absVal%';
  }
}

/// Pure Dart calculation engine for the Draft Picker.
class DraftEngine {
  const DraftEngine._();

  /// Calculates normalized Advantage for a hero against an opposing enemy hero.
  ///
  /// Advantage(H, E) = (HeadToHeadWinRate(H vs E) - BaseWinRate(H)) - (BaseWinRate(E) - 0.50)
  static double computeAdvantage({
    required MatchupMatrix matrix,
    required int heroId,
    required int enemyHeroId,
  }) {
    final matchup = matrix.getMatchup(heroId, enemyHeroId);
    final headToHeadWinRate = matchup != null && matchup.totalGames > 0
        ? matchup.winRate
        : 0.50;
    final baseH = matrix.getBaseWinRate(heroId);
    final baseE = matrix.getBaseWinRate(enemyHeroId);

    return (headToHeadWinRate - baseH) - (baseE - 0.50);
  }

  /// Calculates arithmetic mean advantage score for [heroId] against all active [enemyHeroIds].
  ///
  /// Returns 0.0 if [enemyHeroIds] is empty.
  static double computeCompositeScore({
    required MatchupMatrix matrix,
    required int heroId,
    required List<int> enemyHeroIds,
  }) {
    if (enemyHeroIds.isEmpty) return 0.0;

    double totalAdvantage = 0.0;
    for (final enemyId in enemyHeroIds) {
      totalAdvantage += computeAdvantage(
        matrix: matrix,
        heroId: heroId,
        enemyHeroId: enemyId,
      );
    }
    return totalAdvantage / enemyHeroIds.length;
  }

  /// Evaluates and ranks candidate heroes.
  ///
  /// When [enemyHeroIds] is not empty, ranks heroes by descending Advantage score.
  /// When [enemyHeroIds] is empty, ranks heroes by descending baseline win rate.
  /// Ties are broken by name alphabetically.
  static List<DraftCandidate> rankCandidates({
    required MatchupMatrix matrix,
    required List<HeroSummary> heroes,
    required List<int> enemyHeroIds,
    required List<int> alliedHeroIds,
  }) {
    final assignedIds = {...enemyHeroIds, ...alliedHeroIds};
    final hasEnemies = enemyHeroIds.isNotEmpty;

    final candidates = heroes.map((hero) {
      final baseWinRate = matrix.getBaseWinRate(hero.id);
      final isAssigned = assignedIds.contains(hero.id);
      final advantageScore = hasEnemies
          ? computeCompositeScore(
              matrix: matrix,
              heroId: hero.id,
              enemyHeroIds: enemyHeroIds,
            )
          : null;

      return DraftCandidate(
        hero: hero,
        baseWinRate: baseWinRate,
        advantageScore: advantageScore,
        isAssigned: isAssigned,
      );
    }).toList();

    candidates.sort((a, b) {
      if (a.isAssigned != b.isAssigned) {
        return a.isAssigned ? 1 : -1;
      }
      if (hasEnemies) {
        final scoreA = a.advantageScore ?? 0.0;
        final scoreB = b.advantageScore ?? 0.0;
        final cmp = scoreB.compareTo(scoreA);
        if (cmp != 0) return cmp;
      } else {
        final cmp = b.baseWinRate.compareTo(a.baseWinRate);
        if (cmp != 0) return cmp;
      }
      return a.hero.localizedName.compareTo(b.hero.localizedName);
    });

    return candidates;
  }

  /// Returns only unassigned candidate heroes suitable as counter recommendations.
  static List<DraftCandidate> getRecommendations({
    required MatchupMatrix matrix,
    required List<HeroSummary> heroes,
    required List<int> enemyHeroIds,
    required List<int> alliedHeroIds,
  }) {
    return rankCandidates(
      matrix: matrix,
      heroes: heroes,
      enemyHeroIds: enemyHeroIds,
      alliedHeroIds: alliedHeroIds,
    ).where((c) => !c.isAssigned).toList();
  }
}
