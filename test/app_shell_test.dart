// Smoke tests for the app shell: dark-only theme, the four bottom tabs, and
// state preservation across tab switches. These establish the walking-skeleton
// contract that later feature work builds on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/items/items_providers.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';

import 'core/data/refresh_seam_overrides.dart';

/// In-memory roster for shell tests: these cover navigation, theme, and
/// scroll-state preservation — not data loading (spec: widget tests render
/// over in-memory fake repositories). The real bundled-asset read path is
/// owned by `heroes_screen_test.dart` and the repository tests.
///
/// Loading the real asset here would also hang: flutter_test's fake-async
/// zone never completes a `rootBundle` load after the first one in an
/// isolate, so any later widget test touching the bundle deadlocks.
class _FakeHeroesRepository implements HeroesRepository {
  @override
  Future<List<HeroSummary>> loadHeroes() async => const [];
}

class _FakeItemsRepository implements ItemsRepository {
  @override
  Future<ItemIndex> loadItems() async =>
      const ItemIndex(schemaVersion: 1, locale: 'english', items: []);
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

void main() {
  /// Finds a bottom-navigation destination label by its visible text.
  Finder navLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    // Portraits stream from the Valve CDN (ADR-0001); the shell tests care
    // about navigation and theme, so the CDN layer is stubbed — no widget
    // test touches HTTP (spec: widget tests render over fakes). The refresh
    // trigger also runs on cold start, so its feed and storage seams are
    // stubbed the same way (probe fails → silent no-op by design).
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
          itemsRepositoryProvider.overrideWithValue(_FakeItemsRepository()),
          patchesRepositoryProvider.overrideWithValue(_FakePatchesRepository()),
          ...refreshSeamOverrides(),
        ],
        child: const AegisApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('app launches to the Home tab with the shell in place', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Home'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(navLabel('Heroes'), findsOneWidget);
    expect(navLabel('Items'), findsOneWidget);
    expect(navLabel('Patches'), findsOneWidget);
  });

  testWidgets('theme is dark-only regardless of platform brightness', (
    WidgetTester tester,
  ) async {
    // Simulate the platform being in light mode; the app must still render
    // dark, since it ships no light theme.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme?.brightness, Brightness.dark);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('bottom nav switches between all four tabs', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    const tabLabels = ['Home', 'Heroes', 'Items', 'Patches'];

    Future<void> expectSelected(String label) async {
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        navBar.selectedIndex,
        tabLabels.indexOf(label),
        reason: '$label should be the selected tab',
      );
    }

    await expectSelected('Home');

    for (final label in ['Heroes', 'Items', 'Patches', 'Home']) {
      await tester.tap(navLabel(label));
      await tester.pumpAndSettle();
      await expectSelected(label);
      // The selected tab's screen is the one on screen. The Heroes, Items,
      // and Patches tabs are no longer placeholders (issues 02, 06 & 08) —
      // Heroes and Items carry the search field, Patches carries the pinned
      // latest patch card.
      if (label == 'Heroes' || label == 'Items') {
        expect(find.byType(TextField), findsOneWidget);
      } else if (label == 'Patches') {
        expect(find.text('Latest Patch'), findsOneWidget);
      } else {
        expect(find.text('$label tab'), findsWidgets);
      }
    }
  });

  testWidgets('About opens from the Home top-bar menu', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About & sources'));
    await tester.pumpAndSettle();

    expect(find.text('About tab'), findsOneWidget);
  });

  testWidgets('scroll state is preserved when switching tabs', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Home's placeholder list is long enough to scroll.
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final savedOffset = scrollable.position.pixels;
    expect(savedOffset, greaterThan(0));

    // Switch away and back.
    await tester.tap(navLabel('Heroes'));
    await tester.pumpAndSettle();
    await tester.tap(navLabel('Home'));
    await tester.pumpAndSettle();

    final restored = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(restored.position.pixels, savedOffset);
  });
}
