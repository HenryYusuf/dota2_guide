import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../heroes/hero_index.dart';
import '../heroes/heroes_providers.dart';
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
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset Draft',
            onPressed: () => draftNotifier.resetDraft(),
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
                    teamColor: const Color(0xFF3B82F6),
                    prefixKey: 'allied_slot',
                    slots: draftSession.alliedSlots,
                    focusedSlot: draftSession.focusedSlot,
                    onFocusSlot: (index) => draftNotifier.focusSlot(
                      DraftSlotTarget(team: DraftTeam.ally, index: index),
                    ),
                    onClearSlot: (index) => draftNotifier.clearSlot(
                      DraftSlotTarget(team: DraftTeam.ally, index: index),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TeamSlotsSection(
                    team: DraftTeam.enemy,
                    teamName: 'Enemies',
                    teamColor: const Color(0xFFEF4444),
                    prefixKey: 'enemy_slot',
                    slots: draftSession.enemySlots,
                    focusedSlot: draftSession.focusedSlot,
                    onFocusSlot: (index) => draftNotifier.focusSlot(
                      DraftSlotTarget(team: DraftTeam.enemy, index: index),
                    ),
                    onClearSlot: (index) => draftNotifier.clearSlot(
                      DraftSlotTarget(team: DraftTeam.enemy, index: index),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hero Roster',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hasEnemies
                              ? 'Advantage vs $enemyCount ${enemyCount == 1 ? 'enemy' : 'enemies'}'
                              : 'Ranked by baseline win rate',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
                  child: Center(child: Text('No heroes match your search.')),
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
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Unable to load draft recommendations: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
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
    required this.onFocusSlot,
    required this.onClearSlot,
  });

  final DraftTeam team;
  final String teamName;
  final Color teamColor;
  final String prefixKey;
  final List<HeroSummary?> slots;
  final DraftSlotTarget? focusedSlot;
  final ValueChanged<int> onFocusSlot;
  final ValueChanged<int> onClearSlot;

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
              ),
            ),
            const SizedBox(width: 6),
            Text(
              teamName,
              style: TextStyle(
                color: teamColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (index) {
            final hero = slots[index];
            final isFocused =
                focusedSlot?.team == team && focusedSlot?.index == index;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
                child: InkWell(
                  key: ValueKey('${prefixKey}_$index'),
                  onTap: () => onFocusSlot(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: isFocused
                          ? teamColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isFocused
                            ? teamColor
                            : teamColor.withValues(alpha: 0.3),
                        width: isFocused ? 2 : 1,
                      ),
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
                                fontWeight: FontWeight.bold,
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
                                    vertical: 1,
                                  ),
                                  color: Colors.black87,
                                  child: Text(
                                    hero.localizedName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 1,
                                right: 1,
                                child: GestureDetector(
                                  onTap: () => onClearSlot(index),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 13,
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
    final isAdvantage = candidate.hasAdvantageScore;

    final badgeColor = isAdvantage
        ? ((candidate.advantageScore ?? 0.0) >= 0
              ? Colors.greenAccent
              : Colors.redAccent)
        : (candidate.baseWinRate >= 0.50
              ? Colors.greenAccent
              : Colors.redAccent);

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
            width: 24,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 36,
              child: portraitBuilder(context, candidate.hero),
            ),
          ),
        ],
      ),
      title: Text(
        candidate.hero.localizedName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: isAssigned
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'PICKED',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
    );

    final cardColor =
        Theme.of(context).cardTheme.color ?? const Color(0xFF1C1C1E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: isAssigned ? Opacity(opacity: 0.45, child: content) : content,
      ),
    );
  }
}
