// Item detail: the offline reference page for one Item — identity and shop
// placement, total and combination cost, the stat rows, the Active/Passive/
// Toggle/Use effect text, notes, and lore. Data arrives exclusively through
// [itemDetailProvider] (override-preferred, offline by construction); media
// arrives through the injected icon builder, so widget tests never touch the
// CDN (ADR-0001).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'item_detail.dart';
import 'items_providers.dart';
import 'recipe_tree.dart';
import 'shop_categories.dart';

/// One Item's detail page, pushed from the Items list as `/items/:id`.
class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  /// The id this screen was opened with (list tile, deep link).
  final int itemId;

  /// Route pattern for this screen, nested under the Items branch.
  static const String routePath = ':id';

  /// The location for one Item's page (list → detail navigation).
  static String location(int itemId) => '/items/$itemId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(itemDetailProvider(itemId));
    final buildIcon = ref.watch(itemIconBuilderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Item')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load this item.")),
        data: (detail) => _DetailBody(detail: detail, buildIcon: buildIcon),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.buildIcon});

  final ItemDetail detail;
  final ItemIconBuilder buildIcon;

  @override
  Widget build(BuildContext context) {
    final item = detail.item;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Identity: icon, name, and where the in-game shop presents it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: buildIcon(context, item.iconUrl, item.name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.headlineSmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Tag(label: item.shopCategory.label),
                      if (item.neutralTier case final int tier)
                        _Tag(label: 'Tier ${neutralTierLabel(tier)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CostCard(item: item),
        if (item.components.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecipeCard(itemId: item.id, buildIcon: buildIcon),
        ],
        if (item.attributes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AttributesCard(item: item),
        ],
        if (item.effects.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EffectsCard(effects: item.effects),
        ],
        if (item.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NotesCard(notes: item.notes),
        ],
        if (item.lore.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LoreCard(lore: item.lore),
        ],
      ],
    );
  }
}

/// A small grey chip (shop tab, tier).
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Total cost, and the combination (recipe) cost when the build has a paid
/// recipe step — the converter omits free steps, so no "0 gold" row exists
/// to render.
class _CostCard extends StatelessWidget {
  const _CostCard({required this.item});

  final ItemProfile item;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );

    return _SectionCard(
      key: const ValueKey<String>('item-cost-section'),
      title: 'Cost',
      children: [
        row('Total', '${item.totalCost} gold'),
        if (item.combinationCost case final int combinationCost)
          row('Combination', '$combinationCost gold'),
      ],
    );
  }
}

/// The Recipe tree: components rendered as indented rows with icon, name, and
/// price; components that are themselves combined Items auto-expand one level
/// deeper so there are never dead ends; every row taps through to that Item's
/// detail page. A combined-cost row at the top stays consistent with the
/// component prices shown.
class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.itemId, required this.buildIcon});

  final int itemId;
  final ItemIconBuilder buildIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(recipeTreeProvider(itemId));

    return treeAsync.when(
      loading: () => const _SectionCard(
        key: ValueKey<String>('item-recipe-section'),
        title: 'Recipe',
        children: [
          SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      error: (_, _) => const _SectionCard(
        key: ValueKey<String>('item-recipe-section'),
        title: 'Recipe',
        children: [Text("Couldn't load recipe.")],
      ),
      data: (rootNodes) {
        if (rootNodes.isEmpty) return const SizedBox.shrink();

        final combinedCost = rootNodes.combinedCost;
        final flattened = rootNodes.flatten();
        final seenIds = <int>{};

        return _SectionCard(
          key: const ValueKey<String>('item-recipe-section'),
          title: 'Recipe',
          children: [
            Padding(
              key: const ValueKey<String>('recipe-combined-cost-row'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Combined cost',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '$combinedCost gold',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 12),
            for (final (index, node) in flattened.indexed)
              _RecipeRow(
                key: ValueKey<String>(
                  seenIds.add(node.item.id)
                      ? 'recipe-row-${node.item.id}'
                      : 'recipe-row-${node.item.id}-$index',
                ),
                node: node,
                buildIcon: buildIcon,
              ),
          ],
        );
      },
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({super.key, required this.node, required this.buildIcon});

  final RecipeTreeNode node;
  final ItemIconBuilder buildIcon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final indent = node.depth * 24.0;

    return InkWell(
      onTap: () => context.push(ItemDetailScreen.location(node.item.id)),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent + 4, 4, 4, 4),
        child: Row(
          children: [
            if (node.depth > 0) ...[
              const Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: Colors.white38,
              ),
              const SizedBox(width: 4),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 28,
                height: 28,
                child: buildIcon(context, node.item.iconUrl, node.item.name),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.item.name,
                style: text.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${node.item.totalCost} gold',
              style: text.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stat rows, each pre-rendered by [ItemAttribute.display] — the
/// emitted text is the rendered text.
class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.item});

  final ItemProfile item;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return _SectionCard(
      key: const ValueKey<String>('item-attributes-section'),
      title: 'Attributes',
      children: [
        for (final attribute in item.attributes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(attribute.display, style: style),
          ),
      ],
    );
  }
}

/// One card per effect section (Active / Passive / Toggle / Use / other),
/// in the feed's order.
class _EffectsCard extends StatelessWidget {
  const _EffectsCard({required this.effects});

  final List<ItemEffect> effects;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, effect) in effects.indexed)
          Card(
            key: ValueKey<String>(
              'item-effect-$i-${effect.kind.name}-${effect.title}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (effect.kind != ItemEffectKind.other) ...[
                        _KindBadge(kind: effect.kind),
                        const SizedBox(width: 6),
                      ],
                      if (effect.title.isNotEmpty)
                        Expanded(
                          child: Text(effect.title, style: text.titleSmall),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(effect.text, style: text.bodyMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Active" / "Passive" / "Toggle" / "Use" chip, coloured like the official
/// site's effect marks.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final ItemEffectKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      ItemEffectKind.active => const Color(0xFF4FA3E3),
      ItemEffectKind.toggle => const Color(0xFFD9A44A),
      _ => Colors.white24,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        kind.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return _SectionCard(
      key: const ValueKey<String>('item-notes-section'),
      title: 'Notes',
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(note, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

class _LoreCard extends StatelessWidget {
  const _LoreCard({required this.lore});

  final String lore;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Lore',
      children: [
        Text(
          lore,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
