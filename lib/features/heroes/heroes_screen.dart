import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'hero_detail_screen.dart';
import 'hero_index.dart';
import 'heroes_providers.dart';
import 'primary_attribute_display.dart';

/// Heroes tab: the offline portrait grid with attribute/complexity filters
/// and name search (spec: user stories 1–4, all working with no network).
class HeroesScreen extends ConsumerStatefulWidget {
  const HeroesScreen({super.key});

  static const routeLocation = '/heroes';

  @override
  ConsumerState<HeroesScreen> createState() => _HeroesScreenState();
}

/// Complexity values the filter offers (1 easy – 3 hard, as in-game).
const List<int> _complexities = [1, 2, 3];

class _HeroesScreenState extends ConsumerState<HeroesScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Uncommitted search text; every keystroke refilters.
  String _query = '';

  /// Selected filter values per category. Empty means "no filter", matching
  /// FilterChip's unchecked look: tap to narrow, tap again to widen.
  final Set<PrimaryAttribute> _selectedAttributes = <PrimaryAttribute>{};
  final Set<int> _selectedComplexities = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle<T>(Set<T> selection, T value) {
    setState(() {
      if (!selection.remove(value)) selection.add(value);
    });
  }

  /// Applies search + filters, then presents the roster alphabetically — the
  /// feed's id order is release order, useless for finding a Hero.
  List<HeroSummary> _visibleHeroes(List<HeroSummary> heroes) {
    final query = _query.trim().toLowerCase();
    final visible =
        heroes.where((hero) {
          if (query.isNotEmpty &&
              !hero.localizedName.toLowerCase().contains(query)) {
            return false;
          }
          if (_selectedAttributes.isNotEmpty &&
              !_selectedAttributes.contains(hero.primaryAttribute)) {
            return false;
          }
          if (_selectedComplexities.isNotEmpty &&
              !_selectedComplexities.contains(hero.complexity)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => a.localizedName.toLowerCase().compareTo(
            b.localizedName.toLowerCase(),
          ),
        );
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final heroesAsync = ref.watch(heroesProvider);
    final buildPortrait = ref.read(portraitBuilderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Heroes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search heroes',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final attribute in PrimaryAttribute.values)
                  FilterChip(
                    label: Text(primaryAttributeLabels[attribute]!),
                    avatar: _AttributeDot(primaryAttributeColors[attribute]!),
                    showCheckmark: false,
                    selected: _selectedAttributes.contains(attribute),
                    onSelected: (_) => _toggle(_selectedAttributes, attribute),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final complexity in _complexities)
                  FilterChip(
                    label: Text('Complexity $complexity'),
                    selected: _selectedComplexities.contains(complexity),
                    onSelected: (_) =>
                        _toggle(_selectedComplexities, complexity),
                  ),
              ],
            ),
          ),
          Expanded(
            child: heroesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  const Center(child: Text("Couldn't load heroes.")),
              data: (heroes) {
                final visible = _visibleHeroes(heroes);
                if (visible.isEmpty) {
                  return const Center(child: Text('No heroes match.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 16 / 9,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _HeroTile(
                    hero: visible[index],
                    buildPortrait: buildPortrait,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colour dot identifying a primary attribute on its chip.
class _AttributeDot extends StatelessWidget {
  const _AttributeDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// One grid cell: the CDN portrait edge-to-edge with the Hero's name laid
/// over a bottom gradient (portraits are 16:9, so nothing is cropped).
class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.hero, required this.buildPortrait});

  final HeroSummary hero;
  final PortraitBuilder buildPortrait;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // Grid → detail: push the Hero's page inside the Heroes tab.
      onTap: () => context.push(HeroDetailScreen.location(hero.id)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            buildPortrait(context, hero),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [Colors.transparent, Color(0xE6000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 5),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  hero.localizedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
