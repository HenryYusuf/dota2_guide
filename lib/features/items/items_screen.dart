import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'item_detail_screen.dart';
import 'item_index.dart';
import 'items_providers.dart';
import 'shop_categories.dart';

/// Items tab: the offline Item catalogue grouped the way the in-game shop
/// presents it — shop-category sections in shop order, neutral-tier filter
/// chips, and name search (spec: user stories 5–7, no network needed).
class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  static const routeLocation = '/items';

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

/// Neutral tiers the filter offers (1–5 as in-game; the feed stores them
/// 0-based and [neutralTierLabel] does the +1).
const List<int> _neutralTiers = [0, 1, 2, 3, 4];

/// Maps neutral tier index (0-4) to authentic Dota neutral tier color.
Color _tierColor(int tier) => switch (tier) {
  0 => AppTheme.tier1,
  1 => AppTheme.tier2,
  2 => AppTheme.tier3,
  3 => AppTheme.tier4,
  4 => AppTheme.tier5,
  _ => AppTheme.textSecondary,
};

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Uncommitted search text; every keystroke refilters.
  String _query = '';

  /// Selected neutral tiers. Empty means "no filter"; selecting any tier
  /// switches to a neutral-only browse (that is what tier-browsing IS).
  final Set<int> _selectedNeutralTiers = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTier(int tier) {
    setState(() {
      if (!_selectedNeutralTiers.remove(tier)) _selectedNeutralTiers.add(tier);
    });
  }

  /// Applies search + tier filter, alphabetically — within each shop section,
  /// which is where the screen sorts them.
  List<ItemSummary> _visibleItems(List<ItemSummary> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
        // Recipe prices and unnamed internal entries are never shop rows.
        if (!item.isListable) return false;
        if (query.isNotEmpty && !item.name.toLowerCase().contains(query)) {
          return false;
        }
        if (_selectedNeutralTiers.isNotEmpty) {
          final tier = item.neutralTier;
          if (tier == null || !_selectedNeutralTiers.contains(tier)) {
            return false;
          }
        }
        return true;
      }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final buildIcon = ref.watch(itemIconBuilderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search items',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Neutral Tier Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final tier in _neutralTiers)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      key: ValueKey<String>('neutral-tier-$tier'),
                      label: Text('Tier ${neutralTierLabel(tier)}'),
                      selected: _selectedNeutralTiers.contains(tier),
                      showCheckmark: false,
                      selectedColor: _tierColor(tier).withValues(alpha: 0.22),
                      side: BorderSide(
                        color: _selectedNeutralTiers.contains(tier)
                            ? _tierColor(tier)
                            : AppTheme.border,
                        width: 1,
                      ),
                      onSelected: (_) => _toggleTier(tier),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (error, stackTrace) =>
                  const Center(child: Text("Couldn't load items.")),
              data: (index) {
                final visible = _visibleItems(index.items);
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No items match.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final rows = _sectionRows(visible);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: rows.length,
                  itemBuilder: (context, position) => switch (rows[position]) {
                    _CategoryHeaderRow(:final category, :final count) =>
                      _SectionHeader(category: category, count: count),
                    _ItemEntryRow(:final item) => _ItemTile(
                      item: item,
                      buildIcon: buildIcon,
                    ),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Flattens [items] into typed rows for the list: a category header followed
  /// by its items, in the in-game shop's tab order.
  List<_ItemRow> _sectionRows(List<ItemSummary> items) {
    final rows = <_ItemRow>[];
    for (final category in ShopCategory.values) {
      final section = items
          .where((item) => item.shopCategory == category)
          .toList(growable: false);
      if (section.isEmpty) continue;
      rows.add(_CategoryHeaderRow(category: category, count: section.length));
      for (final item in section) {
        rows.add(_ItemEntryRow(item));
      }
    }
    return rows;
  }
}

/// Row types displayed in the Items catalogue list.
sealed class _ItemRow {
  const _ItemRow();
}

final class _CategoryHeaderRow extends _ItemRow {
  const _CategoryHeaderRow({required this.category, required this.count});
  final ShopCategory category;
  final int count;
}

final class _ItemEntryRow extends _ItemRow {
  const _ItemEntryRow(this.item);
  final ItemSummary item;
}

/// Section heading: the shop tab's name with the section's item count.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.category, required this.count});

  final ShopCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${category.label} ($count)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// One shop row: icon, name, and — for neutrals — the drop tier.
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.buildIcon});

  final ItemSummary item;
  final ItemIconBuilder buildIcon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tier = item.neutralTier;
    final tierColor = tier != null ? _tierColor(tier) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tierColor != null
              ? tierColor.withValues(alpha: 0.35)
              : AppTheme.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: ValueKey<String>('item-tile-${item.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 2,
          ),
          leading: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: tierColor != null
                    ? tierColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 42,
                height: 42,
                child: buildIcon(context, item.iconUrl, item.name),
              ),
            ),
          ),
          title: Text(
            item.name,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: tier == null
              ? null
              : Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: tierColor?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tier ${neutralTierLabel(tier)}',
                        style: text.labelSmall?.copyWith(
                          color: tierColor ?? Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppTheme.textMuted,
          ),
          // List → detail: push the Item's page inside the Items tab.
          onTap: () => context.push(ItemDetailScreen.location(item.id)),
        ),
      ),
    );
  }
}
