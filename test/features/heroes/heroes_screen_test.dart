// Heroes tab seam (spec: "widget tests render real screens over in-memory
// fake repositories"): the real screen, the real filters, fake data. No HTTP,
// no asset bundle, no CDN image cache — portraits go through the injected
// builder so tests never touch the network (ADR-0001 streams media at
// runtime).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:dota2_guide/features/heroes/heroes_screen.dart';

const _cdn = 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes';

/// Deliberately NOT alphabetical, so any ordering the screen presents is the
/// screen's own doing rather than an accident of this list.
const _roster = <HeroSummary>[
  HeroSummary(
    id: 105,
    valveKey: 'npc_dota_hero_techies',
    localizedName: 'Techies',
    primaryAttribute: PrimaryAttribute.universal,
    complexity: 3,
    portraitUrl: '$_cdn/techies.png',
  ),
  HeroSummary(
    id: 5,
    valveKey: 'npc_dota_hero_crystal_maiden',
    localizedName: 'Crystal Maiden',
    primaryAttribute: PrimaryAttribute.intelligence,
    complexity: 2,
    portraitUrl: '$_cdn/crystal_maiden.png',
  ),
  HeroSummary(
    id: 2,
    valveKey: 'npc_dota_hero_axe',
    localizedName: 'Axe',
    primaryAttribute: PrimaryAttribute.strength,
    complexity: 1,
    portraitUrl: '$_cdn/axe.png',
  ),
  HeroSummary(
    id: 1,
    valveKey: 'npc_dota_hero_antimage',
    localizedName: 'Anti-Mage',
    primaryAttribute: PrimaryAttribute.agility,
    complexity: 1,
    portraitUrl: '$_cdn/antimage.png',
  ),
];

class _FakeHeroesRepository implements HeroesRepository {
  @override
  Future<List<HeroSummary>> loadHeroes() async => _roster;
}

/// Portraits are the only networked part of this screen; the stub stands in
/// for the Valve CDN and is findable by the URL it was handed.
Widget _stubPortrait(BuildContext context, HeroSummary hero) =>
    SizedBox(key: ValueKey<String>(hero.portraitUrl));

void main() {
  /// Renders the real [HeroesScreen] over a fake repository (default: the
  /// canned roster above); only the [repository] test opts into real data.
  Future<void> pumpHeroes(
    WidgetTester tester, {
    HeroesRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portraitBuilderProvider.overrideWithValue(_stubPortrait),
          heroesRepositoryProvider.overrideWithValue(
            repository ?? _FakeHeroesRepository(),
          ),
        ],
        child: const MaterialApp(home: HeroesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Reading-order position of a hero name in the grid (row, then column).
  bool isBefore(WidgetTester tester, String a, String b) {
    final pa = tester.getTopLeft(find.text(a));
    final pb = tester.getTopLeft(find.text(b));
    final rowA = pa.dy.round();
    final rowB = pb.dy.round();
    return rowA < rowB || (rowA == rowB && pa.dx < pb.dx);
  }

  testWidgets('renders the roster as a portrait grid, alphabetically', (
    WidgetTester tester,
  ) async {
    await pumpHeroes(tester);

    // Every hero is on screen with its CDN portrait URL.
    for (final hero in _roster) {
      expect(find.text(hero.localizedName), findsOneWidget);
      expect(find.byKey(ValueKey<String>(hero.portraitUrl)), findsOneWidget);
    }
    expect(isBefore(tester, 'Anti-Mage', 'Axe'), isTrue);
    expect(isBefore(tester, 'Axe', 'Crystal Maiden'), isTrue);
    expect(isBefore(tester, 'Crystal Maiden', 'Techies'), isTrue);
  });

  testWidgets('primary-attribute chips narrow the grid', (
    WidgetTester tester,
  ) async {
    await pumpHeroes(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Strength'));
    await tester.pumpAndSettle();
    expect(find.text('Axe'), findsOneWidget);
    expect(find.text('Anti-Mage'), findsNothing);
    expect(find.text('Techies'), findsNothing);

    // Selecting a second attribute widens within the category (OR).
    await tester.tap(find.widgetWithText(FilterChip, 'Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('Axe'), findsOneWidget);
    expect(find.text('Crystal Maiden'), findsOneWidget);

    // Deselecting everything shows the full roster again.
    await tester.tap(find.widgetWithText(FilterChip, 'Strength'));
    await tester.tap(find.widgetWithText(FilterChip, 'Intelligence'));
    await tester.pumpAndSettle();
    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(find.text('Techies'), findsOneWidget);
  });

  testWidgets('complexity filter narrows the grid', (
    WidgetTester tester,
  ) async {
    await pumpHeroes(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Complexity 2'));
    await tester.pumpAndSettle();
    expect(find.text('Crystal Maiden'), findsOneWidget);
    expect(find.text('Axe'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Complexity 1'));
    await tester.pumpAndSettle();
    expect(find.text('Axe'), findsOneWidget);
    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(find.text('Crystal Maiden'), findsOneWidget);
    expect(find.text('Techies'), findsNothing);
  });

  testWidgets('name search matches localized names, case-insensitively', (
    WidgetTester tester,
  ) async {
    await pumpHeroes(tester);

    await tester.enterText(find.byType(TextField), 'MAGE');
    await tester.pumpAndSettle();
    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(find.text('Axe'), findsNothing);
    expect(find.text('Crystal Maiden'), findsNothing);

    await tester.enterText(find.byType(TextField), 'crystal  ');
    await tester.pumpAndSettle();
    expect(find.text('Crystal Maiden'), findsOneWidget);
    expect(find.text('Anti-Mage'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Axe'), findsOneWidget);
    expect(find.text('Techies'), findsOneWidget);
  });

  testWidgets('search and filters combine, with a quiet empty state', (
    WidgetTester tester,
  ) async {
    await pumpHeroes(tester);

    // Strength + search "mage": no hero satisfies both.
    await tester.tap(find.widgetWithText(FilterChip, 'Strength'));
    await tester.enterText(find.byType(TextField), 'mage');
    await tester.pumpAndSettle();

    expect(find.text('No heroes match.'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('Heroes tab renders the bundled snapshot on first launch', (
    WidgetTester tester,
  ) async {
    // Full app with default providers: real repository, real asset bundle,
    // only the CDN portrait layer stubbed — nothing else can reach a network.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [portraitBuilderProvider.overrideWithValue(_stubPortrait)],
        child: const AegisApp(),
      ),
    );
    await tester.pumpAndSettle();

    Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    await tester.tap(navLabel('Heroes'));
    await tester.pumpAndSettle();

    // Real heroes from the bundled index (alphabetical head of the roster).
    expect(find.text('Abaddon'), findsOneWidget);
    expect(find.text('Anti-Mage'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('$_cdn/antimage.png')),
      findsWidgets,
    );
    expect(find.byType(HeroesScreen), findsOneWidget);
  });
}
