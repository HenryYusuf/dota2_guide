// SnapshotRefresher: the refresh policy (spec: "refresh on cold
// start/foreground with a 24h TTL; the probe is never more than once a day;
// full refetch only when the probed data version differs from the
// manifest's; network/parse failures are silent — stale data preserved").
//
// The refresher is feature-generic: features contribute [SnapshotUnit]s
// (feed → app-schema file builders) so tickets 04/06/08 add units without
// touching core.

import 'dart:convert';

import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_refresher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_datafeed_client.dart';
import 'in_memory_file_store.dart';

void main() {
  const unitUrl = 'feed://roster';
  final rosterUnit = SnapshotUnit(
    fetch: (feed) async => {
      'heroes.english.json': jsonEncode(await feed.fetchJson(unitUrl)),
    },
  );

  final t0 = DateTime.utc(2026, 10, 21, 8);

  late FakeDatafeedClient feed;
  late InMemoryFileStore files;
  late OverrideStore store;
  late DateTime now;

  SnapshotRefresher refresher() => SnapshotRefresher(
    feed: feed,
    units: [rosterUnit],
    overrides: store,
    clock: () => now,
  );

  Map<String, Object?> roster(String heroName) => {
    'result': {
      'data': {
        'heroes': [
          {'name_loc': heroName},
        ],
      },
    },
  };

  setUp(() {
    feed = FakeDatafeedClient();
    files = InMemoryFileStore();
    store = OverrideStore(files);
    now = t0;
  });

  group('probe TTL — the feed is checked at most once a day', () {
    test('within TTL: no probe, no refetch, nothing committed', () async {
      feed.version = 1;
      feed.documents[unitUrl] = roster('First');
      expect(await refresher().refresh(), isTrue); // cold start commits v1

      now = t0.add(const Duration(hours: 23));
      feed.version = 2;
      feed.documents[unitUrl] = roster('Second');

      expect(await refresher().refresh(), isFalse);
      expect(feed.probeCalls, 1);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });

    test('expired TTL: probes again', () async {
      feed.version = 1;
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.version = 2;
      feed.documents[unitUrl] = roster('Second');

      expect(await refresher().refresh(), isTrue);
      expect(feed.probeCalls, 2);
      expect(await store.readOrNull('heroes.english.json'), contains('Second'));
    });

    test('a failed probe still spends the day\'s budget', () async {
      feed.failProbe = true;

      expect(await refresher().refresh(), isFalse);
      expect(feed.probeCalls, 1);

      // Feed recovers within the hour — the TTL still gates the next probe.
      feed.failProbe = false;
      feed.version = 1;
      feed.documents[unitUrl] = roster('First');
      now = t0.add(const Duration(hours: 1));

      expect(await refresher().refresh(), isFalse);
      expect(feed.probeCalls, 1);
    });

    test(
      'a backward clock jump re-probes instead of blocking forever',
      () async {
        feed.version = 1;
        feed.documents[unitUrl] = roster('First');
        await refresher().refresh();

        // Device clock corrected backwards (e.g. NTP): lastProbe now sits in
        // the "future". Treating that as within-TTL would block probing until
        // wall-clock catches up — treat it as expired instead.
        now = t0.subtract(const Duration(hours: 2));
        feed.version = 2;
        feed.documents[unitUrl] = roster('Second');

        expect(await refresher().refresh(), isTrue);
        expect(feed.probeCalls, 2);
        expect(
          await store.readOrNull('heroes.english.json'),
          contains('Second'),
        );
      },
    );
  });

  group('version gate — refetch only when the version moved', () {
    test('first refresh (no manifest) fetches and commits', () async {
      feed.version = 7;
      feed.documents[unitUrl] = roster('First');

      expect(await refresher().refresh(), isTrue);

      final manifest = await store.readManifest();
      expect(manifest?.dataVersion, 7);
      expect(manifest?.fetchedAt, t0);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });

    test('unchanged version: probes but fetches nothing', () async {
      feed.version = 7;
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.documents[unitUrl] = roster('ShouldNotLand');

      expect(await refresher().refresh(), isFalse);
      expect(feed.probeCalls, 2);
      expect(feed.fetchCalls, 1); // only the first refresh fetched
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });

    test('version bump: full refetch and commit', () async {
      feed.version = 7;
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.version = 8;
      feed.documents[unitUrl] = roster('Second');

      expect(await refresher().refresh(), isTrue);
      expect(await store.readManifest(), isNotNull);
      expect((await store.readManifest())?.dataVersion, 8);
      expect(await store.readOrNull('heroes.english.json'), contains('Second'));
    });

    test('one unit may commit many files in a single cycle', () async {
      // The Heroes detail unit emits one file per Hero; every name the unit
      // returns must land in the same atomic commit.
      final multiUnit = SnapshotUnit(
        fetch: (feed) async => {
          'hero_1.english.json': '{"id":1}',
          'hero_2.english.json': '{"id":2}',
        },
      );
      feed.version = 3;
      feed.documents[unitUrl] = roster('First');
      final multi = SnapshotRefresher(
        feed: feed,
        units: [rosterUnit, multiUnit],
        overrides: store,
        clock: () => now,
      );

      expect(await multi.refresh(), isTrue);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
      expect(await store.readOrNull('hero_1.english.json'), '{"id":1}');
      expect(await store.readOrNull('hero_2.english.json'), '{"id":2}');
    });

    test('feed serves no version: always refetch on probe', () async {
      feed.version = null; // observed live: the meta block comes and goes
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.documents[unitUrl] = roster('Second');

      expect(await refresher().refresh(), isTrue);
      expect(await store.readOrNull('heroes.english.json'), contains('Second'));
    });
  });

  group('silent failure — stale data beats an error dialog', () {
    test('probe failure: no crash, previous data intact', () async {
      feed.version = 1;
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.failProbe = true;

      expect(await refresher().refresh(), isFalse);
      expect((await store.readManifest())?.dataVersion, 1);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });

    test('fetch failure mid-refresh: previous data fully intact', () async {
      feed.version = 1;
      feed.documents[unitUrl] = roster('First');
      await refresher().refresh();

      now = t0.add(const Duration(hours: 25));
      feed.version = 2;
      feed.failFetch = true;

      expect(await refresher().refresh(), isFalse);
      expect((await store.readManifest())?.dataVersion, 1);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });

    test('probe failure with no manifest: silent, nothing written', () async {
      feed.failProbe = true;

      expect(await refresher().refresh(), isFalse);
      expect(await store.readManifest(), isNull);
    });

    test('feed-shape drift that throws an Error is silent too', () async {
      // Shape drift (a non-map element where the parser expects an object)
      // surfaces as a TypeError — an Error, not an Exception. The spec says
      // "no crash", so the refresher must swallow it and keep serving the
      // previous generation. The unit here parses strictly, like the real
      // `heroesSnapshotUnit` does via `heroIndexFromFeed`.
      SnapshotUnit strictUnit() => SnapshotUnit(
        fetch: (feed) async {
          final doc = await feed.fetchJson(unitUrl);
          final data = doc['result']! as Map<String, dynamic>;
          final heroes = data['heroes']! as List<dynamic>;
          // Throws TypeError on a non-map element.
          return {
            'heroes.english.json': jsonEncode(
              heroes.map((h) => (h as Map)['name_loc']).toList(),
            ),
          };
        },
      );

      feed.version = 1;
      feed.documents[unitUrl] = {
        'result': {
          'heroes': [
            {'name_loc': 'First'},
          ],
        },
      };
      final seed = SnapshotRefresher(
        feed: feed,
        units: [strictUnit()],
        overrides: store,
        clock: () => now,
      );
      expect(await seed.refresh(), isTrue);

      now = t0.add(const Duration(hours: 25));
      feed.version = 2;
      feed.documents[unitUrl] = {
        'result': {
          'heroes': ['not-a-map'],
        },
      };
      final drifted = SnapshotRefresher(
        feed: feed,
        units: [strictUnit()],
        overrides: store,
        clock: () => now,
      );

      expect(await drifted.refresh(), isFalse);
      expect((await store.readManifest())?.dataVersion, 1);
      expect(await store.readOrNull('heroes.english.json'), contains('First'));
    });
  });
}
