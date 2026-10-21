import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search items',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final tier in _neutralTiers)
                  FilterChip(
                    key: ValueKey<String>('neutral-tier-$tier'),
                    label: Text('Tier ${neutralTierLabel(tier)}'),
                    selected: _selectedNeutralTiers.contains(tier),
                    onSelected: (_) => _toggleTier(tier),
                  ),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  const Center(child: Text("Couldn't load items.")),
              data: (index) {
                final visible = _visibleItems(index.items);
                if (visible.isEmpty) {
                  return const Center(child: Text('No items match.'));
                }
                final rows = _sectionRows(visible);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        '${category.label} ($count)',
        style: Theme.of(context).textTheme.titleMedium,
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
    return ListTile(
      key: ValueKey<String>('item-tile-${item.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: buildIcon(context, item.iconUrl, item.name),
        ),
      ),
      title: Text(item.name, style: text.titleSmall),
      subtitle: tier == null
          ? null
          : Text(
              'Tier ${neutralTierLabel(tier)}',
              style: text.labelSmall?.copyWith(color: Colors.white54),
            ),
      // List → detail: push the Item's page inside the Items tab.
      onTap: () => context.push(ItemDetailScreen.location(item.id)),
    );
  }
}
