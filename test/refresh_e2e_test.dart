// End-to-end refresh demonstration (issue 03): the REAL app — real router,
// real screen, real repository, real override store, real refresher, real
// refresh trigger — over a fake feed and an in-memory file store (the only
// seams widget tests may touch: no HTTP, no dart:io, no CDN).
//
// The story: cold start commits the feed's v1 roster; Valve ships v2; the
// next foreground resume probes, sees the version bump, refetches, and the
// Heroes roster updates live — no restart, no error UI, no crash.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/app.dart';
import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/core/data/file_store.dart';
import 'package:dota2_guide/core/data/snapshot_refresher.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/heroes/heroes_providers.dart';
import 'package:dota2_guide/features/heroes/heroes_snapshot_unit.dart';
import 'package:dota2_guide/features/heroes/heroes_screen.dart';

import 'core/data/fake_datafeed_client.dart';
import 'core/data/in_memory_file_store.dart';

/// A herolist feed document with one hero per name — the exact shape
/// `heroesSnapshotUnit` converts (verified live 2026-10-20).
Map<String, Object?> _herolist(List<String> names) => {
  'result': {
    'data': {
      'heroes': [
        for (var i = 0; i < names.length; i++)
          {
            'id': i + 1,
            'name':
                'npc_dota_hero_${names[i].toLowerCase().replaceAll(' ', '_')}',
            'name_loc': names[i],
            'primary_attr': 1,
            'complexity': 1,
          },
      ],
    },
  },
};

Widget _stubPortrait(BuildContext context, HeroSummary hero) =>
    SizedBox(key: ValueKey<String>(hero.portraitUrl));

void main() {
  testWidgets(
    'after a data-version bump, the Heroes roster shows the refreshed data',
    (tester) async {
      final files = InMemoryFileStore();
      final feed = FakeDatafeedClient()
        ..version = 1
        ..documents[heroListFeedUrl] = _herolist(['Original Hero']);

      // Controllable clock: the 24h TTL would otherwise hide the version
      // bump behind a real day.
      var now = DateTime.utc(2026, 10, 21, 8);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            portraitBuilderProvider.overrideWithValue(_stubPortrait),
            fileStoreProvider.overrideWithValue(files),
            datafeedClientProvider.overrideWithValue(feed),
            snapshotUnitsProvider.overrideWithValue(const [heroesSnapshotUnit]),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const AegisApp(),
        ),
      );
      // Cold start: the trigger probes (no manifest → fetch) and commits v1.
      await tester.pumpAndSettle();

      Finder navLabel(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

      await tester.tap(navLabel('Heroes'));
      await tester.pumpAndSettle();
      expect(find.text('Original Hero'), findsOneWidget);

      // Valve ships v2 and a day passes; the app comes back to the
      // foreground — the trigger probes, sees the bump, refetches, commits,
      // bumps the refresh epoch, and the roster re-reads.
      feed
        ..version = 2
        ..documents[heroListFeedUrl] = _herolist(['Refreshed Hero']);
      now = now.add(const Duration(hours: 25));
      // Legal lifecycle chain for a foreground resume (Flutter's state
      // machine: paused → hidden → inactive → resumed).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Refreshed Hero'), findsOneWidget);
      expect(find.text('Original Hero'), findsNothing);
      expect(find.byType(HeroesScreen), findsOneWidget);
      expect(feed.probeCalls, 2); // once per day, never more
    },
  );
}
