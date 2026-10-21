import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../heroes/hero_detail_screen.dart';
import '../items/item_detail_screen.dart';
import 'patch_detail.dart';
import 'patches_providers.dart';

/// One Patch's complete structured change notes screen.
class PatchDetailScreen extends ConsumerWidget {
  const PatchDetailScreen({super.key, required this.patchNumber});

  final String patchNumber;

  /// Route path nested under the Patches tab.
  static const String routePath = ':patchNumber';

  /// Navigation destination for one patch detail page.
  static String location(String patchNumber) => '/patches/$patchNumber';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(patchDetailProvider(patchNumber));
    final buildHeroIcon = ref.watch(patchHeroIconBuilderProvider);
    final buildItemIcon = ref.watch(patchItemIconBuilderProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Patch $patchNumber')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _InlineRetryCard(
          patchNumber: patchNumber,
          onRetry: () => ref.invalidate(patchDetailProvider(patchNumber)),
        ),
        data: (detail) {
          if (detail.sections.isEmpty) {
            return const Center(child: Text('No change notes in this patch.'));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              for (final section in detail.sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    section.title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final group in section.groups)
                  _ChangeGroupCard(
                    group: group,
                    buildHeroIcon: buildHeroIcon,
                    buildItemIcon: buildItemIcon,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChangeGroupCard extends StatelessWidget {
  const _ChangeGroupCard({
    required this.group,
    required this.buildHeroIcon,
    required this.buildItemIcon,
  });

  final PatchChangeGroup group;
  final PatchHeroIconBuilder buildHeroIcon;
  final PatchItemIconBuilder buildItemIcon;

  @override
  Widget build(BuildContext context) {
    final heroId = group.heroId;
    final itemId = group.itemId;
    final isTappable = heroId != null || itemId != null;

    void handleTap() {
      if (heroId != null) {
        context.push(HeroDetailScreen.location(heroId));
      } else if (itemId != null) {
        context.push(ItemDetailScreen.location(itemId));
      }
    }

    Widget headerContent = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (heroId != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 48,
                height: 27,
                child: buildHeroIcon(context, group.iconUrl, group.title),
              ),
            ),
            const SizedBox(width: 12),
          ] else if (itemId != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 36,
                height: 27,
                child: buildItemIcon(context, group.iconUrl, group.title),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              group.title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          if (isTappable)
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isTappable)
            InkWell(
              onTap: handleTap,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: headerContent,
            )
          else
            headerContent,
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in group.lines) _ChangeLineRow(line: line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeLineRow extends StatelessWidget {
  const _ChangeLineRow({required this.line});

  final PatchChangeLine line;

  @override
  Widget build(BuildContext context) {
    final indent = (line.indentLevel - 1).clamp(0, 5) * 16.0;
    final bullet = line.indentLevel > 1 ? '◦ ' : '• ';

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bullet,
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          if (line.badge != null) ...[
            const SizedBox(width: 6),
            _BadgeChip(badge: line.badge!),
          ],
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final String badge;

  @override
  Widget build(BuildContext context) {
    final label = badge.toLowerCase() == 'scepter'
        ? 'Scepter'
        : (badge.toLowerCase() == 'shard' ? 'Shard' : badge);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppTheme.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineRetryCard extends StatelessWidget {
  const _InlineRetryCard({required this.patchNumber, required this.onRetry});

  final String patchNumber;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  "Couldn't load Patch $patchNumber",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your network connection and try again.',
                  style: TextStyle(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
