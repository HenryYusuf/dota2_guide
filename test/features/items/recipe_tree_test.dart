import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/recipe_tree.dart';

import 'item_test_helpers.dart';

void main() {
  test('recipeTreeProvider builds tree with auto-expansion bounded to one level deeper', () async {
    final items = {
      1: createTestItemDetail(
        id: 1,
        name: 'Wind Waker',
        totalCost: 5400,
        components: [2, 3],
      ),
      2: createTestItemDetail(
        id: 2,
        name: 'Eul\'s Scepter',
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
        totalCost: 1000,
        components: [6],
      ),
      5: createTestItemDetail(
        id: 5,
        name: 'Void Stone',
        totalCost: 700,
        components: const [],
      ),
      6: createTestItemDetail(
        id: 6,
        name: 'Base Component',
        totalCost: 500,
        components: const [],
      ),
    };

    final container = ProviderContainer(
      overrides: [
        itemDetailRepositoryProvider.overrideWithValue(
          FakeItemDetailRepository(items),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tree = await container.read(recipeTreeProvider(1).future);

    expect(tree.length, 2);

    // Node 0: Eul's Scepter (depth 0) with 2 children
    final euls = tree[0];
    expect(euls.item.id, 2);
    expect(euls.item.name, 'Eul\'s Scepter');
    expect(euls.depth, 0);
    expect(euls.children.length, 2);

    // Eul's child 0: Staff of Wizardry (depth 1)
    final staff = euls.children[0];
    expect(staff.item.id, 4);
    expect(staff.item.name, 'Staff of Wizardry');
    expect(staff.depth, 1);
    // Expansion is bounded to one level deeper: child does not auto-expand further
    expect(staff.children, isEmpty);

    // Eul's child 1: Void Stone (depth 1)
    final stone = euls.children[1];
    expect(stone.item.id, 5);
    expect(stone.depth, 1);
    expect(stone.children, isEmpty);

    // Node 1: Mystic Staff (depth 0, no children)
    final mystic = tree[1];
    expect(mystic.item.id, 3);
    expect(mystic.depth, 0);
    expect(mystic.children, isEmpty);
  });

  test(
    'recipeTreeProvider returns empty list for item without components',
    () async {
      final items = {
        3: createTestItemDetail(
          id: 3,
          name: 'Mystic Staff',
          totalCost: 2800,
          components: const [],
        ),
      };

      final container = ProviderContainer(
        overrides: [
          itemDetailRepositoryProvider.overrideWithValue(
            FakeItemDetailRepository(items),
          ),
        ],
      );
      addTearDown(container.dispose);

      final tree = await container.read(recipeTreeProvider(3).future);
      expect(tree, isEmpty);
    },
  );
}
