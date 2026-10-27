// Hero detail: the offline reference page for one Hero — collapsing header,
// Attributes and Combat stats, expandable Ability cards with their per-level
// tables, Facets (hidden while the game has none), the four-tier Talent
// tree, and the lore. Data arrives exclusively through [heroDetailProvider]
// (override-preferred, offline by construction); media arrives through the
// injected builders, so widget tests never touch the CDN (ADR-0001).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cdn/cdn_urls.dart';
import '../../core/theme/app_theme.dart';
import '../patches/hero_patch_deltas.dart';
import '../patches/latest_patch_card.dart';
import '../patches/patches_providers.dart';
import 'ability_video_repository.dart';
import 'hero_detail.dart';
import 'hero_index.dart';
import 'heroes_providers.dart';
import 'primary_attribute_display.dart';
import 'widgets/ability_demo_player.dart';

/// One Hero's detail page, pushed from the Heroes grid as `/heroes/:id`.
class HeroDetailScreen extends ConsumerWidget {
  const HeroDetailScreen({super.key, required this.heroId});

  /// The id this screen was opened with (grid tile, deep link).
  final int heroId;

  /// Route pattern for this screen, nested under the Heroes branch.
  static const String routePath = ':id';

  /// The location for one Hero's page (grid → detail navigation).
  static String location(int heroId) => '/heroes/$heroId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(heroDetailProvider(heroId));
    final patchHistoryAsync = ref.watch(heroPatchHistoryProvider(heroId));
    final buildHeader = ref.watch(heroHeaderBuilderProvider);
    final buildIcon = ref.watch(abilityIconBuilderProvider);

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load this hero.")),
        data: (detail) => _DetailBody(
          detail: detail,
          patchHistory:
              patchHistoryAsync.value ??
              HeroPatchHistory(heroId: heroId, deltas: const []),
          buildHeader: buildHeader,
          buildIcon: buildIcon,
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.patchHistory,
    required this.buildHeader,
    required this.buildIcon,
  });

  final HeroDetail detail;
  final HeroPatchHistory patchHistory;
  final HeroHeaderBuilder buildHeader;
  final AbilityIconBuilder buildIcon;

  @override
  Widget build(BuildContext context) {
    final hero = detail.hero;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(hero.localizedName),
            background: Stack(
              fit: StackFit.expand,
              children: [
                buildHeader(context, detail),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Color(0xE6101010)],
                    ),
                  ),
                ),
                // Primary attribute + complexity sit in the header itself
                // (spec), just above the pinned title — they collapse away
                // with the portrait.
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 60,
                  child: _AttributeComplexityRow(profile: hero),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileStrip(profile: hero),
              const SizedBox(height: 12),
              _AttributesCard(profile: hero),
              const SizedBox(height: 12),
              _CombatCard(profile: hero),
              const SizedBox(height: 12),
              _AbilitiesSection(
                detail: detail,
                patchHistory: patchHistory,
                buildIcon: buildIcon,
              ),
              if (detail.facets.isNotEmpty) ...[
                const SizedBox(height: 12),
                _FacetsCard(facets: detail.facets),
              ],
              const SizedBox(height: 12),
              _TalentsCard(talents: detail.talents),
              if (hero.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LoreCard(bio: hero.bio),
              ],
              const SizedBox(height: 12),
              _HeroChangelogCard(
                patchHistory: patchHistory,
                abilities: detail.abilities,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Primary attribute (dot + label) and complexity pips — rendered inside the
/// collapsing header, over the portrait's gradient.
class _AttributeComplexityRow extends StatelessWidget {
  const _AttributeComplexityRow({required this.profile});

  final HeroProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final attributeColor = primaryAttributeColors[profile.primaryAttribute]!;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: attributeColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          primaryAttributeLabels[profile.primaryAttribute]!,
          style: text.labelLarge?.copyWith(
            color: attributeColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Text('Complexity', style: text.labelLarge),
        const SizedBox(width: 6),
        // Filled pips, 1 easy – 3 hard, as in-game.
        for (var i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              i <= profile.complexity ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: i <= profile.complexity ? Colors.white70 : Colors.white24,
            ),
          ),
      ],
    );
  }
}

/// The Hero's one-liner, right under the collapsing header — the "who is
/// this" before any numbers.
class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({required this.profile});

  final HeroProfile profile;

  @override
  Widget build(BuildContext context) {
    return Text(
      profile.oneLiner,
      style: Theme.of(context).textTheme.bodyMedium,
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

/// A label → value row used by the Combat stats card.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.profile});

  final HeroProfile profile;

  @override
  Widget build(BuildContext context) {
    final attributes = profile.attributes;
    final primary = profile.primaryAttribute;
    final text = Theme.of(context).textTheme;
    // The primary attribute decides which of the three pools the Hero piles
    // into — bolded so the reader sees it at a glance. Base and gain are
    // separate texts: the per-level gain reads as its own fact.
    Widget row(PrimaryAttribute attribute, String label, AttributeValue value) {
      final emphasized = attribute == primary;
      final style = emphasized
          ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
          : text.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(_fmtNum(value.base), style: style),
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                '+${_fmtNum(value.gain)}',
                textAlign: TextAlign.right,
                style: style?.copyWith(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      key: const ValueKey<String>('attributes-section'),
      title: 'Attributes',
      children: [
        row(PrimaryAttribute.strength, 'Strength', attributes.strength),
        row(PrimaryAttribute.agility, 'Agility', attributes.agility),
        row(
          PrimaryAttribute.intelligence,
          'Intelligence',
          attributes.intelligence,
        ),
      ],
    );
  }
}

class _CombatCard extends StatelessWidget {
  const _CombatCard({required this.profile});

  final HeroProfile profile;

  @override
  Widget build(BuildContext context) {
    final combat = profile.combat;
    final text = Theme.of(context).textTheme;
    Widget group(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge?.copyWith(color: Colors.white54)),
          ...rows,
        ],
      ),
    );
    return _SectionCard(
      key: const ValueKey<String>('combat-section'),
      title: 'Combat Stats',
      children: [
        group('Attack', [
          _StatRow(
            label: 'Damage',
            value: '${combat.damageMin} - ${combat.damageMax}',
          ),
          _StatRow(label: 'Attack Rate', value: _fmtNum(combat.attackRate)),
          _StatRow(label: 'Attack Range', value: '${combat.attackRange}'),
          // Melee Heroes carry 0 here; the official page shows no row.
          if (combat.projectileSpeed != 0)
            _StatRow(
              label: 'Projectile Speed',
              value: '${combat.projectileSpeed}',
            ),
        ]),
        group('Defense', [
          _StatRow(label: 'Armor', value: _fmtNum(combat.armor)),
          _StatRow(
            label: 'Magic Resistance',
            value: '${_fmtNum(combat.magicResistance)}%',
          ),
        ]),
        group('Mobility', [
          _StatRow(label: 'Movement Speed', value: '${combat.movementSpeed}'),
          _StatRow(label: 'Turn Rate', value: _fmtNum(combat.turnRate)),
        ]),
        group('Vision', [
          _StatRow(label: 'Day Sight', value: '${combat.sightRangeDay}'),
          _StatRow(label: 'Night Sight', value: '${combat.sightRangeNight}'),
        ]),
      ],
    );
  }
}

class _AbilitiesSection extends StatelessWidget {
  const _AbilitiesSection({
    required this.detail,
    required this.patchHistory,
    required this.buildIcon,
  });

  final HeroDetail detail;
  final HeroPatchHistory patchHistory;
  final AbilityIconBuilder buildIcon;

  @override
  Widget build(BuildContext context) {
    // The demo-video CDN path is keyed on the hero's Valve folder name
    // (e.g. `antimage`), so every card needs it for its play control.
    final heroKey = CdnUrls.heroKeyFromValveName(detail.hero.valveKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'Abilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final ability in detail.abilities) ...[
          _AbilityCard(
            ability: ability,
            patchDeltas: patchHistory.deltasForAbility(ability.name),
            buildIcon: buildIcon,
            heroKey: heroKey,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// How each Ability mark is distinguished on its card: label + colour, per
/// the official site's tooltip marks (innate gold, Scepter purple, Shard
/// blue, ultimate red).
enum AbilityMark {
  innate('Innate', Color(0xFFD9A44A)),
  ultimate('Ultimate', AppTheme.primary),
  scepter('Scepter', Color(0xFF9C6ADE)),
  shard('Shard', Color(0xFF4FA3E3));

  const AbilityMark(this.label, this.color);

  final String label;
  final Color color;
}

/// One expandable Ability card: identity and marks always visible; the
/// description, costs, and per-level table expand in place.
class _AbilityCard extends StatefulWidget {
  const _AbilityCard({
    required this.ability,
    this.patchDeltas = const [],
    required this.buildIcon,
    required this.heroKey,
  });

  final AbilityDetail ability;
  final List<HeroAbilityDeltaRecord> patchDeltas;
  final AbilityIconBuilder buildIcon;

  /// The hero's Valve CDN folder name (e.g. `antimage`) — the demo-video
  /// path is keyed on it.
  final String heroKey;

  @override
  State<_AbilityCard> createState() => _AbilityCardState();
}

class _AbilityCardState extends State<_AbilityCard> {
  bool _expanded = false;

  String? get _latestPatch => widget.patchDeltas.firstOrNull?.patchNumber;

  List<AbilityMark> get _marks => [
    if (widget.ability.isInnate) AbilityMark.innate,
    if (widget.ability.isUltimate) AbilityMark.ultimate,
    if (widget.ability.grantedBy == 'scepter') AbilityMark.scepter,
    if (widget.ability.grantedBy == 'shard') AbilityMark.shard,
  ];

  @override
  Widget build(BuildContext context) {
    final ability = widget.ability;
    final text = Theme.of(context).textTheme;
    final latestPatch = _latestPatch;

    return Card(
      key: ValueKey<String>('ability-${ability.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: widget.buildIcon(context, ability),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ability.displayName, style: text.titleSmall),
                        if (_marks.isNotEmpty || latestPatch != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final mark in _marks)
                                  _MarkBadge(mark: mark),
                                if (latestPatch != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _expanded = true),
                                    child: Container(
                                      key: ValueKey<String>(
                                        'ability-patch-chip-${ability.name}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Changed in $latestPatch',
                                        style: text.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _ExpandedBody(
                ability: ability,
                patchDeltas: widget.patchDeltas,
                heroKey: widget.heroKey,
              ),
            ),
        ],
      ),
    );
  }
}

/// One mark chip (Innate / Ultimate / Scepter / Shard), keyed by kind so the
/// colours stay pinned apart in tests.
class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark});

  final AbilityMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('ability-badge-${mark.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mark.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mark.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.ability,
    this.patchDeltas = const [],
    required this.heroKey,
  });

  final AbilityDetail ability;
  final List<HeroAbilityDeltaRecord> patchDeltas;

  /// The hero's Valve CDN folder name (e.g. `antimage`) — the demo-video
  /// path is keyed on it.
  final String heroKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final costRows = <Widget>[
      if (ability.castRanges.any((v) => v != 0))
        _CostRow(label: 'Cast Range', values: ability.castRanges),
      if (ability.manaCosts.any((v) => v != 0))
        _CostRow(label: 'Mana Cost', values: ability.manaCosts),
      if (ability.cooldowns.any((v) => v != 0))
        _CostRow(label: 'Cooldown', values: ability.cooldowns),
    ];
    final tags = [
      if (ability.behaviorTag case final String behavior
          when behavior.isNotEmpty)
        behavior,
      if (ability.target case final String target) target,
      if (ability.damageType case final String damage) damage,
      if (ability.piercesSpellImmunity case final String immunity)
        'Spell Immunity: $immunity',
      if (ability.dispellable case final String dispel) 'Dispel: $dispel',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The demo video sits above the description, the way the official
        // site's tooltip leads with it; a missing/failed demo is a quiet
        // inline note, never an error, so the texts below stay the point.
        _AbilityDemo(heroKey: heroKey, ability: ability),
        Text(ability.description, style: text.bodyMedium),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag, style: text.labelSmall),
                  ),
              ],
            ),
          ),
        if (costRows.isNotEmpty) ...[const SizedBox(height: 8), ...costRows],
        if (ability.specialValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final special in ability.specialValues)
            _SpecialRow(special: special),
        ],
        if (patchDeltas.isNotEmpty) ...[
          const SizedBox(height: 8),
          _AbilityPatchNotesSection(deltas: patchDeltas),
        ],
        if (ability.scepterText case final String scepterText) ...[
          const SizedBox(height: 8),
          _EnhancementRow(mark: AbilityMark.scepter, text: scepterText),
        ],
        if (ability.shardText case final String shardText) ...[
          const SizedBox(height: 8),
          _EnhancementRow(mark: AbilityMark.shard, text: shardText),
        ],
        if (ability.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final note in ability.notes)
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
                  Expanded(child: Text(note, style: text.bodySmall)),
                ],
              ),
            ),
        ],
        if (ability.lore.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              ability.lore,
              style: text.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.white54,
              ),
            ),
          ),
      ],
    );
  }
}

/// The in-place demo control on an expanded Ability card: a small play
/// button; first tap streams (and caches) the Valve CDN demo, then the
/// video plays inline. A missing demo or a failed download degrades to a
/// quiet note — the card's description and stats stay the point.
class _AbilityDemo extends ConsumerStatefulWidget {
  const _AbilityDemo({required this.heroKey, required this.ability});

  /// The hero's Valve CDN folder name (e.g. `antimage`).
  final String heroKey;

  final AbilityDetail ability;

  @override
  ConsumerState<_AbilityDemo> createState() => _AbilityDemoState();
}

class _AbilityDemoState extends ConsumerState<_AbilityDemo> {
  /// What the control shows: idle play button → loading → inline video,
  /// or the degraded note when the CDN has no demo / the download failed.
  _DemoPhase _phase = _DemoPhase.idle;
  File? _video;

  Future<void> _play() async {
    setState(() => _phase = _DemoPhase.loading);
    final url = CdnUrls.abilityDemoVideo(widget.heroKey, widget.ability.name);
    final File file;
    try {
      file = await ref.read(abilityVideoRepositoryProvider).videoFileFor(url);
    } on AbilityVideoException {
      // Missing demo or failed download — both degrade the same quiet way.
      if (mounted) setState(() => _phase = _DemoPhase.unavailable);
      return;
    }
    if (!mounted) return;
    setState(() {
      _video = file;
      _phase = _DemoPhase.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _DemoPhase.idle:
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            key: ValueKey<String>('ability-demo-play-${widget.ability.name}'),
            borderRadius: BorderRadius.circular(6),
            onTap: _play,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    size: 18,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Play demo',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        );
      case _DemoPhase.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case _DemoPhase.unavailable:
        return DemoUnavailable(
          key: ValueKey<String>(
            'ability-demo-unavailable-${widget.ability.name}',
          ),
        );
      case _DemoPhase.playing:
        final video = _video;
        if (video == null) return const SizedBox.shrink();
        final buildVideo = ref.watch(abilityDemoVideoBuilderProvider);
        return buildVideo(context, video, widget.ability.name);
    }
  }
}

enum _DemoPhase { idle, loading, playing, unavailable }

/// One cost row: "Cast Range: 875 / 950 / 1025 / 1100" — one value per
/// Ability level, the way the site's tooltip shows them.
class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.values});

  final String label;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: _StatRow(label: label, value: values.map(_fmtNum).join(' / ')),
    );
  }
}

/// One row of the per-level value table: heading left, per-level values
/// right, `%` on every value for percentage rows.
class _SpecialRow extends StatelessWidget {
  const _SpecialRow({required this.special});

  final AbilitySpecialValue special;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final values = special.values
        .map((value) => '${_fmtNum(value)}${special.isPercentage ? '%' : ''}')
        .join(' / ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              special.heading,
              style: text.labelMedium?.copyWith(color: Colors.white54),
            ),
          ),
          Text(values, style: text.labelMedium),
        ],
      ),
    );
  }
}

/// A Scepter/Shard enhancement sentence, labelled with its mark.
class _EnhancementRow extends StatelessWidget {
  const _EnhancementRow({required this.mark, required this.text});

  final AbilityMark mark;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MarkBadge(mark: mark),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _FacetsCard extends StatelessWidget {
  const _FacetsCard({required this.facets});

  final List<HeroFacet> facets;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget abilityRows(String label, List<FacetAbility> abilities) {
      if (abilities.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.labelLarge?.copyWith(color: Colors.white54),
            ),
            for (final ability in abilities)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ability.displayName,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(ability.description, style: text.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return _SectionCard(
      key: const ValueKey<String>('facets-section'),
      title: 'Facets',
      children: [
        for (final facet in facets) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facet.title, style: text.titleSmall),
                Text(facet.description, style: text.bodySmall),
                abilityRows('Grants', facet.granted),
                abilityRows('Changes', facet.changed),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The Talent tree: four tiers (10 – 25, top tier first like the official
/// tree), two options per tier. Feed order: pair (2i, 2i+1) is the level
/// 10+5i tier, option 2i on the right, 2i+1 on the left.
class _TalentsCard extends StatelessWidget {
  const _TalentsCard({required this.talents});

  final List<String> talents;

  @override
  Widget build(BuildContext context) {
    if (talents.length < 8) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey<String>('talent-tree'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Talents', style: text.titleMedium),
            const SizedBox(height: 8),
            for (var tier = 3; tier >= 0; tier--) ...[
              if (tier != 3) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TalentOption(
                      text: talents[2 * tier + 1],
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        '${10 + 5 * tier}',
                        style: text.titleSmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TalentOption(
                      text: talents[2 * tier],
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TalentOption extends StatelessWidget {
  const _TalentOption({required this.text, required this.alignment});

  final String text;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : TextAlign.left,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _LoreCard extends StatelessWidget {
  const _LoreCard({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Lore',
      children: [Text(bio, style: Theme.of(context).textTheme.bodyMedium)],
    );
  }
}

class _AbilityPatchNotesSection extends StatelessWidget {
  const _AbilityPatchNotesSection({required this.deltas});

  final List<HeroAbilityDeltaRecord> deltas;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 16, color: Color(0xFF81C784)),
              const SizedBox(width: 6),
              Text(
                'Recent Patch Changes',
                style: text.labelMedium?.copyWith(
                  color: const Color(0xFF81C784),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final delta in deltas) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Patch ${delta.patchNumber}',
                style: text.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final line in delta.lines)
              Padding(
                padding: EdgeInsets.only(
                  left: (line.indentLevel - 1) * 12.0 + 4,
                  bottom: 2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFF81C784),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line.text,
                        style: text.bodySmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HeroChangelogCard extends StatefulWidget {
  const _HeroChangelogCard({
    required this.patchHistory,
    required this.abilities,
  });

  final HeroPatchHistory patchHistory;
  final List<AbilityDetail> abilities;

  @override
  State<_HeroChangelogCard> createState() => _HeroChangelogCardState();
}

class _HeroChangelogCardState extends State<_HeroChangelogCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final deltas = widget.patchHistory.deltas;

    return Card(
      key: const ValueKey<String>('hero-changelog-section'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(
                    Icons.change_history,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Changelog', style: text.titleMedium)),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              if (deltas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No patch deltas in recent patches.',
                    style: text.bodySmall?.copyWith(color: Colors.white54),
                  ),
                )
              else
                for (final delta in deltas) ...[
                  _PatchDeltaEntry(delta: delta, abilities: widget.abilities),
                  if (delta != deltas.last)
                    const Divider(height: 16, color: Colors.white12),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PatchDeltaEntry extends StatelessWidget {
  const _PatchDeltaEntry({required this.delta, required this.abilities});

  final HeroPatchDelta delta;
  final List<AbilityDetail> abilities;

  String _resolveAbilityName(HeroAbilityPatchDelta abilityDelta) {
    for (final ability in abilities) {
      if (ability.name == abilityDelta.abilityName) {
        return ability.displayName;
      }
    }
    return abilityDelta.abilityName ?? 'Ability #${abilityDelta.abilityId}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Patch ${delta.patchNumber}',
                style: text.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (delta.timestamp > 0) ...[
              const SizedBox(width: 8),
              Text(
                formatPatchDate(delta.releaseDate),
                style: text.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ],
        ),
        if (delta.stats.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Stats',
              style: text.labelSmall?.copyWith(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final line in delta.stats)
            Padding(
              padding: EdgeInsets.only(
                left: (line.indentLevel - 1) * 12.0 + 8,
                top: 2,
              ),
              child: Text('• ${line.text}', style: text.bodySmall),
            ),
        ],
        if (delta.abilities.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Abilities',
              style: text.labelSmall?.copyWith(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final ability in delta.abilities) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                _resolveAbilityName(ability),
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
            for (final line in ability.lines)
              Padding(
                padding: EdgeInsets.only(
                  left: (line.indentLevel - 1) * 12.0 + 16,
                  top: 1,
                ),
                child: Text('• ${line.text}', style: text.bodySmall),
              ),
          ],
        ],
        if (delta.talents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Talents',
              style: text.labelSmall?.copyWith(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final line in delta.talents)
            Padding(
              padding: EdgeInsets.only(
                left: (line.indentLevel - 1) * 12.0 + 8,
                top: 2,
              ),
              child: Text('• ${line.text}', style: text.bodySmall),
            ),
        ],
      ],
    );
  }
}

/// Game-number formatting, mirroring the official site: truncated toward
/// zero to at most two decimals, trailing `.0` stripped (6.16 stays 6.16,
/// 25.0 shows 25) — same rule the converter applies, so the rendered value
/// is the emitted value.
String _fmtNum(num value) {
  if (value == value.truncateToDouble()) return value.truncate().toString();
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'0$'), '');
}
