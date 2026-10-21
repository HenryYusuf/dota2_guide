import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_detail_repository.dart';
import 'package:dota2_guide/features/patches/patch_detail_screen.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';

class _FakePatchDetailRepository implements PatchDetailRepository {
  _FakePatchDetailRepository({
    this.details = const {},
    this.shouldFail = false,
  });

  final Map<String, PatchDetail> details;
  bool shouldFail;
  int loadCalls = 0;

  @override
  Future<PatchDetail> loadPatchDetail(String patchNumber) async {
    loadCalls++;
    if (shouldFail) {
      throw Exception('Network unreachable');
    }
    final detail = details[patchNumber];
    if (detail == null) throw Exception('Patch $patchNumber not found');
    return detail;
  }
}

void main() {
  final sampleDetail = PatchDetail(
    schemaVersion: 1,
    locale: 'english',
    patchNumber: '7.41f',
    patchName: '7.41f',
    timestamp: 1789455600,
    sections: [
      PatchSection(
        title: 'General',
        groups: [
          PatchChangeGroup(
            title: 'General Changes',
            lines: [
              PatchChangeLine(
                text: 'Courier respawn time decreased',
                indentLevel: 1,
              ),
            ],
          ),
        ],
      ),
      PatchSection(
        title: 'Items',
        groups: [
          PatchChangeGroup(
            title: 'Infused Raindrops',
            itemId: 265,
            iconUrl: 'https://cdn.steamstatic.com/infused_raindrop.png',
            lines: [
              PatchChangeLine(
                text: 'Mana Regen bonus decreased from +0.8 to +0.6',
                indentLevel: 1,
              ),
            ],
          ),
        ],
      ),
      PatchSection(
        title: 'Heroes',
        groups: [
          PatchChangeGroup(
            title: 'Anti-Mage',
            heroId: 1,
            iconUrl: 'https://cdn.steamstatic.com/antimage.png',
            lines: [
              PatchChangeLine(
                text: 'Base Armor decreased by 1',
                indentLevel: 1,
              ),
              PatchChangeLine(
                text: 'Mana Burned as Damage increased from 60% to 65%',
                indentLevel: 1,
              ),
              PatchChangeLine(
                text: 'Aghanim Scepter bonus increased',
                indentLevel: 2,
                badge: 'scepter',
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Widget createSubject({
    required PatchDetailRepository repo,
    String patchNumber = '7.41f',
  }) {
    final router = GoRouter(
      initialLocation: PatchDetailScreen.location(patchNumber),
      routes: [
        GoRoute(
          path: '/patches/:patchNumber',
          builder: (context, state) => PatchDetailScreen(
            patchNumber: state.pathParameters['patchNumber']!,
          ),
        ),
        GoRoute(
          path: '/heroes/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Hero page: ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/items/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Item page: ${state.pathParameters['id']}')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        patchDetailRepositoryProvider.overrideWithValue(repo),
        // Stubs for icons so no HTTP / CDN is used
        patchHeroIconBuilderProvider.overrideWithValue(
          (context, url, name) => Container(
            key: ValueKey('hero_icon_$name'),
            color: Colors.blue,
            width: 48,
            height: 27,
          ),
        ),
        patchItemIconBuilderProvider.overrideWithValue(
          (context, url, name) => Container(
            key: ValueKey('item_icon_$name'),
            color: Colors.green,
            width: 36,
            height: 27,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'renders sections, entity headers with icons/names, and indented lines with badges',
    (tester) async {
      final repo = _FakePatchDetailRepository(details: {'7.41f': sampleDetail});

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // Section headers
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('ITEMS'), findsOneWidget);
      expect(find.text('HEROES'), findsOneWidget);

      // Group titles
      expect(find.text('General Changes'), findsOneWidget);
      expect(find.text('Infused Raindrops'), findsOneWidget);
      expect(find.text('Anti-Mage'), findsOneWidget);

      // Entity icons
      expect(
        find.byKey(const ValueKey('item_icon_Infused Raindrops')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hero_icon_Anti-Mage')), findsOneWidget);

      // Change lines
      expect(find.text('Courier respawn time decreased'), findsOneWidget);
      expect(
        find.text('Mana Regen bonus decreased from +0.8 to +0.6'),
        findsOneWidget,
      );
      expect(find.text('Base Armor decreased by 1'), findsOneWidget);
      expect(find.text('Aghanim Scepter bonus increased'), findsOneWidget);

      // Badge
      expect(find.text('Scepter'), findsOneWidget);
    },
  );

  testWidgets('tapping Hero icon navigates to HeroDetailScreen', (
    tester,
  ) async {
    final repo = _FakePatchDetailRepository(details: {'7.41f': sampleDetail});

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hero_icon_Anti-Mage')));
    await tester.pumpAndSettle();

    expect(find.text('Hero page: 1'), findsOneWidget);
  });

  testWidgets('tapping Item icon navigates to ItemDetailScreen', (
    tester,
  ) async {
    final repo = _FakePatchDetailRepository(details: {'7.41f': sampleDetail});

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('item_icon_Infused Raindrops')));
    await tester.pumpAndSettle();

    expect(find.text('Item page: 265'), findsOneWidget);
  });

  testWidgets(
    'failed fetch shows inline retry (not full-screen error) and retry reloads',
    (tester) async {
      final repo = _FakePatchDetailRepository(
        details: {'7.41f': sampleDetail},
        shouldFail: true,
      );

      await tester.pumpWidget(createSubject(repo: repo));
      await tester.pumpAndSettle();

      // AppBar is still visible (never a full-screen white error or crash)
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Patch 7.41f'), findsOneWidget);

      // Inline retry card
      expect(find.text("Couldn't load Patch 7.41f"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now make repo succeed and tap Retry
      repo.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Succeeded!
      expect(find.text('Anti-Mage'), findsOneWidget);
      expect(find.text("Couldn't load Patch 7.41f"), findsNothing);
    },
  );
}
