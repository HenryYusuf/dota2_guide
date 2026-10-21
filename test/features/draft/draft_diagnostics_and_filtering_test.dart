import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/draft/draft_providers.dart';
import 'package:dota2_guide/features/draft/draft_screen.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';

class _FakeHeroesRepository implements HeroesRepository {
  _FakeHeroesRepository(this.heroes);

  final List<HeroSummary> heroes;

  @override
  Future<List<HeroSummary>> loadHeroes() async => heroes;
}

class _FakeMatchupMatrixRepository implements MatchupMatrixRepository {
  _FakeMatchupMatrixRepository(this.matrix);

  final MatchupMatrix matrix;

  @override
  Future<MatchupMatrix> loadMatchupMatrix() async => matrix;
}

class _FakeHeroRolesRepository implements HeroRolesRepository {
  _FakeHeroRolesRepository(this.roles);

  final Map<int, HeroRoleLevels> roles;

  @override
  Future<Map<int, HeroRoleLevels>> loadHeroRoles() async => roles;
}

void main() {
  final testHeroes = [
    const HeroSummary(
      id: 1,
      valveKey: 'npc_dota_hero_antimage',
      localizedName: 'Anti-Mage',
      primaryAttribute: PrimaryAttribute.agility,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/antimage.png',
    ),
    const HeroSummary(
      id: 2,
      valveKey: 'npc_dota_hero_axe',
      localizedName: 'Axe',
      primaryAttribute: PrimaryAttribute.strength,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/axe.png',
    ),
    const HeroSummary(
      id: 3,
      valveKey: 'npc_dota_hero_bane',
      localizedName: 'Bane',
      primaryAttribute: PrimaryAttribute.universal,
      complexity: 2,
      portraitUrl: 'https://cdn.example.com/bane.png',
    ),
    const HeroSummary(
      id: 5,
      valveKey: 'npc_dota_hero_crystal_maiden',
      localizedName: 'Crystal Maiden',
      primaryAttribute: PrimaryAttribute.intelligence,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/crystal_maiden.png',
    ),
  ];

  final testRoles = {
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
    ]), // Anti-Mage (Pos 1)
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
    ]), // Axe (Pos 3: Durable 3, Initiator 3)
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
    ]), // Bane (Pos 5: Disabler 3, Support 2, Durable 1)
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
    ]), // Crystal Maiden (Pos 5: Support 3)
  };

  final testMatrix = MatchupMatrix.empty();

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        portraitBuilderProvider.overrideWithValue(
          (context, hero) => SizedBox(key: ValueKey<String>(hero.portraitUrl)),
        ),
        heroesRepositoryProvider.overrideWithValue(
          _FakeHeroesRepository(testHeroes),
        ),
        matchupMatrixRepositoryProvider.overrideWithValue(
          _FakeMatchupMatrixRepository(testMatrix),
        ),
        heroRolesRepositoryProvider.overrideWithValue(
          _FakeHeroRolesRepository(testRoles),
        ),
      ],
      child: const MaterialApp(home: DraftScreen()),
    );
  }

  testWidgets(
    'renders horizontal position filter chips and filters candidate roster',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Verify position filter chips are visible
      expect(find.byKey(const ValueKey('pos_filter_all')), findsOneWidget);
      expect(find.byKey(const ValueKey('pos_filter_pos1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pos_filter_pos2')), findsOneWidget);
      expect(find.byKey(const ValueKey('pos_filter_pos3')), findsOneWidget);
      expect(find.byKey(const ValueKey('pos_filter_pos4')), findsOneWidget);
      expect(find.byKey(const ValueKey('pos_filter_pos5')), findsOneWidget);

      // Initially "All" is active: Anti-Mage, Axe, Bane, Crystal Maiden all visible
      expect(find.text('Anti-Mage'), findsOneWidget);
      expect(find.text('Axe'), findsOneWidget);
      expect(find.text('Bane'), findsOneWidget);
      expect(find.text('Crystal Maiden'), findsOneWidget);

      // Tap Pos 1 -> Only Anti-Mage
      await tester.tap(find.byKey(const ValueKey('pos_filter_pos1')));
      await tester.pumpAndSettle();

      expect(find.text('Anti-Mage'), findsOneWidget);
      expect(find.text('Axe'), findsNothing);
      expect(find.text('Bane'), findsNothing);
      expect(find.text('Crystal Maiden'), findsNothing);

      // Tap Pos 3 -> Only Axe
      await tester.tap(find.byKey(const ValueKey('pos_filter_pos3')));
      await tester.pumpAndSettle();

      expect(find.text('Anti-Mage'), findsNothing);
      expect(find.text('Axe'), findsOneWidget);
      expect(find.text('Bane'), findsNothing);
      expect(find.text('Crystal Maiden'), findsNothing);

      // Tap Pos 5 -> Bane and Crystal Maiden
      final pos5Chip = find.byKey(const ValueKey('pos_filter_pos5'));
      await tester.ensureVisible(pos5Chip);
      await tester.tap(pos5Chip);
      await tester.pumpAndSettle();

      expect(find.text('Anti-Mage'), findsNothing);
      expect(find.text('Axe'), findsNothing);
      expect(find.text('Bane'), findsOneWidget);
      expect(find.text('Crystal Maiden'), findsOneWidget);

      // Tap All -> All heroes restore
      final allChip = find.byKey(const ValueKey('pos_filter_all'));
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(find.text('Anti-Mage'), findsOneWidget);
      expect(find.text('Axe'), findsOneWidget);
      expect(find.text('Bane'), findsOneWidget);
      expect(find.text('Crystal Maiden'), findsOneWidget);
    },
  );

  testWidgets(
    'displays composition diagnostics alerts and resolves them dynamically as roles are fulfilled',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // With 0 allied heroes assigned, diagnostic section is not shown
      expect(find.text('Draft lacks reliable stuns/disable'), findsNothing);

      // Focus allied slot 0 and assign Anti-Mage
      await tester.tap(find.byKey(const ValueKey('allied_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anti-Mage'));
      await tester.pumpAndSettle();

      // Now Anti-Mage is assigned to allies. Thresholds for Disabler, Durable, Initiator, Support are unmet.
      expect(find.text('Draft lacks reliable stuns/disable'), findsOneWidget);
      expect(find.text('Draft lacks durable frontline'), findsOneWidget);
      expect(find.text('Draft lacks initiation'), findsOneWidget);
      expect(find.text('Draft lacks sufficient support'), findsOneWidget);

      // Focus allied slot 1 and assign Axe (Durable: 3, Initiator: 3, Disabler: 2)
      await tester.tap(find.byKey(const ValueKey('allied_slot_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      // Durable (3 >= 3) and Initiator (3 >= 2) alerts should be resolved!
      expect(find.text('Draft lacks durable frontline'), findsNothing);
      expect(find.text('Draft lacks initiation'), findsNothing);
      // Disabler is 2 < 3, and Support is 0 < 3
      expect(find.text('Draft lacks reliable stuns/disable'), findsOneWidget);
      expect(find.text('Draft lacks sufficient support'), findsOneWidget);

      // Focus allied slot 2 and assign Bane (Disabler: 3, Support: 2)
      await tester.tap(find.byKey(const ValueKey('allied_slot_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bane'));
      await tester.pumpAndSettle();

      // Disabler is 2 + 3 = 5 >= 3 -> Disabler alert resolved!
      expect(find.text('Draft lacks reliable stuns/disable'), findsNothing);
      // Support is 2 < 3 -> Support alert remains
      expect(find.text('Draft lacks sufficient support'), findsOneWidget);

      // Focus allied slot 3 and assign Crystal Maiden (Support: 3)
      await tester.tap(find.byKey(const ValueKey('allied_slot_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crystal Maiden'));
      await tester.pumpAndSettle();

      // Support is 2 + 3 = 5 >= 3 -> All alerts resolved!
      expect(find.text('Draft lacks reliable stuns/disable'), findsNothing);
      expect(find.text('Draft lacks durable frontline'), findsNothing);
      expect(find.text('Draft lacks initiation'), findsNothing);
      expect(find.text('Draft lacks sufficient support'), findsNothing);
      expect(find.text('Team composition is well-balanced'), findsOneWidget);
    },
  );
}
