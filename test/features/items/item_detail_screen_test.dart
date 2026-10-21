// Item detail screen seam: the real screen over fake repositories.
// No HTTP, no asset bundle, no CDN image cache.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_detail_repository.dart';
import 'package:dota2_guide/features/items/item_detail_screen.dart';
import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';

import 'item_test_helpers.dart';

const _cdn = 'https://cdn.steamstatic.com/apps/dota2/images/dota_react/items';

final _testDetail = ItemDetail(
  schemaVersion: 1,
  locale: 'english',
  item: const ItemProfile(
    id: 100,
    valveKey: 'item_cyclone',
    name: 'Eul\'s Scepter of Divinity',
    iconUrl: '$_cdn/cyclone.png',
    shopCategory: ShopCategory.caster,
    neutralTier: null,
    totalCost: 2600,
    combinationCost: 675,
    components: [23, 57, 244],
    attributes: [
      ItemAttribute(
        sign: '+',
        label: 'Intelligence',
        values: [10],
        isPercentage: false,
      ),
      ItemAttribute(
        sign: '+',
        label: 'Movement Speed',
        values: [20],
        isPercentage: false,
      ),
    ],
    effects: [
      ItemEffect(
        kind: ItemEffectKind.active,
        title: 'Cyclone',
        text:
            'Sweeps a target unit up into a cyclone, making them invulnerable.',
      ),
    ],
    notes: ['Cannot target magic immune enemies.'],
    lore: 'A mysterious scepter passed down through generations.',
  ),
);

final _defaultEulsComponents = <int, ItemDetail>{
  100: _testDetail,
  23: createTestItemDetail(id: 23, name: 'Staff of Wizardry', totalCost: 1000),
  57: createTestItemDetail(id: 57, name: 'Void Stone', totalCost: 700),
  244: createTestItemDetail(id: 244, name: 'Wind Lace', totalCost: 225),
};

class _FailingItemDetailRepository implements ItemDetailRepository {
  @override
  Future<ItemDetail> loadItemDetail(int itemId) async =>
      throw Exception('Failed to load detail');
}

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    ItemDetailRepository? repository,
    int itemId = 100,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemIconBuilderProvider.overrideWithValue(stubItemIcon),
          itemDetailRepositoryProvider.overrideWithValue(
            repository ?? FakeItemDetailRepository(_defaultEulsComponents),
          ),
        ],
        child: MaterialApp(home: ItemDetailScreen(itemId: itemId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRouterDetail(
    WidgetTester tester, {
    required ItemDetailRepository repository,
    int initialItemId = 1,
  }) async {
    final router = GoRouter(
      initialLocation: ItemDetailScreen.location(initialItemId),
      routes: [
        GoRoute(
          path: '/items/:id',
          builder: (context, state) =>
              ItemDetailScreen(itemId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemIconBuilderProvider.overrideWithValue(stubItemIcon),
          itemDetailRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders identity, total cost, combination cost, attributes, and effect text',
    (WidgetTester tester) async {
      await pumpDetail(tester);

      // Identity
      expect(find.text('Eul\'s Scepter of Divinity'), findsOneWidget);
      expect(find.text('Caster'), findsOneWidget);

      // Cost section
      expect(
        find.byKey(const ValueKey<String>('item-cost-section')),
        findsOneWidget,
      );
      expect(find.text('2600 gold'), findsOneWidget);
      expect(find.text('675 gold'), findsOneWidget);

      // Attributes section
      expect(
        find.byKey(const ValueKey<String>('item-attributes-section')),
        findsOneWidget,
      );
      expect(find.text('+10 Intelligence'), findsOneWidget);
      expect(find.text('+20 Movement Speed'), findsOneWidget);

      // Effects card
      await tester.scrollUntilVisible(find.text('Cyclone'), 100);
      expect(find.text('Cyclone'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(
        find.text(
          'Sweeps a target unit up into a cyclone, making them invulnerable.',
        ),
        findsOneWidget,
      );

      // Notes and Lore
      await tester.scrollUntilVisible(
        find.text('Cannot target magic immune enemies.'),
        100,
      );
      expect(find.text('Cannot target magic immune enemies.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('A mysterious scepter passed down through generations.'),
        100,
      );
      expect(
        find.text('A mysterious scepter passed down through generations.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows quiet error message when load fails', (
    WidgetTester tester,
  ) async {
    await pumpDetail(tester, repository: _FailingItemDetailRepository());

    expect(find.text("Couldn't load this item."), findsOneWidget);
  });

  testWidgets(
    'renders a multi-level tree from a fake repository and verifies tap-through navigation',
    (WidgetTester tester) async {
      final items = <int, ItemDetail>{
        1: createTestItemDetail(
          id: 1,
          name: 'Wind Waker',
          totalCost: 5400,
          components: [2, 3],
        ),
        2: createTestItemDetail(
          id: 2,
          name: 'Eul\'s Scepter of Divinity',
          totalCost: 2600,
          components: [4, 5],
        ),
        3: createTestItemDetail(
          id: 3,
          name: 'Mystic Staff',
          totalCost: 2800,
          components: const [],
        ),
        4: createTestItemDetail(
          id: 4,
          name: 'Staff of Wizardry',
          totalCost: 1600,
          components: const [],
        ),
        5: createTestItemDetail(
          id: 5,
          name: 'Void Stone',
          totalCost: 1000,
          components: const [],
        ),
      };

      await pumpRouterDetail(
        tester,
        repository: FakeItemDetailRepository(items),
        initialItemId: 1,
      );

      // Verify the Recipe section exists
      expect(
        find.byKey(const ValueKey<String>('item-recipe-section')),
        findsOneWidget,
      );

      // Verify top combined-cost row is consistent with displayed component prices
      // (2600 + 2800 = 5400 gold)
      final combinedCostRow = find.byKey(
        const ValueKey<String>('recipe-combined-cost-row'),
      );
      expect(combinedCostRow, findsOneWidget);
      expect(
        find.descendant(
          of: combinedCostRow,
          matching: find.text('Combined cost'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: combinedCostRow, matching: find.text('5400 gold')),
        findsOneWidget,
      );

      // Verify components rendered as icon + name + price
      // Eul's Scepter (depth 0, combined item)
      expect(find.text('Eul\'s Scepter of Divinity'), findsOneWidget);
      expect(find.text('2600 gold'), findsOneWidget);

      // Auto-expanded one level deeper: Staff of Wizardry and Void Stone (depth 1)
      expect(find.text('Staff of Wizardry'), findsOneWidget);
      expect(find.text('1600 gold'), findsOneWidget);
      expect(find.text('Void Stone'), findsOneWidget);
      expect(find.text('1000 gold'), findsOneWidget);

      // Mystic Staff (depth 0)
      expect(find.text('Mystic Staff'), findsOneWidget);
      expect(find.text('2800 gold'), findsOneWidget);

      // Verify indentation by depth:
      // Depth 1 item should have a larger x-offset (indented) than depth 0 item
      final eulsText = tester.getTopLeft(
        find.text('Eul\'s Scepter of Divinity'),
      );
      final staffText = tester.getTopLeft(find.text('Staff of Wizardry'));
      expect(staffText.dx, greaterThan(eulsText.dx));

      // Tap any row navigates to that Item's detail page (depth 0 row: Eul's)
      await tester.tap(find.byKey(const ValueKey<String>('recipe-row-2')));
      await tester.pumpAndSettle();

      // We are now on Eul's detail page
      expect(find.text('Eul\'s Scepter of Divinity'), findsWidgets);
      // Back button appears
      expect(find.byType(BackButton), findsOneWidget);

      // Back navigation returns to the original Item (Wind Waker)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Wind Waker'), findsOneWidget);

      // Tap a depth 1 child row (Staff of Wizardry)
      await tester.tap(find.byKey(const ValueKey<String>('recipe-row-4')));
      await tester.pumpAndSettle();

      // We are now on Staff of Wizardry's detail page
      expect(find.text('Staff of Wizardry'), findsWidgets);
      expect(find.byType(BackButton), findsOneWidget);

      // Back navigation returns to the original Item (Wind Waker)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Wind Waker'), findsOneWidget);
    },
  );

  testWidgets('an item without components does not show the recipe card', (
    WidgetTester tester,
  ) async {
    final items = <int, ItemDetail>{
      3: createTestItemDetail(
        id: 3,
        name: 'Mystic Staff',
        totalCost: 2800,
        components: const [],
      ),
    };

    await pumpDetail(
      tester,
      repository: FakeItemDetailRepository(items),
      itemId: 3,
    );

    expect(
      find.byKey(const ValueKey<String>('item-recipe-section')),
      findsNothing,
    );
  });
}
