// Smoke tests for the app shell: dark-only theme, the four bottom tabs, and
// state preservation across tab switches. These establish the walking-skeleton
// contract that later feature work builds on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AegisApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('app launches to the Home tab with the shell in place', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Home'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Heroes'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Items'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Patches'),
      ),
      findsOneWidget,
    );
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
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      await expectSelected(label);
      // The selected tab's screen is the one on screen.
      expect(find.text('$label tab'), findsWidgets);
    }
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
    expect(scrollable.position.pixels, greaterThan(0));

    // Switch away and back.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Heroes'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();

    final restored = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(restored.position.pixels, greaterThan(0));
  });
}
