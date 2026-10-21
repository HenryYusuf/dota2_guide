// Hero detail screen seam: the real screen and its section widgets over a
// fake repository and stubbed media builders — no HTTP, no assets, no CDN
// (ADR-0001: media streams at runtime; spec: widget tests never touch the
// network). Pins the ticket's UI contract: collapsing header, Attributes /
// Combat stats cards, ability cards that expand in place to their per-level
// table, visually distinct Innate / Scepter / Shard marks, facets hidden
// when empty, a four-tier talent tree, lore — plus grid→detail navigation
// with override-preferred reads (refreshed data wins).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';
import 'package:dota2_guide/core/data/file_store.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/core/data/snapshot_refresher.dart';
import 'package:dota2_guide/features/heroes/ability_video_repository.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_detail_repository.dart';
import 'package:dota2_guide/features/heroes/hero_detail_screen.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_screen.dart';

import '../../core/data/fake_datafeed_client.dart';
import '../../core/data/in_memory_file_store.dart';
import '../../core/data/refresh_seam_overrides.dart';

const _cdn = 'https://cdn.steamstatic.com/apps/dota2/images/dota_react';

AbilityDetail _ability({
  required String name,
  required String displayName,
  String description = 'Does a thing.',
  String lore = '',
  List<String> notes = const [],
  bool isInnate = false,
  bool isUltimate = false,
  String? grantedBy,
  String behaviorTag = 'No Target',
  String? target,
  String? damageType,
  String? piercesSpellImmunity,
  List<double> castRanges = const [0],
  List<double> manaCosts = const [0],
  List<double> cooldowns = const [0],
  List<AbilitySpecialValue> specialValues = const [],
  String? scepterText,
  String? shardText,
}) => AbilityDetail(
  name: name,
  displayName: displayName,
  iconUrl: '$_cdn/abilities/$name.png',
  description: description,
  lore: lore,
  notes: notes,
  isInnate: isInnate,
  isUltimate: isUltimate,
  grantedBy: grantedBy,
  behaviorTag: behaviorTag,
  target: target,
  piercesSpellImmunity: piercesSpellImmunity,
  damageType: damageType,
  dispellable: null,
  castRanges: castRanges,
  manaCosts: manaCosts,
  cooldowns: cooldowns,
  specialValues: specialValues,
  scepterText: scepterText,
  shardText: shardText,
);

/// A schema-complete Anti-Mage-flavoured detail with every mark the screen
/// distinguishes: an innate ability, an ultimate, a Scepter-granted ability,
/// a Shard-granted ability, and (optionally) a Facet.
HeroDetail _detail({bool withFacets = false}) => HeroDetail(
  schemaVersion: heroDetailSchemaVersion,
  locale: 'english',
  hero: HeroProfile(
    id: 1,
    valveKey: 'npc_dota_hero_antimage',
    localizedName: 'Anti-Mage',
    oneLiner: 'Slashes his foes with mana-draining attacks',
    primaryAttribute: PrimaryAttribute.agility,
    complexity: 1,
    portraitUrl: '$_cdn/heroes/antimage.png',
    attributes: HeroAttributes(
      strength: AttributeValue(base: 21, gain: 1.6),
      agility: AttributeValue(base: 25, gain: 2.8),
      intelligence: AttributeValue(base: 12, gain: 1.8),
    ),
    combat: const HeroCombatStats(
      damageMin: 54,
      damageMax: 58,
      attackRate: 1.4,
      attackRange: 150,
      projectileSpeed: 0,
      armor: 6.16,
      magicResistance: 25,
      movementSpeed: 315,
      turnRate: 0.6,
      sightRangeDay: 1800,
      sightRangeNight: 800,
    ),
    bio: 'The monks of Turstarkuri watched the rugged valleys below.',
  ),
  abilities: [
    _ability(
      name: 'antimage_mana_break',
      displayName: 'Mana Break',
      description: 'Burns mana on each attack.',
      notes: const ['25% mana burn from illusions.'],
      damageType: 'Physical',
      piercesSpellImmunity: 'No',
      specialValues: const [
        AbilitySpecialValue(
          heading: 'MANA BURNED PER HIT:',
          values: [25, 30, 35, 40],
          isPercentage: false,
        ),
        AbilitySpecialValue(
          heading: 'MAX MANA BURNED PER HIT:',
          values: [1.8, 2.7, 3.6, 4.5],
          isPercentage: true,
        ),
      ],
    ),
    _ability(
      name: 'antimage_blink',
      displayName: 'Blink',
      description: 'Short distance teleportation.',
      castRanges: const [875, 950, 1025, 1100],
      manaCosts: const [60, 55, 50, 45],
      cooldowns: const [10.5, 9, 7.5, 6],
      behaviorTag: 'Point Target',
      specialValues: const [
        AbilitySpecialValue(
          heading: 'DEBUFF DURATION:',
          values: [0.5],
          isPercentage: false,
        ),
      ],
    ),
    _ability(
      name: 'antimage_persectur',
      displayName: 'Persecutor',
      description: 'Attacks slow enemies based on missing mana.',
      isInnate: true,
      behaviorTag: 'Passive',
    ),
    _ability(
      name: 'antimage_mana_void',
      displayName: 'Mana Void',
      description: 'Damages based on missing mana.',
      isUltimate: true,
      target: 'Enemy Units',
      damageType: 'Magical',
      piercesSpellImmunity: 'No',
      manaCosts: const [100, 150, 200],
      cooldowns: const [100, 85, 70],
    ),
    _ability(
      name: 'antimage_mana_flare',
      displayName: 'Mana Flare',
      description: 'Channels a flare around Anti-Mage.',
      grantedBy: 'scepter',
      scepterText: 'Increases flare radius.',
    ),
    _ability(
      name: 'antimage_counterspell_shard',
      displayName: 'Counterspell Upgrade',
      description: 'Adds a passive reflection.',
      grantedBy: 'shard',
      shardText: 'Grants a chance to reflect.',
    ),
  ],
  talents: const [
    '+3 Health Regen',
    '+200 Mana Void Radius',
    '+9% Persecutor Min Movement Slow',
    '+0.2 Mana Void Damage Multiplier',
    '+125 Blink Cast Range',
    '-1s Blink Cooldown',
    '+0.8s Mana Void Stun',
    '-50s Mana Void Cooldown',
  ],
  facets: withFacets
      ? const [
          HeroFacet(
            title: "Magebane's Mirror",
            description: 'Counterspell burns the countered spell mana.',
            granted: [
              FacetAbility(
                displayName: 'Mana Flare',
                description: 'Throws a flare burning mana.',
              ),
            ],
            changed: [
              FacetAbility(
                displayName: 'Counterspell',
                description: 'Burns mana when reflecting a spell.',
              ),
            ],
          ),
        ]
      : const [],
);

class _FakeDetailRepository implements HeroDetailRepository {
  _FakeDetailRepository(this.detail);

  final HeroDetail detail;

  @override
  Future<HeroDetail> loadHeroDetail(int heroId) async => detail;
}

class _FailingDetailRepository implements HeroDetailRepository {
  @override
  Future<HeroDetail> loadHeroDetail(int heroId) async {
    throw const FormatException('Simulated: unreadable detail file');
  }
}

/// The demo-video seam, faked: either hands back a (fake) cached file or
/// throws the CDN-shaped failure, and records every URL it was asked for so
/// the test can pin the two-level path convention.
class _FakeVideoRepository implements AbilityVideoRepository {
  _FakeVideoRepository({this.error}) : file = null;

  _FakeVideoRepository.playable()
    : error = null,
      file = File(r'C:\cache\antimage_blink.webm');

  /// The failure to throw instead of serving a file (404 vs transport).
  final Object? error;

  /// The local file "already in the cache".
  final File? file;

  final List<String> requestedUrls = <String>[];

  @override
  Future<File> videoFileFor(String cdnUrl) async {
    requestedUrls.add(cdnUrl);
    final Object? error = this.error;
    if (error != null) throw error;
    return file!;
  }
}

/// The video_player layer, stubbed: the only networked/platform widget on
/// this screen besides the icons, findable by the ability it was handed.
Widget _stubVideo(BuildContext context, File video, String abilityName) =>
    SizedBox(key: ValueKey<String>('demo-video-$abilityName'));

/// The CDN layer, stubbed: header media and ability icons are the only
/// networked widgets on this screen, each findable by the URL it was handed.
Widget _stubHeader(BuildContext context, HeroDetail detail) =>
    SizedBox(key: ValueKey<String>('header-${detail.hero.portraitUrl}'));

Widget _stubIcon(BuildContext context, AbilityDetail ability) =>
    SizedBox(key: ValueKey<String>('icon-${ability.name}'));

void main() {
  /// Renders the real [HeroDetailScreen] over a fake repository. The surface
  /// is deliberately tall so every section is laid out (SliverList builds
  /// lazily — off-screen sections would otherwise not exist to find).
  Future<void> pumpDetail(
    WidgetTester tester, {
    HeroDetail? detail,
    HeroDetailRepository? repository,
    AbilityVideoRepository? videoRepository,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroDetailRepositoryProvider.overrideWithValue(
            repository ?? _FakeDetailRepository(detail ?? _detail()),
          ),
          heroHeaderBuilderProvider.overrideWithValue(_stubHeader),
          abilityIconBuilderProvider.overrideWithValue(_stubIcon),
          abilityDemoVideoBuilderProvider.overrideWithValue(_stubVideo),
          if (videoRepository != null)
            abilityVideoRepositoryProvider.overrideWithValue(videoRepository),
        ],
        child: const MaterialApp(home: HeroDetailScreen(heroId: 1)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String abilityName) =>
      find.byKey(ValueKey<String>('ability-$abilityName'));

  /// Expands the Blink card and taps its demo play control — the shared
  /// setup every demo-behaviour test starts from.
  Future<Finder> tapDemoPlay(WidgetTester tester) async {
    final blink = card('antimage_blink');
    await tester.tap(find.descendant(of: blink, matching: find.text('Blink')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('ability-demo-play-antimage_blink')),
    );
    await tester.pumpAndSettle();
    return blink;
  }

  testWidgets(
    'renders the collapsing header, attributes, combat stats, and lore',
    (tester) async {
      await pumpDetail(tester);

      // Collapsing header: name in the app bar, media behind it, and the
      // primary attribute + complexity inside the header itself (they
      // collapse away with the portrait).
      expect(find.text('Anti-Mage'), findsOneWidget);
      final header = find.byKey(
        const ValueKey<String>('header-$_cdn/heroes/antimage.png'),
      );
      expect(header, findsOneWidget);
      final appBar = find.byType(SliverAppBar);
      expect(
        find.descendant(of: appBar, matching: find.text('Agility')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appBar, matching: find.text('Complexity')),
        findsOneWidget,
      );
      expect(
        find.text('Slashes his foes with mana-draining attacks'),
        findsOneWidget,
      );

      // Attributes: base + per-level gain, Agility highlighted as primary.
      // Scoped to the section: the talent tree renders its own level labels.
      final attributes = find.byKey(
        const ValueKey<String>('attributes-section'),
      );
      expect(attributes, findsOneWidget);
      expect(
        find.descendant(of: attributes, matching: find.text('21')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attributes, matching: find.text('+1.6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attributes, matching: find.text('25')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attributes, matching: find.text('+2.8')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attributes, matching: find.text('12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attributes, matching: find.text('+1.8')),
        findsOneWidget,
      );

      // Combat stats, including the site's two-decimal armor truncation.
      final combat = find.byKey(const ValueKey<String>('combat-section'));
      expect(combat, findsOneWidget);
      expect(
        find.descendant(of: combat, matching: find.text('54 - 58')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: combat, matching: find.text('6.16')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: combat, matching: find.text('25%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: combat, matching: find.text('315')),
        findsOneWidget,
      );
      // Melee heroes show no projectile speed (feed value 0).
      expect(find.text('Projectile Speed'), findsNothing);

      // Lore.
      expect(find.text('Lore'), findsOneWidget);
      expect(
        find.text('The monks of Turstarkuri watched the rugged valleys below.'),
        findsOneWidget,
      );

      // The header actually collapses: with all content asserted on the
      // tall surface, shrink to phone size so the page can scroll, then
      // verify scrolling collapses the pinned app bar's painted extent.
      RenderSliver appBarSliver() => tester.renderObject<RenderSliver>(appBar);
      expect(appBarSliver().geometry!.paintExtent, 220);
      tester.view.physicalSize = const Size(1080, 1600);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(appBarSliver().geometry!.paintExtent, lessThan(220));
    },
  );

  testWidgets(
    'ability cards are collapsed by default and expand in place to their '
    'per-level table',
    (tester) async {
      await pumpDetail(tester);

      final blink = card('antimage_blink');
      expect(
        find.descendant(of: blink, matching: find.text('Blink')),
        findsOneWidget,
      );

      // Collapsed: no per-level table, no description.
      expect(
        find.descendant(of: blink, matching: find.text('DEBUFF DURATION:')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: blink,
          matching: find.text('Short distance teleportation.'),
        ),
        findsNothing,
      );

      // Expand in place: description, costs, and the per-level table appear
      // inside the same card (values joined the way the site shows them).
      await tester.tap(
        find.descendant(of: blink, matching: find.text('Blink')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: blink,
          matching: find.text('Short distance teleportation.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: blink,
          matching: find.text('875 / 950 / 1025 / 1100'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blink, matching: find.text('60 / 55 / 50 / 45')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blink, matching: find.text('10.5 / 9 / 7.5 / 6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blink, matching: find.text('DEBUFF DURATION:')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blink, matching: find.text('0.5')),
        findsOneWidget,
      );
      // Behaviour and targeting tags render as chips in the expanded body.
      expect(
        find.descendant(of: blink, matching: find.text('Point Target')),
        findsOneWidget,
      );

      // Another card is still collapsed: expansion is per-card, in place.
      final manaBreak = card('antimage_mana_break');
      expect(
        find.descendant(
          of: manaBreak,
          matching: find.text('MANA BURNED PER HIT:'),
        ),
        findsNothing,
      );

      // Tapping again collapses it.
      await tester.tap(
        find.descendant(of: blink, matching: find.text('Blink')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: blink, matching: find.text('DEBUFF DURATION:')),
        findsNothing,
      );
    },
  );

  testWidgets('the per-level table marks percentage rows with %', (
    tester,
  ) async {
    await pumpDetail(tester);

    final manaBreak = card('antimage_mana_break');
    await tester.tap(
      find.descendant(of: manaBreak, matching: find.text('Mana Break')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: manaBreak, matching: find.text('25 / 30 / 35 / 40')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: manaBreak,
        matching: find.text('1.8% / 2.7% / 3.6% / 4.5%'),
      ),
      findsOneWidget,
    );
    // Notes render in the expanded body.
    expect(
      find.descendant(
        of: manaBreak,
        matching: find.text('25% mana burn from illusions.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('innate and Aghanim marks are visually distinct badges', (
    tester,
  ) async {
    await pumpDetail(tester);

    Color badgeColor(ValueKey<String> key) {
      final badge = tester.widget<Container>(find.byKey(key));
      return (badge.decoration! as BoxDecoration).color!;
    }

    // Each mark exists on its own ability card…
    expect(
      find.descendant(
        of: card('antimage_persectur'),
        matching: find.byKey(const ValueKey<String>('ability-badge-innate')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card('antimage_mana_flare'),
        matching: find.byKey(const ValueKey<String>('ability-badge-scepter')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card('antimage_counterspell_shard'),
        matching: find.byKey(const ValueKey<String>('ability-badge-shard')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card('antimage_mana_void'),
        matching: find.byKey(const ValueKey<String>('ability-badge-ultimate')),
      ),
      findsOneWidget,
    );

    // …and no card wears another's mark, so the colours can't be confused.
    expect(
      find.descendant(
        of: card('antimage_persectur'),
        matching: find.byKey(const ValueKey<String>('ability-badge-scepter')),
      ),
      findsNothing,
    );

    // The three aghanim-family/innate colours are pairwise distinct.
    final innate = badgeColor(const ValueKey<String>('ability-badge-innate'));
    final scepter = badgeColor(const ValueKey<String>('ability-badge-scepter'));
    final shard = badgeColor(const ValueKey<String>('ability-badge-shard'));
    expect(innate, isNot(scepter));
    expect(scepter, isNot(shard));
    expect(innate, isNot(shard));
  });

  testWidgets('scepter and shard enhancements render in the expanded body', (
    tester,
  ) async {
    await pumpDetail(tester);

    final flare = card('antimage_mana_flare');
    await tester.tap(
      find.descendant(of: flare, matching: find.text('Mana Flare')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: flare,
        matching: find.text('Increases flare radius.'),
      ),
      findsOneWidget,
    );

    final shardCard = card('antimage_counterspell_shard');
    await tester.tap(
      find.descendant(
        of: shardCard,
        matching: find.text('Counterspell Upgrade'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: shardCard,
        matching: find.text('Grants a chance to reflect.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'an ability card offers an in-place demo play control that streams '
    'through the CDN path convention',
    (tester) async {
      final videos = _FakeVideoRepository.playable();
      await pumpDetail(tester, videoRepository: videos);

      final blink = card('antimage_blink');

      // The play control lives inside the expanded card, not on a route of
      // its own; tapping it streams the demo inline via the injected player.
      await tester.tap(
        find.descendant(of: blink, matching: find.text('Blink')),
      );
      await tester.pumpAndSettle();
      final play = find.descendant(
        of: blink,
        matching: find.byKey(
          const ValueKey<String>('ability-demo-play-antimage_blink'),
        ),
      );
      expect(play, findsOneWidget);
      await tester.tap(play);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: blink,
          matching: find.byKey(
            const ValueKey<String>('demo-video-antimage_blink'),
          ),
        ),
        findsOneWidget,
      );

      // The requested URL follows the verified two-level convention: hero
      // folder + full ability name (.webm), never the flat icon-style path.
      expect(videos.requestedUrls, [
        'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
            'antimage/antimage_blink.webm',
      ]);
    },
  );

  testWidgets(
    'a missing demo degrades inline: description and stats stay visible',
    (tester) async {
      // The CDN has no video at that URL — the discovery-time 404 the spec
      // calls a normal state.
      await pumpDetail(
        tester,
        videoRepository: _FakeVideoRepository(
          error: VideoUnavailableException('https://example/none.webm'),
        ),
      );

      final blink = await tapDemoPlay(tester);

      // Small inline degraded state — and the card's content stays the point.
      expect(
        find.descendant(of: blink, matching: find.text('No demo video')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: blink,
          matching: find.text('Short distance teleportation.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: blink,
          matching: find.text('875 / 950 / 1025 / 1100'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: blink, matching: find.text('DEBUFF DURATION:')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed demo download degrades the same quiet way', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      videoRepository: _FakeVideoRepository(
        error: VideoDownloadException(
          'https://example/offline.webm',
          'offline',
        ),
      ),
    );

    final blink = await tapDemoPlay(tester);

    expect(
      find.descendant(of: blink, matching: find.text('No demo video')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: blink,
        matching: find.text('Short distance teleportation.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'facets are hidden when empty and list granted/changed abilities when '
    'present',
    (tester) async {
      // Current game data has no facets (patch 7.41 removed them): the
      // section must not render an empty card.
      await pumpDetail(tester);
      expect(find.text('Facets'), findsNothing);

      // With facets (pipeline stays complete for their return), each facet
      // shows its title, description, and changed abilities.
      await pumpDetail(tester, detail: _detail(withFacets: true));
      final facets = find.byKey(const ValueKey<String>('facets-section'));
      expect(facets, findsOneWidget);
      expect(
        find.descendant(of: facets, matching: find.text("Magebane's Mirror")),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: facets,
          matching: find.text('Counterspell burns the countered spell mana.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: facets, matching: find.text('Counterspell')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: facets,
          matching: find.text('Burns mana when reflecting a spell.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the talent tree shows four tiers of two options, 25 on top', (
    tester,
  ) async {
    await pumpDetail(tester);

    final tree = find.byKey(const ValueKey<String>('talent-tree'));
    expect(tree, findsOneWidget);
    for (final label in const ['25', '20', '15', '10']) {
      expect(
        find.descendant(of: tree, matching: find.text(label)),
        findsOneWidget,
      );
    }

    // Tier labels stack top-down: 25 above 10.
    expect(
      tester
          .getTopLeft(find.descendant(of: tree, matching: find.text('25')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.descendant(of: tree, matching: find.text('10')))
            .dy,
      ),
    );

    // Feed order: pair (2i, 2i+1) is level 10+5i, option 2i on the right,
    // option 2i+1 on the left — checked on every tier, not just level 10.
    final talents = _detail().talents;
    for (var tier = 0; tier < 4; tier++) {
      final left = find.descendant(
        of: tree,
        matching: find.text(talents[2 * tier + 1]),
      );
      final right = find.descendant(
        of: tree,
        matching: find.text(talents[2 * tier]),
      );
      final level = find.descendant(
        of: tree,
        matching: find.text('${10 + 5 * tier}'),
      );
      final leftPos = tester.getTopLeft(left);
      final rightPos = tester.getTopLeft(right);
      final levelPos = tester.getTopLeft(level);
      expect(leftPos.dx, lessThan(rightPos.dx), reason: 'tier $level left');
      expect(leftPos.dy, closeTo(rightPos.dy, 1), reason: 'tier $level row');
      expect(
        leftPos.dy,
        closeTo(levelPos.dy, 8),
        reason: 'tier ${10 + 5 * tier} label beside its options',
      );
    }

    // All eight talents render.
    for (final talent in talents) {
      expect(
        find.descendant(of: tree, matching: find.text(talent)),
        findsOneWidget,
        reason: 'talent "$talent" should be on the tree',
      );
    }
  });

  testWidgets('a load failure shows a quiet error, not a crash', (
    tester,
  ) async {
    await pumpDetail(tester, repository: _FailingDetailRepository());

    expect(find.text("Couldn't load this hero."), findsOneWidget);
    expect(find.byType(HeroDetailScreen), findsOneWidget);
  });

  testWidgets('a grid tile opens the Hero detail page (bundled data)', (
    tester,
  ) async {
    // Full app over the real repositories and the real bundled snapshot;
    // only the CDN layer, the file store, and the feed are stubbed.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portraitBuilderProvider.overrideWithValue(
            (context, hero) =>
                SizedBox(key: ValueKey<String>(hero.portraitUrl)),
          ),
          heroHeaderBuilderProvider.overrideWithValue(_stubHeader),
          abilityIconBuilderProvider.overrideWithValue(_stubIcon),
          ...refreshSeamOverrides(),
        ],
        child: const AegisApp(),
      ),
    );
    await tester.pumpAndSettle();

    Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    await tester.tap(navLabel('Heroes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anti-Mage'));
    await tester.pumpAndSettle();

    expect(find.byType(HeroDetailScreen), findsOneWidget);
    final screen = find.byType(HeroDetailScreen);
    expect(
      find.descendant(of: screen, matching: find.text('Anti-Mage')),
      findsOneWidget,
    );
    // Real bundled detail data, not the roster index.
    expect(
      find.descendant(
        of: screen,
        matching: find.text('Slashes his foes with mana-draining attacks'),
      ),
      findsOneWidget,
    );

    // Back returns to the grid.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HeroDetailScreen), findsNothing);
    expect(find.byType(HeroesScreen), findsOneWidget);
  });

  testWidgets(
    'grid→detail prefers a committed override (refreshed data wins)',
    (tester) async {
      // What a refresh would have committed for Anti-Mage: same schema,
      // recognisably different texts.
      final files = InMemoryFileStore();
      await OverrideStore(files).commit(
        manifest: SnapshotManifest(
          dataVersion: 99,
          fetchedAt: DateTime.utc(2026, 10, 21, 8),
        ),
        blobs: {'hero_1.english.json': _refreshedDetailJson()},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portraitBuilderProvider.overrideWithValue(
              (context, hero) =>
                  SizedBox(key: ValueKey<String>(hero.portraitUrl)),
            ),
            heroHeaderBuilderProvider.overrideWithValue(_stubHeader),
            abilityIconBuilderProvider.overrideWithValue(_stubIcon),
            fileStoreProvider.overrideWithValue(files),
            datafeedClientProvider.overrideWithValue(
              FakeDatafeedClient()..failProbe = true,
            ),
          ],
          child: const AegisApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Heroes'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Anti-Mage'));
      await tester.pumpAndSettle();

      final screen = find.byType(HeroDetailScreen);
      expect(
        find.descendant(
          of: screen,
          matching: find.text('Refreshed one-liner for Anti-Mage.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: screen,
          matching: find.text('Slashes his foes with mana-draining attacks'),
        ),
        findsNothing,
      );
    },
  );
}

/// The committed override's file content: the fake detail re-encoded through
/// the real schema, so the override is byte-shape compatible exactly like a
/// refresh unit's output.
String _refreshedDetailJson() {
  final refreshed = _detail();
  return '''
{
  "schema_version": 1,
  "locale": "english",
  "hero": {
    "id": 1,
    "valve_key": "${refreshed.hero.valveKey}",
    "localized_name": "${refreshed.hero.localizedName}",
    "one_liner": "Refreshed one-liner for Anti-Mage.",
    "primary_attribute": "agility",
    "complexity": 1,
    "portrait_url": "${refreshed.hero.portraitUrl}",
    "attributes": {
      "strength": {"base": 21, "gain": 1.6},
      "agility": {"base": 25, "gain": 2.8},
      "intelligence": {"base": 12, "gain": 1.8}
    },
    "combat": {
      "damage_min": 54,
      "damage_max": 58,
      "attack_rate": 1.4,
      "attack_range": 150,
      "projectile_speed": 0,
      "armor": 6.16,
      "magic_resistance": 25,
      "movement_speed": 315,
      "turn_rate": 0.6,
      "sight_range_day": 1800,
      "sight_range_night": 800
    },
    "bio": "The monks of Turstarkuri watched the rugged valleys below."
  },
  "abilities": [],
  "talents": [
    "+3 Health Regen",
    "+200 Mana Void Radius",
    "+9% Persecutor Min Movement Slow",
    "+0.2 Mana Void Damage Multiplier",
    "+125 Blink Cast Range",
    "-1s Blink Cooldown",
    "+0.8s Mana Void Stun",
    "-50s Mana Void Cooldown"
  ],
  "facets": []
}
''';
}
