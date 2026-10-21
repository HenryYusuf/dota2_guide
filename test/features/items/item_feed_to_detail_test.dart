// Feed → app-schema converter seam for Items (one converter, two writers:
// `tool/snapshot.dart` bundles what this emits and the refresh unit
// re-emits it, so a refreshed override is byte-shape compatible with the
// bundled per-Item file by construction).

import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_feed_to_detail.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _feedDoc({
  required int id,
  required String name,
  required String nameLoc,
  int cost = 1000,
  int neutralTier = 4294967295,
  String descLoc = '',
  String loreLoc = '',
  List<dynamic> notesLoc = const [],
  List<dynamic> specialValues = const [],
}) => {
  'result': {
    'status': 1,
    'data': {
      'items': [
        {
          'id': id,
          'name': name,
          'name_loc': nameLoc,
          'desc_loc': descLoc,
          'lore_loc': loreLoc,
          'notes_loc': notesLoc,
          'special_values': specialValues,
          'item_cost': cost,
          'item_neutral_tier': neutralTier,
        },
      ],
    },
  },
};

void main() {
  group('itemDetailFromFeed', () {
    test('maps item identity, cost, lore, and notes', () {
      final feed = _feedDoc(
        id: 1,
        name: 'item_blink',
        nameLoc: 'Blink Dagger',
        cost: 2250,
        loreLoc: 'A legendary dagger.',
        notesLoc: ['Can be used to escape.'],
      );

      final detail = itemDetailFromFeed(feed, locale: 'english');

      expect(detail['schema_version'], itemDetailSchemaVersion);
      expect(detail['locale'], 'english');
      final item = detail['item']! as Map<String, Object?>;
      expect(item['id'], 1);
      expect(item['valve_key'], 'item_blink');
      expect(item['name'], 'Blink Dagger');
      expect(item['total_cost'], 2250);
      expect(item['combination_cost'], isNull);
      expect(item['lore'], 'A legendary dagger.');
      expect(item['notes'], ['Can be used to escape.']);
    });

    test('attaches combination cost and components when recipe provided', () {
      final feed = _feedDoc(
        id: 100,
        name: 'item_cyclone',
        nameLoc: 'Eul\'s Scepter of Divinity',
        cost: 2600,
      );

      final detail = itemDetailFromFeed(
        feed,
        locale: 'english',
        recipe: const ItemRecipeInfo(
          combinationCost: 675,
          components: [23, 57, 244],
        ),
      );

      final item = detail['item']! as Map<String, Object?>;
      expect(item['combination_cost'], 675);
      expect(item['components'], [23, 57, 244]);
    });

    test('parses attributes and decodes heading tokens', () {
      final feed = _feedDoc(
        id: 1,
        name: 'item_test',
        nameLoc: 'Test Item',
        specialValues: [
          {
            'name': 'bonus_str',
            'values_float': [10.0],
            'heading_loc': r'+$str',
            'is_percentage': false,
          },
          {
            'name': 'bonus_evasion',
            'values_float': [20.0],
            'heading_loc': r'+$evasion',
            'is_percentage': true,
          },
        ],
      );

      final detail = itemDetailFromFeed(feed, locale: 'english');
      final item = detail['item']! as Map<String, Object?>;
      final attrs = (item['attributes']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(attrs, hasLength(2));
      expect(attrs[0]['sign'], '+');
      expect(attrs[0]['label'], 'Strength');
      expect(attrs[0]['values'], [10.0]);
      expect(attrs[0]['is_percentage'], isFalse);

      expect(attrs[1]['sign'], '+');
      expect(attrs[1]['label'], 'Evasion');
      expect(attrs[1]['values'], [20.0]);
      expect(attrs[1]['is_percentage'], isTrue);
    });

    test(
      'splits active, passive, toggle, and use effects and resolves tokens',
      () {
        final feed = _feedDoc(
          id: 1,
          name: 'item_test',
          nameLoc: 'Test Item',
          descLoc: '<h1>Active: Teleport</h1> Moves %range% units.<h1>Passive: Glow</h1> Gives %radius% light.',
          specialValues: [
            {
              'name': 'range',
              'values_float': [1200.0],
            },
            {
              'name': 'radius',
              'values_float': [600.0],
            },
          ],
        );

        final detail = itemDetailFromFeed(feed, locale: 'english');
        final item = detail['item']! as Map<String, Object?>;
        final effects = (item['effects']! as List<Object?>)
            .cast<Map<String, Object?>>();

        expect(effects, hasLength(2));
        expect(effects[0]['kind'], 'active');
        expect(effects[0]['title'], 'Teleport');
        expect(effects[0]['text'], 'Moves 1200 units.');

        expect(effects[1]['kind'], 'passive');
        expect(effects[1]['title'], 'Glow');
        expect(effects[1]['text'], 'Gives 600 light.');
      },
    );

    test('handles bare descriptions with no heading', () {
      final feed = _feedDoc(
        id: 1,
        name: 'item_boots',
        nameLoc: 'Boots',
        descLoc: 'Movement speed bonuses do not stack.',
      );

      final detail = itemDetailFromFeed(feed, locale: 'english');
      final item = detail['item']! as Map<String, Object?>;
      final effects = (item['effects']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(effects, hasLength(1));
      expect(effects.single['kind'], 'other');
      expect(effects.single['text'], 'Movement speed bonuses do not stack.');
    });
  });

  group('itemRecipesFromItemlist', () {
    test('pairs recipe items with base items and resolves components and combination cost', () {
      final entries = [
        {
          'name': 'item_recipe_blink',
          'recipes': [
            {
              'items': [10, 20],
            },
          ],
        },
      ];
      final costs = {'item_recipe_blink': 500};

      final recipes = itemRecipesFromItemlist(entries, costs);

      expect(recipes.containsKey('item_blink'), isTrue);
      expect(recipes['item_blink']!.combinationCost, 500);
      expect(recipes['item_blink']!.components, [10, 20]);
    });
  });

  group('itemCostFromFeed', () {
    test('extracts valve key and cost', () {
      final feed = _feedDoc(
        id: 1,
        name: 'item_blink',
        nameLoc: 'Blink Dagger',
        cost: 2250,
      );
      final (key, cost) = itemCostFromFeed(feed);
      expect(key, 'item_blink');
      expect(cost, 2250);
    });
  });
}
