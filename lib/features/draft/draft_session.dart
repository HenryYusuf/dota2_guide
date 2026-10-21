import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../heroes/hero_index.dart';

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
  }) : alliedSlots = List.unmodifiable(
         alliedSlots ?? List<HeroSummary?>.filled(5, null),
       ),
       enemySlots = List.unmodifiable(
         enemySlots ?? List<HeroSummary?>.filled(5, null),
       );

  final List<HeroSummary?> alliedSlots;
  final List<HeroSummary?> enemySlots;
  final DraftSlotTarget? focusedSlot;

  List<int> get alliedHeroIds =>
      alliedSlots.whereType<HeroSummary>().map((h) => h.id).toList();

  List<int> get enemyHeroIds =>
      enemySlots.whereType<HeroSummary>().map((h) => h.id).toList();

  Set<int> get assignedHeroIds => {...alliedHeroIds, ...enemyHeroIds};

  bool isHeroAssigned(int heroId) => assignedHeroIds.contains(heroId);

  bool get isEmpty => alliedHeroIds.isEmpty && enemyHeroIds.isEmpty;

  DraftSessionState copyWith({
    List<HeroSummary?>? alliedSlots,
    List<HeroSummary?>? enemySlots,
    DraftSlotTarget? Function()? focusedSlot,
  }) {
    return DraftSessionState(
      alliedSlots: alliedSlots ?? this.alliedSlots,
      enemySlots: enemySlots ?? this.enemySlots,
      focusedSlot: focusedSlot != null ? focusedSlot() : this.focusedSlot,
    );
  }
}

/// State notifier managing in-memory draft selections and slot focus.
class DraftSessionNotifier extends Notifier<DraftSessionState> {
  @override
  DraftSessionState build() => DraftSessionState();

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

    final isAlly = target.team == DraftTeam.ally;
    final currentSlots = isAlly ? state.alliedSlots : state.enemySlots;
    final updatedSlots = List<HeroSummary?>.from(currentSlots);
    updatedSlots[target.index] = hero;

    // Find next empty slot on the same team to advance focus smoothly
    DraftSlotTarget? nextFocus;
    final nextEmptySameTeam = updatedSlots.indexWhere((s) => s == null);
    if (nextEmptySameTeam != -1) {
      nextFocus = DraftSlotTarget(team: target.team, index: nextEmptySameTeam);
    } else {
      // If same team is full, check the other team
      final otherSlots = isAlly ? state.enemySlots : state.alliedSlots;
      final otherEmpty = otherSlots.indexWhere((s) => s == null);
      if (otherEmpty != -1) {
        nextFocus = DraftSlotTarget(
          team: isAlly ? DraftTeam.enemy : DraftTeam.ally,
          index: otherEmpty,
        );
      }
    }

    state = state.copyWith(
      alliedSlots: isAlly ? updatedSlots : null,
      enemySlots: !isAlly ? updatedSlots : null,
      focusedSlot: () => nextFocus,
    );
  }

  /// Clears the hero in [target] slot and focuses it.
  void clearSlot(DraftSlotTarget target) {
    final isAlly = target.team == DraftTeam.ally;
    final currentSlots = isAlly ? state.alliedSlots : state.enemySlots;
    if (currentSlots[target.index] == null) {
      focusSlot(target);
      return;
    }

    final updatedSlots = List<HeroSummary?>.from(currentSlots);
    updatedSlots[target.index] = null;

    state = state.copyWith(
      alliedSlots: isAlly ? updatedSlots : null,
      enemySlots: !isAlly ? updatedSlots : null,
      focusedSlot: () => target,
    );
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
