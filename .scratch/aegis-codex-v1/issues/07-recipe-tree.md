# 07: Recipe tree

**What to build:** The Item detail page gains the Recipe tree: components rendered as indented rows with icon, name, and price; components that are themselves combined Items auto-expand one level deeper so there are never dead ends; every row taps through to that Item's detail page, letting a player plan a complete purchase order across several Items. A combined-cost row at the top stays consistent with the component prices shown.

**Blocked by:** 06 (items list & detail — the page it lives on).

**Status:** ready-for-human

- [x] Tree renders each component as icon + name + price, indented by depth
- [x] Components with their own recipes expand one level deeper automatically
- [x] Tapping any row navigates to that Item's detail page; back navigation returns to the original Item
- [x] Top combined-cost row is consistent with the sum of displayed component prices
- [x] Widget test renders a multi-level tree from a fake repository and verifies tap-through navigation

## Comments

### 2026-10-21 — implementation complete

Delivered on branch `main`, analyzer clean (`dart analyze` reporting no issues), full suite green (155 tests).

**Data Model & Tree Provider:**
- `RecipeTreeNode` and `recipeTreeProvider` in `lib/features/items/recipe_tree.dart`.
- Root components loaded at depth 0; components that are themselves combined items (`components.isNotEmpty`) auto-expand one level deeper (`depth: 1`) without unbounded recursion.
- `calculateRecipeCombinedCost` (and `Iterable<RecipeTreeNode>.combinedCost`) sums root-level component prices, guaranteeing consistency with displayed component rows.
- `flattenRecipeTree` (and `Iterable<RecipeTreeNode>.flatten()`) flattens tree nodes in pre-order for linear display.

**UI:**
- `_RecipeCard` on `ItemDetailScreen`: displayed when `item.components.isNotEmpty`.
- Header row displays `Combined cost` consistent with displayed component prices.
- `_RecipeRow` displays icon (via `itemIconBuilderProvider`), name, price (`$totalCost gold`), and indentation (`depth * 24.0` with `Icons.subdirectory_arrow_right` indicator for depth > 0).
- Tapping any row navigates to `ItemDetailScreen.location(component.id)` via GoRouter (`context.push`), allowing multi-hop navigation and back navigation returning to original item.

**Tests & Test Helpers:**
- Unit tests: `test/features/items/recipe_tree_test.dart` verifying bounded one-level auto-expansion and empty tree handling.
- Widget tests: `test/features/items/item_detail_screen_test.dart` verifying multi-level tree rendering, indentation, combined cost consistency, tap-through navigation, back navigation, and omission of recipe card when item has no components.
- Extracted shared test helpers in `test/features/items/item_test_helpers.dart` (`createTestItemDetail`, `FakeItemDetailRepository`, `stubItemIcon`).

### 2026-10-21 — code review applied

Two-axis review (standards + spec):
- **Spec Review**: 100% compliant. All acceptance criteria met, no scope creep.
- **Standards Review**: Documented standards clean (canonical domain terms `Recipe`, `Item`; ADR-0001 compliant; zero analyzer warnings).
- **Refactoring Applied**:
  - Encapsulated free functions as extension methods on `Iterable<RecipeTreeNode>` (`.flatten()`, `.combinedCost`).
  - Extracted shared test fixture factories and fake repository into `item_test_helpers.dart` to eliminate test code duplication.
