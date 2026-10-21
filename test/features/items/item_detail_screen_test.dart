// Item detail screen seam: the real screen over fake repositories.
// No HTTP, no asset bundle, no CDN image cache.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_detail_repository.dart';
import 'package:dota2_guide/features/items/item_detail_screen.dart';
import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';

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

class _FakeItemDetailRepository implements ItemDetailRepository {
  _FakeItemDetailRepository();

  @override
  Future<ItemDetail> loadItemDetail(int itemId) async => _testDetail;
}

class _FailingItemDetailRepository implements ItemDetailRepository {
  @override
  Future<ItemDetail> loadItemDetail(int itemId) async =>
      throw Exception('Failed to load detail');
}

Widget _stubIcon(BuildContext context, String url, String itemName) =>
    SizedBox(key: ValueKey<String>(url));

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    ItemDetailRepository? repository,
    int itemId = 100,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemIconBuilderProvider.overrideWithValue(_stubIcon),
          itemDetailRepositoryProvider.overrideWithValue(
            repository ?? _FakeItemDetailRepository(),
          ),
        ],
        child: MaterialApp(home: ItemDetailScreen(itemId: itemId)),
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
      expect(find.text('Cyclone'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(
        find.text(
          'Sweeps a target unit up into a cyclone, making them invulnerable.',
        ),
        findsOneWidget,
      );

      // Notes and Lore
      expect(find.text('Cannot target magic immune enemies.'), findsOneWidget);
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
}
