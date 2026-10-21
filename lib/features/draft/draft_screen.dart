import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../heroes/heroes_providers.dart';
import 'draft_providers.dart';

/// Draft tab: the offline Draft Picker 5v5 drafting screen and counter recommendation tool.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Draft Picker')),
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
                    teamName: 'Allies',
                    teamColor: const Color(0xFF3B82F6),
                    prefixKey: 'allied_slot',
                  ),
                  const SizedBox(height: 12),
                  _TeamSlotsSection(
                    teamName: 'Enemies',
                    teamColor: const Color(0xFFEF4444),
                    prefixKey: 'enemy_slot',
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
                          'Ranked by baseline win rate',
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
              final visible = rankedList.where((rh) {
                if (_query.isEmpty) return true;
                return rh.hero.localizedName.toLowerCase().contains(_query);
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
                    return _HeroRosterRow(rankedHero: item, rank: index + 1);
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

class _TeamSlotsSection extends StatelessWidget {
  const _TeamSlotsSection({
    required this.teamName,
    required this.teamColor,
    required this.prefixKey,
  });

  final String teamName;
  final Color teamColor;
  final String prefixKey;

  @override
  Widget build(BuildContext context) {
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
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
                child: Container(
                  key: ValueKey('${prefixKey}_$index'),
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: teamColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: teamColor.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
  const _HeroRosterRow({required this.rankedHero, required this.rank});

  final RankedHero rankedHero;
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portraitBuilder = ref.watch(portraitBuilderProvider);
    final winRate = rankedHero.baseWinRate;
    final isPositive = winRate >= 0.50;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                child: portraitBuilder(context, rankedHero.hero),
              ),
            ),
          ],
        ),
        title: Text(
          rankedHero.hero.localizedName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isPositive ? Colors.green : Colors.redAccent).withValues(
              alpha: 0.15,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (isPositive ? Colors.green : Colors.redAccent).withValues(
                alpha: 0.3,
              ),
            ),
          ),
          child: Text(
            rankedHero.winRatePercentage,
            style: TextStyle(
              color: isPositive ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
