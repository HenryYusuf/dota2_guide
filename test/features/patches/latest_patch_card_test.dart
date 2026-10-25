import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/core/theme/app_theme.dart';
import 'package:dota2_guide/features/patches/latest_patch_card.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';

void main() {
  const testPatch = PatchSummary(
    patchNumber: '7.41f',
    patchName: 'Gameplay Update 7.41f',
    timestamp: 1729000000,
  );

  testWidgets('renders LatestPatchCard and responds to taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: LatestPatchCard(patch: testPatch, onTap: () => tapped = true),
        ),
      ),
    );

    // Verify badge
    expect(find.text('Latest Patch'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);

    // Verify title with formatted date
    expect(find.textContaining('7.41f'), findsWidgets);

    // Verify tap
    await tester.tap(find.byType(LatestPatchCard));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
