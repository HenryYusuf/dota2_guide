import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../heroes/hero_index.dart';
import '../heroes/heroes_providers.dart';
import '../heroes/primary_attribute_display.dart';
import 'draft_providers.dart';

/// Draft tab: the offline Draft Picker 5v5 drafting screen.
class DraftScreen extends ConsumerStatefulWidget {
  const DraftScreen({super.key});

  static const routeLocation = '/draft';

  @override
  ConsumerState<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends ConsumerState<DraftScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showResetConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Draft'),
          content: const Text(
            'Are you sure you want to clear all 10 slots and reset the draft?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      ref.read(draftSessionProvider.notifier).resetDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedHeroesAsync = ref.watch(draftRankedHeroesProvider);
    final draftSession = ref.watch(draftSessionProvider);
    final draftNotifier = ref.read(draftSessionProvider.notifier);

    final hasEnemies = draftSession.enemyHeroIds.isNotEmpty;
    final enemyCount = draftSession.enemyHeroIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Picker'),
        actions: [
          Tooltip(
            message: 'Reset Draft',
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              onPressed: () => _showResetConfirmation(context),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 5v5 Draft Board
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TeamSlotsSection(
                    team: DraftTeam.ally,
                    teamName: 'Allies',
                    teamColor: AppTheme.radiant,
                    prefixKey: 'allied_slot',
                    slots: draftSession.alliedSlots,
                    focusedSlot: draftSession.focusedSlot,
                    notifier: draftNotifier,
                  ),
                  const SizedBox(height: 12),
                  _TeamSlotsSection(
                    team: DraftTeam.enemy,
                    teamName: 'Enemies',
                    teamColor: AppTheme.dire,
                    prefixKey: 'enemy_slot',
                    slots: draftSession.enemySlots,
                    focusedSlot: draftSession.focusedSlot,
                    notifier: draftNotifier,
                  ),
                  const SizedBox(height: 12),
                  _CompositionDiagnosticsSection(
                    hasAllies: draftSession.alliedHeroIds.isNotEmpty,
                    diagnosticsAsync: ref.watch(
                      draftCompositionDiagnosticsProvider,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hero Roster',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hasEnemies
                              ? 'Advantage vs $enemyCount ${enemyCount == 1 ? 'enemy' : 'enemies'}'
                              : 'Ranked by baseline win rate',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _PositionFilterBar(
                    selectedPosition: draftSession.selectedPosition,
                    onSelected: (pos) => draftNotifier.setPositionFilter(pos),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search hero...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Hero Roster List
          rankedHeroesAsync.when(
            data: (rankedList) {
              final visible = rankedList.where((candidate) {
                if (_query.isEmpty) return true;
                return candidate.hero.localizedName.toLowerCase().contains(
                  _query,
                );
              }).toList();

              if (visible.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No heroes match your search.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = visible[index];
                    return _HeroRosterRow(
                      candidate: item,
                      rank: index + 1,
                      onTap: item.isAssigned
                          ? null
                          : () => draftNotifier.assignHero(item.hero),
                    );
                  }, childCount: visible.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load draft recommendations: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamSlotsSection extends ConsumerWidget {
  const _TeamSlotsSection({
    required this.team,
    required this.teamName,
    required this.teamColor,
    required this.prefixKey,
    required this.slots,
    required this.focusedSlot,
    required this.notifier,
  });

  final DraftTeam team;
  final String teamName;
  final Color teamColor;
  final String prefixKey;
  final List<HeroSummary?> slots;
  final DraftSlotTarget? focusedSlot;
  final DraftSessionNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portraitBuilder = ref.watch(portraitBuilderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: teamColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              teamName,
              style: TextStyle(
                color: teamColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final hero = slots[index];
            final target = DraftSlotTarget(team: team, index: index);
            final isFocused = focusedSlot == target;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
                child: InkWell(
                  key: ValueKey('${prefixKey}_$index'),
                  onTap: () {
                    if (hero != null) {
                      notifier.clearSlot(target);
                    }
                    notifier.focusSlot(target);
                  },
                  onLongPress: hero != null
                      ? () => notifier.clearSlot(target)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: isFocused
                          ? teamColor.withValues(alpha: 0.20)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFocused
                            ? teamColor
                            : teamColor.withValues(alpha: 0.35),
                        width: isFocused ? 2 : 1,
                      ),
                      boxShadow: isFocused
                          ? [
                              BoxShadow(
                                color: teamColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hero == null
                        ? Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isFocused
                                    ? teamColor
                                    : teamColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              portraitBuilder(context, hero),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 1.5,
                                  ),
                                  color: const Color(0xE6080B10),
                                  child: Text(
                                    hero.localizedName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => notifier.clearSlot(target),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HeroRosterRow extends ConsumerWidget {
  const _HeroRosterRow({
    required this.candidate,
    required this.rank,
    required this.onTap,
  });

  final DraftCandidate candidate;
  final int rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portraitBuilder = ref.watch(portraitBuilderProvider);

    final isAssigned = candidate.isAssigned;
    final isAdvantage = candidate.hasAdvantage;

    final badgeColor = isAdvantage
        ? ((candidate.advantage ?? 0.0) >= 0 ? AppTheme.agility : AppTheme.dire)
        : (candidate.baseWinRate >= 0.50 ? AppTheme.agility : AppTheme.dire);

    final badgeText = isAdvantage
        ? candidate.advantagePercentage
        : candidate.baseWinRatePercentage;

    final content = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              isAssigned ? '—' : '$rank',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    primaryAttributeColors[candidate.hero.primaryAttribute]
                        ?.withValues(alpha: 0.4) ??
                    AppTheme.border,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 48,
                height: 36,
                child: portraitBuilder(context, candidate.hero),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        candidate.hero.localizedName,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: isAssigned
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'PICKED',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: isAssigned ? Opacity(opacity: 0.45, child: content) : content,
      ),
    );
  }
}

class _CompositionDiagnosticsSection extends StatelessWidget {
  const _CompositionDiagnosticsSection({
    required this.hasAllies,
    required this.diagnosticsAsync,
  });

  final bool hasAllies;
  final AsyncValue<CompositionDiagnostics> diagnosticsAsync;

  @override
  Widget build(BuildContext context) {
    if (!hasAllies) return const SizedBox.shrink();

    return diagnosticsAsync.when(
      data: (diagnostics) {
        final isBalanced = diagnostics.isBalanced;
        final statusColor = isBalanced ? AppTheme.agility : AppTheme.gold;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBalanced
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Composition Diagnostics',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final arch in diagnostics.archetypes)
                    _RoleScoreChip(
                      label: arch.label,
                      points: arch.points,
                      threshold: arch.threshold,
                      fulfilled: arch.fulfilled,
                    ),
                ],
              ),
              if (diagnostics.alerts.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final alert in diagnostics.alerts)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(color: statusColor, fontSize: 12),
                        ),
                        Expanded(
                          child: Text(
                            alert,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: AppTheme.agility, fontSize: 12),
                    ),
                    Expanded(
                      child: Text(
                        'Team composition is well-balanced',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RoleScoreChip extends StatelessWidget {
  const _RoleScoreChip({
    required this.label,
    required this.points,
    required this.threshold,
    required this.fulfilled,
  });

  final String label;
  final int points;
  final int threshold;
  final bool fulfilled;

  @override
  Widget build(BuildContext context) {
    final color = fulfilled ? AppTheme.agility : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fulfilled
            ? AppTheme.agility.withValues(alpha: 0.15)
            : AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: fulfilled
              ? AppTheme.agility.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Text(
        '$label $points/$threshold',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: fulfilled ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PositionFilterBar extends StatelessWidget {
  const _PositionFilterBar({
    required this.selectedPosition,
    required this.onSelected,
  });

  final DraftPosition? selectedPosition;
  final ValueChanged<DraftPosition?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('pos_filter_all'),
            label: const Text('All'),
            selected: selectedPosition == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 6),
          for (final pos in DraftPosition.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('pos_filter_${pos.name}'),
                label: Text(pos.label),
                tooltip: '${pos.label}: ${pos.laneDescription}',
                selected: selectedPosition == pos,
                onSelected: (selected) {
                  onSelected(selected ? pos : null);
                },
              ),
            ),
        ],
      ),
    );
  }
}
