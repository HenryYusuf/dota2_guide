// Items tab seam: the real screen, the real filters, fake data. No HTTP,
// no asset bundle, no CDN image cache — icons go through the injected
// builder so widget tests never touch the network (ADR-0001 streams media at
// runtime).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dota2_guide/features/items/item_detail_screen.dart';
import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/items/items_screen.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';

const _cdn = 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/items';

final _testItems = <ItemSummary>[
  const ItemSummary(
    id: 1,
    valveKey: 'item_blink',
    name: 'Blink Dagger',
    shopCategory: ShopCategory.caster,
    neutralTier: null,
    isRecipe: false,
    iconUrl: '$_cdn/blink.png',
  ),
  const ItemSummary(
    id: 2,
    valveKey: 'item_blades_of_attack',
    name: 'Blades of Attack',
    shopCategory: ShopCategory.weapons,
    neutralTier: null,
    isRecipe: false,
    iconUrl: '$_cdn/blades_of_attack.png',
  ),
  const ItemSummary(
    id: 287,
    valveKey: 'item_keen_optic',
    name: 'Keen Optic',
    shopCategory: ShopCategory.neutral,
    neutralTier: 0,
    isRecipe: false,
    iconUrl: '$_cdn/keen_optic.png',
  ),
  const ItemSummary(
    id: 298,
    valveKey: 'item_philosophers_stone',
    name: 'Philosopher\'s Stone',
    shopCategory: ShopCategory.neutral,
    neutralTier: 1,
    isRecipe: false,
    iconUrl: '$_cdn/philosophers_stone.png',
  ),
  // Recipe-only item (should be filtered out by isListable)
  const ItemSummary(
    id: 606,
    valveKey: 'item_recipe_arcane_blink',
    name: 'Arcane Blink Recipe',
    shopCategory: ShopCategory.caster,
    neutralTier: null,
    isRecipe: true,
    iconUrl: '$_cdn/recipe_arcane_blink.png',
  ),
];

class _FakeItemsRepository implements ItemsRepository {
  _FakeItemsRepository();

  @override
  Future<ItemIndex> loadItems() async =>
      ItemIndex(schemaVersion: 1, locale: 'english', items: _testItems);
}

class _FailingItemsRepository implements ItemsRepository {
  @override
  Future<ItemIndex> loadItems() async =>
      throw Exception('Failed to load items');
}

Widget _stubIcon(BuildContext context, String url, String itemName) =>
    SizedBox(key: ValueKey<String>(url));

void main() {
  Future<void> pumpItems(
    WidgetTester tester, {
    ItemsRepository? repository,
    GoRouter? router,
  }) async {
    final app = MaterialApp.router(
      routerConfig:
          router ??
          GoRouter(
            initialLocation: ItemsScreen.routeLocation,
            routes: [
              GoRoute(
                path: ItemsScreen.routeLocation,
                builder: (context, state) => const ItemsScreen(),
                routes: [
                  GoRoute(
                    path: ItemDetailScreen.routePath,
                    builder: (context, state) =>
                        Text('Detail ${state.pathParameters['id']}'),
                  ),
                ],
              ),
            ],
          ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemIconBuilderProvider.overrideWithValue(_stubIcon),
          itemsRepositoryProvider.overrideWithValue(
            repository ?? _FakeItemsRepository(),
          ),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders items grouped by shop category with item count', (
    WidgetTester tester,
  ) async {
    await pumpItems(tester);

    // Categories with items render their headers
    expect(find.text('Weapons (1)'), findsOneWidget);
    expect(find.text('Caster (1)'), findsOneWidget);
    expect(find.text('Neutral Items (2)'), findsOneWidget);

    // Listable items appear
    expect(find.text('Blink Dagger'), findsOneWidget);
    expect(find.text('Blades of Attack'), findsOneWidget);
    expect(find.text('Keen Optic'), findsOneWidget);
    expect(find.text('Philosopher\'s Stone'), findsOneWidget);

    // Recipe item is excluded from shop list
    expect(find.text('Arcane Blink Recipe'), findsNothing);
  });

  testWidgets('neutral tier chips filter the items list', (
    WidgetTester tester,
  ) async {
    await pumpItems(tester);

    // Tap Tier 1 chip (neutral tier 0)
    await tester.tap(find.byKey(const ValueKey<String>('neutral-tier-0')));
    await tester.pumpAndSettle();

    expect(find.text('Keen Optic'), findsOneWidget);
    expect(find.text('Philosopher\'s Stone'), findsNothing);
    expect(find.text('Blink Dagger'), findsNothing);

    // Tap Tier 2 chip as well (neutral tier 1)
    await tester.tap(find.byKey(const ValueKey<String>('neutral-tier-1')));
    await tester.pumpAndSettle();

    expect(find.text('Keen Optic'), findsOneWidget);
    expect(find.text('Philosopher\'s Stone'), findsOneWidget);
    expect(find.text('Blink Dagger'), findsNothing);

    // Deselect both
    await tester.tap(find.byKey(const ValueKey<String>('neutral-tier-0')));
    await tester.tap(find.byKey(const ValueKey<String>('neutral-tier-1')));
    await tester.pumpAndSettle();

    expect(find.text('Blink Dagger'), findsOneWidget);
  });

  testWidgets('name search narrows the items list', (
    WidgetTester tester,
  ) async {
    await pumpItems(tester);

    await tester.enterText(find.byType(TextField), 'blink');
    await tester.pumpAndSettle();

    expect(find.text('Blink Dagger'), findsOneWidget);
    expect(find.text('Blades of Attack'), findsNothing);
    expect(find.text('Keen Optic'), findsNothing);

    // Empty search result shows friendly message
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();

    expect(find.text('No items match.'), findsOneWidget);
  });

  testWidgets('tapping an item tile navigates to item detail', (
    WidgetTester tester,
  ) async {
    await pumpItems(tester);

    await tester.tap(find.byKey(const ValueKey<String>('item-tile-1')));
    await tester.pumpAndSettle();

    expect(find.text('Detail 1'), findsOneWidget);
  });

  testWidgets('shows quiet error message when repository fails', (
    WidgetTester tester,
  ) async {
    await pumpItems(tester, repository: _FailingItemsRepository());

    expect(find.text("Couldn't load items."), findsOneWidget);
  });
}
