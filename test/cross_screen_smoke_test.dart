// Cross-screen widget smoke test: covers all four tabs (Home, Heroes, Items,
// Patches) plus About, navigating end-to-end over in-memory fake repositories
// (Issue 11 & User Story 45).
//
// Verifies routing contracts, parameter passing, tab state preservation, and
// inter-feature deep links (Home → About, Home → Patch Detail, Home → Heroes,
// Heroes → Hero Detail, Items → Item Detail → Component Item Detail,
// Patches → Patch Detail → Hero Detail) without hitting HTTP, disk, or CDN.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_detail_repository.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:dota2_guide/features/home/home_providers.dart';
import 'package:dota2_guide/features/home/news_repository.dart';
import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_detail_repository.dart';
import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_detail_repository.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';

import 'core/data/refresh_seam_overrides.dart';

// --- Fakes ---

class _FakeHeroesRepository implements HeroesRepository {
  @override
  Future<List<HeroSummary>> loadHeroes() async => const [
    HeroSummary(
      id: 1,
      valveKey: 'npc_dota_hero_antimage',
      localizedName: 'Anti-Mage',
      primaryAttribute: PrimaryAttribute.agility,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/antimage.png',
    ),
  ];
}

class _FakeHeroDetailRepository implements HeroDetailRepository {
  @override
  Future<HeroDetail> loadHeroDetail(int heroId) async {
    return const HeroDetail(
      schemaVersion: 1,
      locale: 'english',
      hero: HeroProfile(
        id: 1,
        valveKey: 'npc_dota_hero_antimage',
        localizedName: 'Anti-Mage',
        oneLiner: 'Slashes foes with mana-draining attacks',
        primaryAttribute: PrimaryAttribute.agility,
        complexity: 1,
        portraitUrl: 'https://cdn.example.com/antimage.png',
        attributes: HeroAttributes(
          strength: AttributeValue(base: 21, gain: 1.6),
          agility: AttributeValue(base: 25, gain: 2.8),
          intelligence: AttributeValue(base: 12, gain: 1.8),
        ),
        combat: HeroCombatStats(
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
        AbilityDetail(
          name: 'antimage_mana_break',
          displayName: 'Mana Break',
          iconUrl: 'https://cdn.example.com/mana_break.png',
          description: 'Burns mana per hit.',
          lore: '',
          notes: [],
          isInnate: false,
          isUltimate: false,
          grantedBy: null,
          behaviorTag: 'Passive',
          target: null,
          piercesSpellImmunity: null,
          damageType: 'Physical',
          dispellable: null,
          castRanges: [0],
          manaCosts: [0],
          cooldowns: [0],
          specialValues: [],
          scepterText: null,
          shardText: null,
        ),
      ],
      talents: [
        '+3 Health Regen',
        '+200 Mana Void Radius',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
      facets: [],
    );
  }
}

class _FakeItemsRepository implements ItemsRepository {
  @override
  Future<ItemIndex> loadItems() async => const ItemIndex(
    schemaVersion: 1,
    locale: 'english',
    items: [
      ItemSummary(
        id: 100,
        valveKey: 'item_cyclone',
        name: "Eul's Scepter of Divinity",
        iconUrl: 'https://cdn.example.com/cyclone.png',
        shopCategory: ShopCategory.caster,
        neutralTier: null,
        isRecipe: false,
      ),
      ItemSummary(
        id: 57,
        valveKey: 'item_staff_of_wizardry',
        name: 'Staff of Wizardry',
        iconUrl: 'https://cdn.example.com/staff_of_wizardry.png',
        shopCategory: ShopCategory.attributes,
        neutralTier: null,
        isRecipe: false,
      ),
    ],
  );
}

class _FakeItemDetailRepository implements ItemDetailRepository {
  @override
  Future<ItemDetail> loadItemDetail(int itemId) async {
    if (itemId == 100) {
      return const ItemDetail(
        schemaVersion: 1,
        locale: 'english',
        item: ItemProfile(
          id: 100,
          valveKey: 'item_cyclone',
          name: "Eul's Scepter of Divinity",
          iconUrl: 'https://cdn.example.com/cyclone.png',
          shopCategory: ShopCategory.caster,
          neutralTier: null,
          totalCost: 2600,
          combinationCost: 675,
          components: [57],
          attributes: [
            ItemAttribute(
              label: 'Intelligence',
              sign: '+',
              values: [10],
              isPercentage: false,
            ),
          ],
          effects: [
            ItemEffect(
              kind: ItemEffectKind.active,
              title: 'Cyclone',
              text: 'Sweeps a target unit up into a cyclone.',
            ),
          ],
          notes: [],
          lore: 'A mysterious scepter.',
        ),
      );
    }
    return const ItemDetail(
      schemaVersion: 1,
      locale: 'english',
      item: ItemProfile(
        id: 57,
        valveKey: 'item_staff_of_wizardry',
        name: 'Staff of Wizardry',
        iconUrl: 'https://cdn.example.com/staff_of_wizardry.png',
        shopCategory: ShopCategory.attributes,
        neutralTier: null,
        totalCost: 1000,
        combinationCost: null,
        components: [],
        attributes: [
          ItemAttribute(
            label: 'Intelligence',
            sign: '+',
            values: [10],
            isPercentage: false,
          ),
        ],
        effects: [],
        notes: [],
        lore: 'A staff of power.',
      ),
    );
  }
}

class _FakeNewsRepository implements NewsRepository {
  @override
  Future<List<NewsItem>> loadNews() async => const [
    NewsItem(
      id: '1',
      title: '7.41f Gameplay Patch Notes',
      url: 'https://example.com/news/1',
      timestamp: 1789497865,
    ),
  ];
}

class _FakePatchesRepository implements PatchesRepository {
  @override
  Future<PatchIndex> loadPatchIndex() async => const PatchIndex(
    schemaVersion: 1,
    locale: 'english',
    patches: [
      PatchSummary(
        patchNumber: '7.41f',
        patchName: '7.41f',
        timestamp: 1789455600,
      ),
    ],
  );
}

class _FakePatchDetailRepository implements PatchDetailRepository {
  @override
  Future<PatchDetail> loadPatchDetail(String patchNumber) async {
    return const PatchDetail(
      schemaVersion: 1,
      locale: 'english',
      patchNumber: '7.41f',
      patchName: '7.41f',
      timestamp: 1789455600,
      sections: [
        PatchSection(
          title: 'Heroes',
          groups: [
            PatchChangeGroup(
              title: 'Anti-Mage',
              heroId: 1,
              iconUrl: 'https://cdn.example.com/antimage.png',
              lines: [
                PatchChangeLine(
                  text: 'Base armor increased by 1',
                  indentLevel: 1,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  Finder navLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  Future<void> pumpSmokeApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portraitBuilderProvider.overrideWithValue(
            (context, hero) =>
                SizedBox(key: ValueKey<String>(hero.portraitUrl)),
          ),
          itemIconBuilderProvider.overrideWithValue(
            (context, url, name) => SizedBox(key: ValueKey<String>(url)),
          ),
          heroesRepositoryProvider.overrideWithValue(_FakeHeroesRepository()),
          heroDetailRepositoryProvider.overrideWithValue(
            _FakeHeroDetailRepository(),
          ),
          itemsRepositoryProvider.overrideWithValue(_FakeItemsRepository()),
          itemDetailRepositoryProvider.overrideWithValue(
            _FakeItemDetailRepository(),
          ),
          patchesRepositoryProvider.overrideWithValue(_FakePatchesRepository()),
          patchDetailRepositoryProvider.overrideWithValue(
            _FakePatchDetailRepository(),
          ),
          newsRepositoryProvider.overrideWithValue(_FakeNewsRepository()),
          ...refreshSeamOverrides(),
        ],
        child: const AegisApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'end-to-end smoke: all four tabs and About render and navigate over fakes',
    (WidgetTester tester) async {
      await pumpSmokeApp(tester);

      // 1. Initial Launch: Home Tab
      expect(find.text('Aegis Codex'), findsOneWidget);
      expect(find.text('Latest Patch'), findsOneWidget);
      expect(find.text('VALVE NEWS'), findsOneWidget);

      // --- Home -> About -> Back ---
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About & sources'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Unofficial — not affiliated with Valve Corporation',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Valve datafeeds'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Aegis Codex'), findsOneWidget);

      // --- Home -> Latest Patch card -> Patch Detail -> Back ---
      await tester.tap(find.text('Latest Patch'));
      await tester.pumpAndSettle();

      expect(find.text('Patch 7.41f'), findsOneWidget);
      expect(find.text('Anti-Mage'), findsOneWidget);

      // Back returns to Patches tab
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Latest Patch'), findsOneWidget);

      // Return to Home tab
      await tester.tap(navLabel('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Aegis Codex'), findsOneWidget);

      // --- Home -> Quick entry Heroes -> Heroes Tab ---
      await tester.tap(find.text('Heroes').first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Anti-Mage'), findsOneWidget);

      // --- Heroes -> Hero Detail -> Back ---
      await tester.tap(find.text('Anti-Mage'));
      await tester.pumpAndSettle();

      expect(find.text('Mana Break'), findsOneWidget);
      expect(find.text('Attributes'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // --- Bottom Nav -> Items Tab ---
      await tester.tap(navLabel('Items'));
      await tester.pumpAndSettle();

      expect(find.text("Eul's Scepter of Divinity"), findsOneWidget);

      // --- Items -> Item Detail -> Recipe Component Detail -> Back -> Back ---
      await tester.tap(find.text("Eul's Scepter of Divinity"));
      await tester.pumpAndSettle();

      expect(find.text('2600 gold'), findsOneWidget);
      expect(find.text('Cyclone'), findsOneWidget);
      expect(find.text('Recipe'), findsOneWidget);

      // Tap component "Staff of Wizardry" inside Recipe Tree
      await tester.tap(find.text('Staff of Wizardry'));
      await tester.pumpAndSettle();

      expect(find.text('1000 gold'), findsOneWidget);
      expect(find.text('A staff of power.'), findsOneWidget);

      // Pop component
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Cyclone'), findsOneWidget);

      // Pop item detail
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      // --- Bottom Nav -> Patches Tab ---
      await tester.tap(navLabel('Patches'));
      await tester.pumpAndSettle();

      expect(find.text('Latest Patch'), findsOneWidget);
      expect(find.text('7.41f'), findsWidgets);

      // Open Patch Detail from Patches tab
      await tester.tap(find.text('7.41f').first);
      await tester.pumpAndSettle();

      expect(find.text('Patch 7.41f'), findsOneWidget);
      expect(find.text('Anti-Mage'), findsOneWidget);

      // Tap Anti-Mage entity header to open Hero Detail
      await tester.tap(find.text('Anti-Mage'));
      await tester.pumpAndSettle();

      expect(find.text('Mana Break'), findsOneWidget);

      // Pop hero detail back to patch detail
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Patch 7.41f'), findsOneWidget);

      // Pop patch detail back to patches list
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Latest Patch'), findsOneWidget);

      // --- Bottom Nav -> Home Tab ---
      await tester.tap(navLabel('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Aegis Codex'), findsOneWidget);
    },
  );
}
