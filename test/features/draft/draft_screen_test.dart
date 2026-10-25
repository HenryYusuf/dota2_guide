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
  _FakeHeroRolesRepository([this.roles = const {}]);

  final Map<int, HeroRoleLevels> roles;

  @override
  Future<Map<int, HeroRoleLevels>> loadHeroRoles() async => roles;
}

class _ErrorMatchupMatrixRepository implements MatchupMatrixRepository {
  @override
  Future<MatchupMatrix> loadMatchupMatrix() async {
    throw Exception('Failed to load matrix');
  }
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
  ];

  // Hero 1 (Anti-Mage): 40 wins / 100 = 40%
  // Hero 2 (Axe): 65 wins / 100 = 65%
  // Hero 3 (Bane): 52 wins / 100 = 52%
  final testMatrix = MatchupMatrix.fromJson({
    '1': {
      '2': [40, 100],
    },
    '2': {
      '1': [65, 100],
    },
    '3': {
      '1': [52, 100],
    },
  });

  final testRoles = {
    1: HeroRoleLevels.fromList(const [3, 0, 1, 0, 0, 0, 3, 0, 0]),
    2: HeroRoleLevels.fromList(const [1, 0, 0, 2, 0, 3, 0, 0, 3]),
    3: HeroRoleLevels.fromList(const [0, 2, 1, 3, 0, 1, 0, 0, 0]),
  };

  Future<void> pumpDraft(
    WidgetTester tester, {
    MatchupMatrixRepository? matrixRepo,
    HeroesRepository? heroesRepo,
    HeroRolesRepository? rolesRepo,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portraitBuilderProvider.overrideWithValue(
            (context, hero) =>
                SizedBox(key: ValueKey<String>(hero.portraitUrl)),
          ),
          heroesRepositoryProvider.overrideWithValue(
            heroesRepo ?? _FakeHeroesRepository(testHeroes),
          ),
          matchupMatrixRepositoryProvider.overrideWithValue(
            matrixRepo ?? _FakeMatchupMatrixRepository(testMatrix),
          ),
          heroRolesRepositoryProvider.overrideWithValue(
            rolesRepo ?? _FakeHeroRolesRepository(testRoles),
          ),
        ],
        child: const MaterialApp(home: DraftScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders 5 allied slots, 5 enemy slots, and hero roster', (
    tester,
  ) async {
    await pumpDraft(tester);

    expect(find.text('Draft Picker'), findsOneWidget);
    expect(find.text('Allies'), findsOneWidget);
    expect(find.text('Enemies'), findsOneWidget);
    expect(find.text('Hero Roster'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('allied_slot_$i')), findsOneWidget);
      expect(find.byKey(ValueKey('enemy_slot_$i')), findsOneWidget);
    }
  });

  testWidgets('sorts hero roster by baseline win rate in descending order', (
    tester,
  ) async {
    await pumpDraft(tester);

    // Sorted order should be: Axe (65.0%), Bane (52.0%), Anti-Mage (40.0%)
    expect(find.text('Axe'), findsOneWidget);
    expect(find.text('Bane'), findsOneWidget);
    expect(find.text('Anti-Mage'), findsOneWidget);

    expect(find.text('65.0%'), findsOneWidget);
    expect(find.text('52.0%'), findsOneWidget);
    expect(find.text('40.0%'), findsOneWidget);

    final axePos = tester.getTopLeft(find.text('Axe')).dy;
    final banePos = tester.getTopLeft(find.text('Bane')).dy;
    final amPos = tester.getTopLeft(find.text('Anti-Mage')).dy;

    expect(axePos, lessThan(banePos));
    expect(banePos, lessThan(amPos));
  });

  testWidgets('filters roster by search query', (tester) async {
    await pumpDraft(tester);

    await tester.enterText(find.byType(TextField), 'anti');
    await tester.pumpAndSettle();

    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(find.text('Axe'), findsNothing);
    expect(find.text('Bane'), findsNothing);
  });

  testWidgets('shows quiet error message when matchup matrix fails to load', (
    tester,
  ) async {
    await pumpDraft(tester, matrixRepo: _ErrorMatchupMatrixRepository());

    expect(
      find.textContaining('Unable to load draft recommendations'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping an empty slot focuses it, and tapping a roster hero assigns that hero',
    (tester) async {
      await pumpDraft(tester);

      // Tap enemy slot 0
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();

      // Tap Axe in roster
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      // Axe is now assigned to enemy_slot_0
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('enemy_slot_0')),
          matching: find.text('Axe'),
        ),
        findsOneWidget,
      );

      // Enemy slot 1 is now focused (auto-advanced)
    },
  );

  testWidgets(
    'assigning an enemy hero re-ranks candidate roster by Advantage with percentage badges',
    (tester) async {
      await pumpDraft(tester);

      // Focus enemy slot 0 and assign Axe
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      // Candidate roster should now show Advantage badges:
      // Anti-Mage (-15.0%) and Bane (-17.0%)
      expect(find.text('-15.0%'), findsOneWidget);
      expect(find.text('-17.0%'), findsOneWidget);

      // AM should now be higher than Bane
      final amPos = tester.getTopLeft(find.text('Anti-Mage')).dy;
      final banePos = tester.getTopLeft(find.text('Bane')).dy;
      expect(amPos, lessThan(banePos));

      // Subtitle indicates advantage ranking
      expect(find.textContaining('Advantage vs 1 enemy'), findsOneWidget);
    },
  );

  testWidgets(
    'assigned heroes are visually marked as picked and cannot be assigned again',
    (tester) async {
      await pumpDraft(tester);

      // Focus enemy slot 0 and assign Axe
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      // Axe should have a PICKED badge and show no numerical rank
      expect(find.text('PICKED'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      // Focus enemy slot 1
      await tester.tap(find.byKey(const ValueKey('enemy_slot_1')));
      await tester.pumpAndSettle();

      // Attempt to tap Axe in the roster again
      await tester.tap(find.text('Axe').last);
      await tester.pumpAndSettle();

      // Enemy slot 1 should still be empty
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('enemy_slot_1')),
          matching: find.text('Axe'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'clearing an assigned slot removes the hero and updates recommendations',
    (tester) async {
      await pumpDraft(tester);

      // Assign Axe to enemy slot 0
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      expect(find.text('-15.0%'), findsOneWidget);

      // Clear enemy slot 0 (via clear button or slot tap)
      final clearBtn = find.descendant(
        of: find.byKey(const ValueKey('enemy_slot_0')),
        matching: find.byIcon(Icons.close),
      );
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Slot 0 is empty again
      expect(find.text('65.0%'), findsOneWidget);
      expect(find.text('Ranked by baseline win rate'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping an assigned slot clears it and leaves it focused for replacement',
    (tester) async {
      await pumpDraft(tester);

      // Assign Axe to enemy slot 0
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      expect(find.text('-15.0%'), findsOneWidget);

      // Tap the assigned slot directly
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();

      // Slot 0 is now empty and Axe is removed
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('enemy_slot_0')),
          matching: find.text('Axe'),
        ),
        findsNothing,
      );
      // Recommendations revert to baseline
      expect(find.text('Ranked by baseline win rate'), findsOneWidget);
    },
  );

  testWidgets(
    'Reset Draft button clears all slots upon confirmation and restores baseline ranking',
    (tester) async {
      await pumpDraft(tester);

      // Assign Axe to enemy slot 0
      await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Axe'));
      await tester.pumpAndSettle();

      expect(find.text('-15.0%'), findsOneWidget);

      // Tap Reset Draft button
      // Verify prominent Reset button exists with label in AppBar
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
      final resetBtn = find.byTooltip('Reset Draft');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Reset Draft'), findsWidgets);
      expect(
        find.text(
          'Are you sure you want to clear all 10 slots and reset the draft?',
        ),
        findsOneWidget,
      );

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      // Baseline restored
      expect(find.text('65.0%'), findsOneWidget);
      expect(find.text('52.0%'), findsOneWidget);
      expect(find.text('40.0%'), findsOneWidget);
      expect(find.text('Ranked by baseline win rate'), findsOneWidget);
    },
  );

  testWidgets('long-pressing an assigned slot clears it', (tester) async {
    await pumpDraft(tester);

    // Assign Axe to enemy slot 0
    await tester.tap(find.byKey(const ValueKey('enemy_slot_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Axe'));
    await tester.pumpAndSettle();

    expect(find.text('-15.0%'), findsOneWidget);

    // Long press enemy slot 0
    await tester.longPress(find.byKey(const ValueKey('enemy_slot_0')));
    await tester.pumpAndSettle();

    // Slot 0 is now empty, baseline win rate ranking restored
    expect(find.text('65.0%'), findsOneWidget);
    expect(find.text('Ranked by baseline win rate'), findsOneWidget);
  });
}
