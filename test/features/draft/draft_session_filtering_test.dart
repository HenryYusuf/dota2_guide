import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/draft/draft_providers.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';

void main() {
  group('DraftSessionNotifier position filtering', () {
    test('initial state has null selectedPosition (All)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(draftSessionProvider);
      expect(state.selectedPosition, isNull);
    });

    test(
      'setPositionFilter updates selectedPosition and resetDraft clears it',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(draftSessionProvider.notifier);
        notifier.setPositionFilter(DraftPosition.pos1);
        expect(
          container.read(draftSessionProvider).selectedPosition,
          DraftPosition.pos1,
        );

        notifier.setPositionFilter(DraftPosition.pos3);
        expect(
          container.read(draftSessionProvider).selectedPosition,
          DraftPosition.pos3,
        );

        notifier.resetDraft();
        expect(container.read(draftSessionProvider).selectedPosition, isNull);
      },
    );
  });

  group('draftRankedHeroesProvider with position filtering', () {
    test(
      'filters candidates by selectedPosition while preserving ranking',
      () async {
        const hero1 = HeroSummary(
          id: 1,
          valveKey: 'npc_dota_hero_antimage',
          localizedName: 'Anti-Mage',
          primaryAttribute: PrimaryAttribute.agility,
          complexity: 1,
          portraitUrl: 'url1',
        );
        const hero2 = HeroSummary(
          id: 2,
          valveKey: 'npc_dota_hero_axe',
          localizedName: 'Axe',
          primaryAttribute: PrimaryAttribute.strength,
          complexity: 1,
          portraitUrl: 'url2',
        );
        const hero5 = HeroSummary(
          id: 5,
          valveKey: 'npc_dota_hero_crystal_maiden',
          localizedName: 'Crystal Maiden',
          primaryAttribute: PrimaryAttribute.intelligence,
          complexity: 1,
          portraitUrl: 'url5',
        );

        final rolesMap = {
          1: HeroRoleLevels.fromList(const [
            3,
            0,
            1,
            0,
            0,
            0,
            3,
            0,
            0,
          ]), // Pos 1 (Carry 3)
          2: HeroRoleLevels.fromList(const [
            1,
            0,
            0,
            2,
            0,
            3,
            0,
            0,
            3,
          ]), // Pos 3 (Durable 3, Initiator 3)
          5: HeroRoleLevels.fromList(const [
            0,
            3,
            2,
            2,
            0,
            0,
            0,
            0,
            0,
          ]), // Pos 5 (Support 3)
        };

        final matrix = MatchupMatrix.empty();

        final container = ProviderContainer(
          overrides: [
            heroesProvider.overrideWith(
              (ref) => Future.value([hero1, hero2, hero5]),
            ),
            matchupMatrixProvider.overrideWith((ref) => Future.value(matrix)),
            heroRolesProvider.overrideWith((ref) => Future.value(rolesMap)),
          ],
        );
        addTearDown(container.dispose);

        // Wait for futures to resolve
        await container.read(heroesProvider.future);
        await container.read(matchupMatrixProvider.future);
        await container.read(heroRolesProvider.future);

        // Initially All (null) -> 3 heroes
        var ranked = container.read(draftRankedHeroesProvider).value!;
        expect(ranked.length, 3);

        // Filter by Pos 1 -> Anti-Mage
        container
            .read(draftSessionProvider.notifier)
            .setPositionFilter(DraftPosition.pos1);
        ranked = container.read(draftRankedHeroesProvider).value!;
        expect(ranked.length, 1);
        expect(ranked.first.hero.id, 1);

        // Filter by Pos 3 -> Axe
        container
            .read(draftSessionProvider.notifier)
            .setPositionFilter(DraftPosition.pos3);
        ranked = container.read(draftRankedHeroesProvider).value!;
        expect(ranked.length, 1);
        expect(ranked.first.hero.id, 2);

        // Filter by Pos 5 -> Crystal Maiden
        container
            .read(draftSessionProvider.notifier)
            .setPositionFilter(DraftPosition.pos5);
        ranked = container.read(draftRankedHeroesProvider).value!;
        expect(ranked.length, 1);
        expect(ranked.first.hero.id, 5);
      },
    );
  });

  group('draftCompositionDiagnosticsProvider', () {
    test('computes diagnostics dynamically as allied slots change', () async {
      const hero2 = HeroSummary(
        id: 2,
        valveKey: 'npc_dota_hero_axe',
        localizedName: 'Axe',
        primaryAttribute: PrimaryAttribute.strength,
        complexity: 1,
        portraitUrl: 'url2',
      );
      const hero3 = HeroSummary(
        id: 3,
        valveKey: 'npc_dota_hero_bane',
        localizedName: 'Bane',
        primaryAttribute: PrimaryAttribute.universal,
        complexity: 2,
        portraitUrl: 'url3',
      );

      final rolesMap = {
        2: HeroRoleLevels.fromList(const [
          1,
          0,
          0,
          2,
          0,
          3,
          0,
          0,
          3,
        ]), // Axe: Durable 3, Initiator 3
        3: HeroRoleLevels.fromList(const [
          0,
          2,
          1,
          3,
          0,
          1,
          0,
          0,
          0,
        ]), // Bane: Disabler 3, Support 2, Durable 1
      };

      final container = ProviderContainer(
        overrides: [
          heroRolesProvider.overrideWith((ref) => Future.value(rolesMap)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(heroRolesProvider.future);

      // Initially empty -> all 4 alerts
      var diag = container.read(draftCompositionDiagnosticsProvider).value!;
      expect(diag.alerts.length, 4);

      // Assign Bane to Allied Slot 0 -> Disabler threshold met
      container.read(draftSessionProvider.notifier).assignHero(hero3);
      diag = container.read(draftCompositionDiagnosticsProvider).value!;
      expect(diag.hasDisabler, isTrue);
      expect(
        diag.alerts,
        isNot(contains(CompositionDiagnostics.disablerAlert)),
      );

      // Assign Axe to Allied Slot 1 -> Durable and Initiator thresholds met
      container.read(draftSessionProvider.notifier).assignHero(hero2);
      diag = container.read(draftCompositionDiagnosticsProvider).value!;
      expect(diag.hasDurable, isTrue);
      expect(diag.hasInitiator, isTrue);
      expect(diag.alerts, isNot(contains(CompositionDiagnostics.durableAlert)));
      expect(
        diag.alerts,
        isNot(contains(CompositionDiagnostics.initiatorAlert)),
      );
    });
  });
}
