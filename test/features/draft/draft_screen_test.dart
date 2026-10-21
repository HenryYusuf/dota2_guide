import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/draft/draft_providers.dart';
import 'package:dota2_guide/features/draft/draft_screen.dart';
import 'package:dota2_guide/features/draft/matchup_matrix_repository.dart';
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

  Widget buildSubject({
    MatchupMatrixRepository? matrixRepo,
    HeroesRepository? heroesRepo,
  }) {
    return ProviderScope(
      overrides: [
        portraitBuilderProvider.overrideWithValue(
          (context, hero) => SizedBox(key: ValueKey<String>(hero.portraitUrl)),
        ),
        heroesRepositoryProvider.overrideWithValue(
          heroesRepo ?? _FakeHeroesRepository(testHeroes),
        ),
        matchupMatrixRepositoryProvider.overrideWithValue(
          matrixRepo ?? _FakeMatchupMatrixRepository(testMatrix),
        ),
      ],
      child: const MaterialApp(home: DraftScreen()),
    );
  }

  testWidgets('renders 5 allied slots, 5 enemy slots, and hero roster', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'anti');
    await tester.pumpAndSettle();

    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(find.text('Axe'), findsNothing);
    expect(find.text('Bane'), findsNothing);
  });

  testWidgets('shows quiet error message when matchup matrix fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(matrixRepo: _ErrorMatchupMatrixRepository()),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Unable to load draft recommendations'),
      findsOneWidget,
    );
  });
}
