import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search heroes',
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

          // Primary Attribute Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final attribute in PrimaryAttribute.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(primaryAttributeLabels[attribute]!),
                      avatar: _AttributeDot(primaryAttributeColors[attribute]!),
                      showCheckmark: false,
                      selected: _selectedAttributes.contains(attribute),
                      selectedColor: primaryAttributeColors[attribute]!
                          .withValues(alpha: 0.25),
                      side: BorderSide(
                        color: _selectedAttributes.contains(attribute)
                            ? primaryAttributeColors[attribute]!
                            : AppTheme.border,
                        width: 1,
                      ),
                      onSelected: (_) =>
                          _toggle(_selectedAttributes, attribute),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Complexity Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final complexity in _complexities)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('Complexity $complexity'),
                      selected: _selectedComplexities.contains(complexity),
                      showCheckmark: false,
                      selectedColor: AppTheme.gold.withValues(alpha: 0.22),
                      side: BorderSide(
                        color: _selectedComplexities.contains(complexity)
                            ? AppTheme.gold
                            : AppTheme.border,
                        width: 1,
                      ),
                      onSelected: (_) =>
                          _toggle(_selectedComplexities, complexity),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Heroes Grid
          Expanded(
            child: heroesAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (error, stackTrace) =>
                  const Center(child: Text("Couldn't load heroes.")),
              data: (heroes) {
                final visible = _visibleHeroes(heroes);
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 48,
                            color: AppTheme.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No heroes match.',
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
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 16 / 9,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
        ],
      ),
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
    final attrColor =
        primaryAttributeColors[hero.primaryAttribute] ?? AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: attrColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          // Grid → detail: push the Hero's page inside the Heroes tab.
          onTap: () => context.push(HeroDetailScreen.location(hero.id)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                buildPortrait(context, hero),
                // Gradient scrim for optimal text contrast
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Color(0xF0080B10)],
                    ),
                  ),
                ),
                // Primary Attribute dot indicator (top left)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: attrColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: attrColor.withValues(alpha: 0.7),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                // Hero Name (bottom center)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      hero.localizedName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
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
  }
}
