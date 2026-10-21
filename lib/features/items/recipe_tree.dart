import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item_detail.dart';
import 'items_providers.dart';

/// One node in an Item's recipe tree.
class RecipeTreeNode {
  const RecipeTreeNode({
    required this.item,
    required this.depth,
    this.children = const [],
  });

  /// The component's profile (identity, costs, attributes, etc.).
  final ItemProfile item;

  /// Tree depth (0 for direct components, 1 for auto-expanded children).
  final int depth;

  /// Sub-components if this node is a combined Item and auto-expanded
  /// (bounded to 1 level deeper per spec).
  final List<RecipeTreeNode> children;
}

/// Extension methods on collections of [RecipeTreeNode].
extension RecipeTreeNodesExtension on Iterable<RecipeTreeNode> {
  /// Flattens a forest of recipe tree nodes in pre-order for linear display.
  List<RecipeTreeNode> flatten() {
    final flattened = <RecipeTreeNode>[];
    for (final root in this) {
      flattened.add(root);
      for (final child in root.children) {
        flattened.add(child);
      }
    }
    return flattened;
  }

  /// Sums the direct component prices shown at the root level of the recipe tree,
  /// ensuring consistency with the displayed component prices.
  int get combinedCost {
    return fold<int>(0, (sum, node) => sum + node.item.totalCost);
  }
}

/// Flattens a forest of recipe tree nodes in pre-order for linear display.
List<RecipeTreeNode> flattenRecipeTree(List<RecipeTreeNode> rootNodes) =>
    rootNodes.flatten();

/// Sums the direct component prices shown at the root level of the recipe tree,
/// ensuring consistency with the displayed component prices.
int calculateRecipeCombinedCost(List<RecipeTreeNode> rootNodes) =>
    rootNodes.combinedCost;

/// Builds the recipe tree for [itemId], auto-expanding components that are
/// themselves combined Items exactly one level deeper.
final recipeTreeProvider = FutureProvider.family<List<RecipeTreeNode>, int>((
  ref,
  itemId,
) async {
  final repo = ref.watch(itemDetailRepositoryProvider);
  final rootDetail = await repo.loadItemDetail(itemId);
  final rootComponents = rootDetail.item.components;
  if (rootComponents.isEmpty) return const [];

  final rootNodes = await Future.wait(
    rootComponents.map((componentId) async {
      final compDetail = await repo.loadItemDetail(componentId);
      final compItem = compDetail.item;
      final children = <RecipeTreeNode>[];
      if (compItem.components.isNotEmpty) {
        final childDetails = await Future.wait(
          compItem.components.map((childId) => repo.loadItemDetail(childId)),
        );
        for (final childDetail in childDetails) {
          children.add(RecipeTreeNode(item: childDetail.item, depth: 1));
        }
      }
      return RecipeTreeNode(item: compItem, depth: 0, children: children);
    }),
  );
  return rootNodes;
});
