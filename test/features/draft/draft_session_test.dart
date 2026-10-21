import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/draft/draft_session.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';

void main() {
  group('DraftSessionNotifier', () {
    const hero1 = HeroSummary(
      id: 1,
      valveKey: 'npc_dota_hero_antimage',
      localizedName: 'Anti-Mage',
      primaryAttribute: PrimaryAttribute.agility,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/antimage.png',
    );
    const hero2 = HeroSummary(
      id: 2,
      valveKey: 'npc_dota_hero_axe',
      localizedName: 'Axe',
      primaryAttribute: PrimaryAttribute.strength,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/axe.png',
    );

    test('initializes with 5 empty allied slots, 5 empty enemy slots, and null focus', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(draftSessionProvider);

      expect(state.alliedSlots.length, 5);
      expect(state.enemySlots.length, 5);
      expect(state.alliedSlots.every((s) => s == null), isTrue);
      expect(state.enemySlots.every((s) => s == null), isTrue);
      expect(state.focusedSlot, isNull);
      expect(state.isEmpty, isTrue);
      expect(state.assignedHeroIds, isEmpty);
    });

    test('focusSlot sets the active target slot', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(draftSessionProvider.notifier);
      notifier.focusSlot(
        const DraftSlotTarget(team: DraftTeam.enemy, index: 2),
      );

      expect(
        container.read(draftSessionProvider).focusedSlot,
        const DraftSlotTarget(team: DraftTeam.enemy, index: 2),
      );
    });

    test('assignHero assigns hero to focused slot and advances focus to next empty slot', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(draftSessionProvider.notifier);
      notifier.focusSlot(
        const DraftSlotTarget(team: DraftTeam.enemy, index: 0),
      );

      notifier.assignHero(hero1);

      var state = container.read(draftSessionProvider);
      expect(state.enemySlots[0], hero1);
      expect(state.isHeroAssigned(hero1.id), isTrue);
      // Auto-advances to enemy slot 1
      expect(
        state.focusedSlot,
        const DraftSlotTarget(team: DraftTeam.enemy, index: 1),
      );

      notifier.assignHero(hero2);
      state = container.read(draftSessionProvider);
      expect(state.enemySlots[1], hero2);
      expect(
        state.focusedSlot,
        const DraftSlotTarget(team: DraftTeam.enemy, index: 2),
      );
    });

    test('assignHero ignores hero if already assigned to any slot (duplicate lockout)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(draftSessionProvider.notifier);
      notifier.focusSlot(const DraftSlotTarget(team: DraftTeam.ally, index: 0));
      notifier.assignHero(hero1);

      notifier.focusSlot(
        const DraftSlotTarget(team: DraftTeam.enemy, index: 0),
      );
      notifier.assignHero(hero1); // Already picked by ally 0

      final state = container.read(draftSessionProvider);
      expect(state.enemySlots[0], isNull);
      expect(
        state.focusedSlot,
        const DraftSlotTarget(team: DraftTeam.enemy, index: 0),
      );
    });

    test('clearSlot removes hero from slot and sets focus to cleared slot', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(draftSessionProvider.notifier);
      notifier.focusSlot(const DraftSlotTarget(team: DraftTeam.ally, index: 3));
      notifier.assignHero(hero1);

      expect(container.read(draftSessionProvider).alliedSlots[3], hero1);

      notifier.clearSlot(const DraftSlotTarget(team: DraftTeam.ally, index: 3));
      final state = container.read(draftSessionProvider);
      expect(state.alliedSlots[3], isNull);
      expect(state.isHeroAssigned(hero1.id), isFalse);
      expect(
        state.focusedSlot,
        const DraftSlotTarget(team: DraftTeam.ally, index: 3),
      );
    });

    test('resetDraft clears all 10 slots and clears focus', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(draftSessionProvider.notifier);
      notifier.focusSlot(const DraftSlotTarget(team: DraftTeam.ally, index: 0));
      notifier.assignHero(hero1);
      notifier.focusSlot(
        const DraftSlotTarget(team: DraftTeam.enemy, index: 0),
      );
      notifier.assignHero(hero2);

      expect(container.read(draftSessionProvider).isEmpty, isFalse);

      notifier.resetDraft();

      final state = container.read(draftSessionProvider);
      expect(state.isEmpty, isTrue);
      expect(state.alliedSlots.every((s) => s == null), isTrue);
      expect(state.enemySlots.every((s) => s == null), isTrue);
      expect(state.focusedSlot, isNull);
    });
  });
}
