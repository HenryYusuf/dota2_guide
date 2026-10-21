import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import '../heroes/hero_index.dart';
import '../heroes/heroes_providers.dart';
import 'matchup_matrix_repository.dart';

/// Provider for the [MatchupMatrixRepository] seam.
final matchupMatrixRepositoryProvider = Provider<MatchupMatrixRepository>(
  (ref) => SnapshotMatchupMatrixRepository(ref.watch(snapshotSourceProvider)),
);

/// Precomputed matchup matrix, loaded once per app run and re-read on refresh.
final matchupMatrixProvider = FutureProvider<MatchupMatrix>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(matchupMatrixRepositoryProvider).loadMatchupMatrix();
});

/// A hero paired with their baseline empirical win rate.
class RankedHero {
  const RankedHero({required this.hero, required this.baseWinRate});

  final HeroSummary hero;
  final double baseWinRate;

  /// Win rate formatted as percentage string, e.g. "52.4%".
  String get winRatePercentage => '${(baseWinRate * 100).toStringAsFixed(1)}%';
}

/// The hero roster ranked by baseline win rate in descending order (highest win rate first).
final draftRankedHeroesProvider = Provider<AsyncValue<List<RankedHero>>>((ref) {
  final heroesAsync = ref.watch(heroesProvider);
  final matrixAsync = ref.watch(matchupMatrixProvider);

  if (heroesAsync.isLoading || matrixAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (heroesAsync.hasError) {
    return AsyncValue.error(heroesAsync.error!, heroesAsync.stackTrace!);
  }
  if (matrixAsync.hasError) {
    return AsyncValue.error(matrixAsync.error!, matrixAsync.stackTrace!);
  }

  final heroes = heroesAsync.value ?? const <HeroSummary>[];
  final matrix = matrixAsync.value ?? MatchupMatrix.empty();

  final ranked = heroes.map((h) {
    return RankedHero(hero: h, baseWinRate: matrix.getBaseWinRate(h.id));
  }).toList();

  ranked.sort((a, b) {
    final cmp = b.baseWinRate.compareTo(a.baseWinRate);
    if (cmp != 0) return cmp;
    return a.hero.localizedName.compareTo(b.hero.localizedName);
  });

  return AsyncValue.data(ranked);
});
