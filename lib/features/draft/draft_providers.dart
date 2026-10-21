import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import '../heroes/hero_index.dart';
import '../heroes/heroes_providers.dart';
import 'draft_engine.dart';
import 'draft_session.dart';
import 'matchup_matrix_repository.dart';

export 'draft_engine.dart';
export 'draft_session.dart';

/// Provider for the [MatchupMatrixRepository] seam.
final matchupMatrixRepositoryProvider = Provider<MatchupMatrixRepository>(
  (ref) => SnapshotMatchupMatrixRepository(ref.watch(snapshotSourceProvider)),
);

/// Precomputed matchup matrix, loaded once per app run and re-read on refresh.
final matchupMatrixProvider = FutureProvider<MatchupMatrix>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(matchupMatrixRepositoryProvider).loadMatchupMatrix();
});

/// Backwards-compatible alias for [DraftCandidate].
typedef RankedHero = DraftCandidate;

/// The candidate heroes evaluated and ranked in real time by the [DraftEngine].
final draftRankedHeroesProvider = Provider<AsyncValue<List<DraftCandidate>>>((
  ref,
) {
  final heroesAsync = ref.watch(heroesProvider);
  final matrixAsync = ref.watch(matchupMatrixProvider);
  final draftSession = ref.watch(draftSessionProvider);

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

  final ranked = DraftEngine.rankCandidates(
    matrix: matrix,
    heroes: heroes,
    enemyHeroIds: draftSession.enemyHeroIds,
    alliedHeroIds: draftSession.alliedHeroIds,
  );

  return AsyncValue.data(ranked);
});
