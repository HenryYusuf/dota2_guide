import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:dota2_guide/features/about/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(SnapshotManifest? manifest) => ProviderScope(
  overrides: [snapshotManifestProvider.overrideWith((ref) async => manifest)],
  child: const MaterialApp(home: AboutScreen()),
);

void main() {
  testWidgets('shows disclaimer, attributions and last-updated from manifest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        SnapshotManifest(
          dataVersion: 1,
          fetchedAt: DateTime.utc(2026, 10, 21, 9, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Unofficial — not affiliated with Valve Corporation'),
      findsOneWidget,
    );
    expect(find.textContaining('Valve datafeeds'), findsOneWidget);
    expect(find.textContaining('Steam CDN'), findsOneWidget);
    expect(find.textContaining('Steam news feed'), findsOneWidget);
    expect(
      find.textContaining('OpenDota public match aggregates'),
      findsOneWidget,
    );

    final lastUpdatedFinder = find.text('Last updated: 2026-10-21');
    await tester.scrollUntilVisible(lastUpdatedFinder, 100);
    expect(lastUpdatedFinder, findsOneWidget);
  });

  testWidgets('falls back to bundled snapshot when no manifest exists', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(null));
    await tester.pumpAndSettle();

    final lastUpdatedFinder = find.text('Last updated: bundled snapshot');
    await tester.scrollUntilVisible(lastUpdatedFinder, 100);
    expect(lastUpdatedFinder, findsOneWidget);
  });
}
