import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_detail_repository.dart';
import 'package:dota2_guide/features/heroes/hero_detail_screen.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/patches/hero_patch_deltas_repository.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';

AbilityDetail _ability({
  required String name,
  required String displayName,
  String description = 'Does a thing.',
}) => AbilityDetail(
  name: name,
  displayName: displayName,
  iconUrl: 'https://cdn.example.com/$name.png',
  description: description,
  lore: '',
  notes: const [],
  isInnate: false,
  isUltimate: false,
  grantedBy: null,
  behaviorTag: 'No Target',
  target: null,
  damageType: null,
  dispellable: null,
  piercesSpellImmunity: null,
  castRanges: const [0],
  manaCosts: const [0],
  cooldowns: const [0],
  specialValues: const [],
  scepterText: null,
  shardText: null,
);

HeroDetail _detail() => HeroDetail(
  schemaVersion: heroDetailSchemaVersion,
  locale: 'english',
  hero: HeroProfile(
    id: 1,
    valveKey: 'npc_dota_hero_antimage',
    localizedName: 'Anti-Mage',
    oneLiner: 'Slashes his foes with mana-draining attacks',
    primaryAttribute: PrimaryAttribute.agility,
    complexity: 1,
    portraitUrl: 'https://cdn.example.com/antimage.png',
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
    bio: 'The monks of Turstarkuri...',
  ),
  abilities: [
    _ability(name: 'antimage_mana_break', displayName: 'Mana Break'),
    _ability(name: 'antimage_blink', displayName: 'Blink'),
    _ability(name: 'antimage_mana_void', displayName: 'Mana Void'),
  ],
  talents: const ['+3 Health Regen', '+200 Mana Void Radius'],
  facets: const [],
);

class _FakeHeroDetailRepository implements HeroDetailRepository {
  _FakeHeroDetailRepository(this.detail);

  final HeroDetail detail;

  @override
  Future<HeroDetail> loadHeroDetail(int heroId) async => detail;
}

class _FakeHeroPatchDeltaRepository implements HeroPatchDeltaRepository {
  _FakeHeroPatchDeltaRepository(this.history);

  final HeroPatchHistory history;

  @override
  Future<HeroPatchHistory> loadHeroPatchHistory(int heroId) async => history;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeHistory = HeroPatchHistory(
    heroId: 1,
    deltas: [
      HeroPatchDelta(
        patchNumber: '7.41f',
        patchName: '7.41f',
        timestamp: 1789455600,
        stats: const [],
        talents: const [
          PatchChangeLine(
            text: 'Level 15 Talent Mana Void Cooldown reduced',
            indentLevel: 1,
          ),
        ],
        abilities: const [
          HeroAbilityPatchDelta(
            abilityId: 5003,
            abilityName: 'antimage_mana_break',
            lines: [
              PatchChangeLine(
                text: 'Mana Burned as Damage increased from 60% to 65%',
                indentLevel: 1,
              ),
            ],
          ),
        ],
      ),
      HeroPatchDelta(
        patchNumber: '7.41d',
        patchName: '7.41d',
        timestamp: 1780556400,
        stats: const [
          PatchChangeLine(
            text: 'Base Agility increased from 24 to 25',
            indentLevel: 1,
          ),
        ],
        talents: const [],
        abilities: const [
          HeroAbilityPatchDelta(
            abilityId: 5004,
            abilityName: 'antimage_blink',
            lines: [
              PatchChangeLine(
                text: 'Mana Cost decreased from 65/60/55/50 to 60/55/50/45',
                indentLevel: 1,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Widget buildScreen({HeroPatchHistory? history}) {
    return ProviderScope(
      overrides: [
        heroDetailRepositoryProvider.overrideWithValue(
          _FakeHeroDetailRepository(_detail()),
        ),
        heroPatchDeltaRepositoryProvider.overrideWithValue(
          _FakeHeroPatchDeltaRepository(history ?? fakeHistory),
        ),
        portraitBuilderProvider.overrideWithValue(
          (context, hero) => const SizedBox(key: ValueKey('portrait')),
        ),
        heroHeaderBuilderProvider.overrideWithValue(
          (context, detail) => const SizedBox(key: ValueKey('header')),
        ),
        abilityIconBuilderProvider.overrideWithValue(
          (context, ability) => SizedBox(key: ValueKey('icon-${ability.name}')),
        ),
        abilityDemoVideoBuilderProvider.overrideWithValue(
          (context, video, abilityName) =>
              SizedBox(key: ValueKey('demo-video-$abilityName')),
        ),
      ],
      child: const MaterialApp(home: HeroDetailScreen(heroId: 1)),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    HeroPatchHistory? history,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildScreen(history: history));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Ability cards display "Changed in [Patch]" chip for modified abilities and none for unmodified',
    (tester) async {
      await pumpScreen(tester);

      // Mana Break modified in 7.41f
      expect(find.text('Changed in 7.41f'), findsOneWidget);

      // Blink modified in 7.41d
      expect(find.text('Changed in 7.41d'), findsOneWidget);

      // Mana Void was NOT modified in the recent 5 patches
      expect(
        find.byKey(const ValueKey('ability-patch-chip-antimage_mana_void')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Expanding an affected Ability card reveals the exact historical patch notes inline',
    (tester) async {
      await pumpScreen(tester);

      // Tap to expand Mana Break card
      final manaBreakCard = find.byKey(
        const ValueKey('ability-antimage_mana_break'),
      );
      expect(manaBreakCard, findsOneWidget);
      await tester.tap(manaBreakCard);
      await tester.pumpAndSettle();

      // Verify the patch note line is visible inline inside the expanded ability
      expect(
        find.text('Mana Burned as Damage increased from 60% to 65%'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Tapping "Changed in [Patch]" chip directly expands the card and reveals the notes inline',
    (tester) async {
      await pumpScreen(tester);

      final chip = find.text('Changed in 7.41f');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      // Verify note is revealed
      expect(
        find.text('Mana Burned as Damage increased from 60% to 65%'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Bottom Changelog section displays chronological patch notes for stats, talents, and abilities',
    (tester) async {
      await pumpScreen(tester);

      // Verify the section displays recent patches
      expect(
        find.byKey(const ValueKey('hero-changelog-section')),
        findsOneWidget,
      );
      expect(find.text('Changelog'), findsOneWidget);
      expect(find.text('Patch 7.41f'), findsOneWidget);
      expect(find.text('September 15, 2026'), findsOneWidget);
      expect(find.text('Patch 7.41d'), findsOneWidget);

      // Verify stat and talent notes appear
      expect(
        find.text('• Base Agility increased from 24 to 25'),
        findsOneWidget,
      );
      expect(
        find.text('• Level 15 Talent Mana Void Cooldown reduced'),
        findsOneWidget,
      );
      // Verify localized ability name is displayed in Changelog
      expect(find.text('Mana Break'), findsAtLeast(1));
    },
  );
}
