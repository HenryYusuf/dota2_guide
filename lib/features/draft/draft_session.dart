import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../heroes/hero_index.dart';
import 'hero_roles.dart';

export 'hero_roles.dart';

/// The two sides of a bilateral draft.
enum DraftTeam { ally, enemy }

/// Identifies an active slot target on the draft board.
@immutable
class DraftSlotTarget {
  const DraftSlotTarget({required this.team, required this.index});

  final DraftTeam team;
  final int index; // 0..4

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftSlotTarget && team == other.team && index == other.index;

  @override
  int get hashCode => Object.hash(team, index);

  @override
  String toString() => 'DraftSlotTarget(${team.name}[$index])';
}

/// Ephemeral in-memory state of an active draft session.
@immutable
class DraftSessionState {
  DraftSessionState({
    List<HeroSummary?>? alliedSlots,
    List<HeroSummary?>? enemySlots,
    this.focusedSlot,
    this.selectedPosition,
  }) : alliedSlots = List.unmodifiable(
         alliedSlots ?? List<HeroSummary?>.filled(5, null),
       ),
       enemySlots = List.unmodifiable(
         enemySlots ?? List<HeroSummary?>.filled(5, null),
       );

  final List<HeroSummary?> alliedSlots;
  final List<HeroSummary?> enemySlots;
  final DraftSlotTarget? focusedSlot;
  final DraftPosition? selectedPosition;

  List<int> get alliedHeroIds =>
      alliedSlots.whereType<HeroSummary>().map((h) => h.id).toList();

  List<int> get enemyHeroIds =>
      enemySlots.whereType<HeroSummary>().map((h) => h.id).toList();

  Set<int> get assignedHeroIds => {...alliedHeroIds, ...enemyHeroIds};

  bool isHeroAssigned(int heroId) => assignedHeroIds.contains(heroId);

  bool get isEmpty => alliedHeroIds.isEmpty && enemyHeroIds.isEmpty;

  /// Returns the hero currently occupying [target], if any.
  HeroSummary? heroAt(DraftSlotTarget target) {
    final slots = target.team == DraftTeam.ally ? alliedSlots : enemySlots;
    return slots[target.index];
  }

  /// Returns the next empty slot target after [current], checking the same team
  /// first then falling back to the opposing team.
  DraftSlotTarget? nextEmptySlot(DraftSlotTarget current) {
    final sameTeamSlots = current.team == DraftTeam.ally
        ? alliedSlots
        : enemySlots;
    final nextSameTeam = sameTeamSlots.indexWhere((s) => s == null);
    if (nextSameTeam != -1) {
      return DraftSlotTarget(team: current.team, index: nextSameTeam);
    }

    final otherTeam = current.team == DraftTeam.ally
        ? DraftTeam.enemy
        : DraftTeam.ally;
    final otherTeamSlots = otherTeam == DraftTeam.ally
        ? alliedSlots
        : enemySlots;
    final nextOtherTeam = otherTeamSlots.indexWhere((s) => s == null);
    if (nextOtherTeam != -1) {
      return DraftSlotTarget(team: otherTeam, index: nextOtherTeam);
    }
    return null;
  }

  /// Returns a copy of the state with [hero] assigned to [target].
  DraftSessionState withSlotAssigned(DraftSlotTarget target, HeroSummary hero) {
    final isAlly = target.team == DraftTeam.ally;
    final currentSlots = isAlly ? alliedSlots : enemySlots;
    final updatedSlots = List<HeroSummary?>.from(currentSlots);
    updatedSlots[target.index] = hero;

    final updated = copyWith(
      alliedSlots: isAlly ? updatedSlots : null,
      enemySlots: !isAlly ? updatedSlots : null,
    );
    final nextFocus = updated.nextEmptySlot(target);
    return updated.copyWith(focusedSlot: () => nextFocus);
  }

  /// Returns a copy of the state with [target] cleared.
  DraftSessionState withSlotCleared(DraftSlotTarget target) {
    final isAlly = target.team == DraftTeam.ally;
    final currentSlots = isAlly ? alliedSlots : enemySlots;
    if (currentSlots[target.index] == null) {
      return copyWith(focusedSlot: () => target);
    }

    final updatedSlots = List<HeroSummary?>.from(currentSlots);
    updatedSlots[target.index] = null;

    return copyWith(
      alliedSlots: isAlly ? updatedSlots : null,
      enemySlots: !isAlly ? updatedSlots : null,
      focusedSlot: () => target,
    );
  }

  DraftSessionState copyWith({
    List<HeroSummary?>? alliedSlots,
    List<HeroSummary?>? enemySlots,
    DraftSlotTarget? Function()? focusedSlot,
    DraftPosition? Function()? selectedPosition,
  }) {
    return DraftSessionState(
      alliedSlots: alliedSlots ?? this.alliedSlots,
      enemySlots: enemySlots ?? this.enemySlots,
      focusedSlot: focusedSlot != null ? focusedSlot() : this.focusedSlot,
      selectedPosition: selectedPosition != null
          ? selectedPosition()
          : this.selectedPosition,
    );
  }
}

/// State notifier managing in-memory draft selections and slot focus.
class DraftSessionNotifier extends Notifier<DraftSessionState> {
  @override
  DraftSessionState build() => DraftSessionState();

  /// Sets or clears the active competitive position filter.
  void setPositionFilter(DraftPosition? position) {
    state = state.copyWith(selectedPosition: () => position);
  }

  /// Sets the currently active slot target on the board.
  void focusSlot(DraftSlotTarget? target) {
    state = state.copyWith(focusedSlot: () => target);
  }

  /// Assigns [hero] to the active slot (or first empty slot if none focused).
  ///
  /// Ignores the call if [hero] is already assigned to any slot.
  void assignHero(HeroSummary hero) {
    if (state.isHeroAssigned(hero.id)) return;

    var target = state.focusedSlot;
    if (target == null) {
      final emptyAlly = state.alliedSlots.indexWhere((s) => s == null);
      if (emptyAlly != -1) {
        target = DraftSlotTarget(team: DraftTeam.ally, index: emptyAlly);
      } else {
        final emptyEnemy = state.enemySlots.indexWhere((s) => s == null);
        if (emptyEnemy != -1) {
          target = DraftSlotTarget(team: DraftTeam.enemy, index: emptyEnemy);
        }
      }
    }

    if (target == null) return;
    state = state.withSlotAssigned(target, hero);
  }

  /// Clears the hero in [target] slot and focuses it.
  void clearSlot(DraftSlotTarget target) {
    state = state.withSlotCleared(target);
  }

  /// Resets all 10 slots and clears focus.
  void resetDraft() {
    state = DraftSessionState();
  }
}

/// Provider for the active ephemeral draft session.
final draftSessionProvider =
    NotifierProvider<DraftSessionNotifier, DraftSessionState>(
      DraftSessionNotifier.new,
    );
