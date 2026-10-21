import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import '../heroes/hero_index.dart';
import '../heroes/heroes_providers.dart';
import 'draft_engine.dart';
import 'draft_session.dart';
import 'hero_roles_repository.dart';
import 'matchup_matrix_repository.dart';

export 'draft_engine.dart';
export 'draft_session.dart';
export 'hero_roles_repository.dart';
export 'matchup_matrix_repository.dart';

/// Provider for the [MatchupMatrixRepository] seam.
final matchupMatrixRepositoryProvider = Provider<MatchupMatrixRepository>(
  (ref) => SnapshotMatchupMatrixRepository(ref.watch(snapshotSourceProvider)),
);

/// Precomputed matchup matrix, loaded once per app run and re-read on refresh.
final matchupMatrixProvider = FutureProvider<MatchupMatrix>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(matchupMatrixRepositoryProvider).loadMatchupMatrix();
});

/// Provider for the [HeroRolesRepository] seam.
final heroRolesRepositoryProvider = Provider<HeroRolesRepository>(
  (ref) => SnapshotHeroRolesRepository(ref.watch(snapshotSourceProvider)),
);

/// Precomputed hero role levels, loaded once per app run and re-read on refresh.
final heroRolesProvider = FutureProvider<Map<int, HeroRoleLevels>>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(heroRolesRepositoryProvider).loadHeroRoles();
});

/// Real-time team composition diagnostics for the current allied picks.
final draftCompositionDiagnosticsProvider =
    Provider<AsyncValue<CompositionDiagnostics>>((ref) {
      final rolesAsync = ref.watch(heroRolesProvider);
      final draftSession = ref.watch(draftSessionProvider);

      if (rolesAsync.isLoading) {
        return const AsyncValue.loading();
      }
      if (rolesAsync.hasError) {
        return AsyncValue.error(rolesAsync.error!, rolesAsync.stackTrace!);
      }

      final rolesMap = rolesAsync.value ?? const <int, HeroRoleLevels>{};
      final alliedRoles = draftSession.alliedSlots
          .whereType<HeroSummary>()
          .map((hero) => rolesMap[hero.id] ?? const HeroRoleLevels())
          .toList();

      final diagnostics = DraftEngine.evaluateComposition(alliedRoles);
      return AsyncValue.data(diagnostics);
    });

/// The candidate heroes evaluated and ranked in real time by the [DraftEngine],
/// optionally filtered by competitive position.
final draftRankedHeroesProvider = Provider<AsyncValue<List<DraftCandidate>>>((
  ref,
) {
  final heroesAsync = ref.watch(heroesProvider);
  final matrixAsync = ref.watch(matchupMatrixProvider);
  final rolesAsync = ref.watch(heroRolesProvider);
  final draftSession = ref.watch(draftSessionProvider);

  if (heroesAsync.isLoading || matrixAsync.isLoading || rolesAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (heroesAsync.hasError) {
    return AsyncValue.error(heroesAsync.error!, heroesAsync.stackTrace!);
  }
  if (matrixAsync.hasError) {
    return AsyncValue.error(matrixAsync.error!, matrixAsync.stackTrace!);
  }
  if (rolesAsync.hasError) {
    return AsyncValue.error(rolesAsync.error!, rolesAsync.stackTrace!);
  }

  final heroes = heroesAsync.value ?? const <HeroSummary>[];
  final matrix = matrixAsync.value ?? MatchupMatrix.empty();
  final roles = rolesAsync.value ?? const <int, HeroRoleLevels>{};

  final ranked = DraftEngine.rankCandidates(
    matrix: matrix,
    heroes: heroes,
    enemyHeroIds: draftSession.enemyHeroIds,
    alliedHeroIds: draftSession.alliedHeroIds,
  );

  final position = draftSession.selectedPosition;
  if (position == null) {
    return AsyncValue.data(ranked);
  }

  final filtered = ranked.where((candidate) {
    final role = roles[candidate.hero.id];
    return role?.isSuitableForPosition(position) ?? false;
  }).toList();

  return AsyncValue.data(filtered);
});
