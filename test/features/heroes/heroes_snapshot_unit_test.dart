// The Heroes refresh units: feed → app-schema file builders for the roster
// index and every Hero's detail ("one converter, two writers" — the same
// `heroIndexFromFeed` / `heroDetailFromFeed` the snapshot tool bundles, so a
// refreshed override is byte-shape compatible with the bundled assets).
//
// Pins the fan-out contract: the detail unit reads the roster for ids,
// fetches one herodata document per Hero, and emits one
// `hero_<id>.english.json` file each — every emitted file must parse with
// the app's strict reader (schema drift fails here, not at render time).

import 'dart:convert';

import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:dota2_guide/features/heroes/heroes_snapshot_unit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/fake_datafeed_client.dart';
import 'synthetic_herodata_feed.dart';

/// The herolist feed: the roster the units derive ids from (same shape the
/// index converter and the refresh e2e test use).
Map<String, dynamic> _herolist(List<Map<String, Object?>> heroes) => {
  'result': {
    'status': 1,
    'meta': {'data_version': 42},
    'data': {'heroes': heroes},
  },
};

Map<String, Object?> _rosterHero(int id, String valveKey, String nameLoc) => {
  'id': id,
  'name': valveKey,
  'order_id': id,
  'name_loc': nameLoc,
  'name_english_loc': nameLoc,
  'primary_attr': 1,
  'complexity': 1,
};

/// A herodata document for [id], in the feed's envelope.
Map<String, dynamic> _herodata(Map<String, Object?> hero) => feedDocument(hero);

/// Decodes an emitted file the way the repository does before parsing it.
HeroDetail _parse(String file) =>
    HeroDetail.fromJson(jsonDecode(file) as Map<String, dynamic>);

void main() {
  late FakeDatafeedClient feed;

  setUp(() => feed = FakeDatafeedClient());

  test('the index unit emits the roster under the bundled unit name', () async {
    feed.documents[heroListFeedUrl] = _herolist([
      _rosterHero(1, 'npc_dota_hero_antimage', 'Anti-Mage'),
    ]);

    final files = await heroesSnapshotUnit.fetch(feed);

    expect(files.keys, [heroIndexUnit]);
    expect(files[heroIndexUnit], contains('"Anti-Mage"'));
  });

  test('the detail unit emits one parseable file per roster Hero', () async {
    feed.documents[heroListFeedUrl] = _herolist([
      _rosterHero(1, 'npc_dota_hero_antimage', 'Anti-Mage'),
      _rosterHero(2, 'npc_dota_hero_axe', 'Axe'),
    ]);
    feed.documents[heroDataFeedUrl(1)] = _herodata(heroFeed());
    feed.documents[heroDataFeedUrl(2)] = _herodata(
      heroFeed()
        ..['id'] = 2
        ..['name'] = 'npc_dota_hero_axe'
        ..['name_loc'] = 'Axe',
    );

    final files = await heroDetailSnapshotUnit.fetch(feed);

    expect(
      files.keys,
      unorderedEquals([heroDetailUnitName(1), heroDetailUnitName(2)]),
    );

    // Every emitted file parses with the app's strict reader — the same
    // contract the bundled assets have to keep.
    final antiMage = _parse(files[heroDetailUnitName(1)]!);
    expect(antiMage.hero.id, 1);
    expect(antiMage.hero.localizedName, 'Anti-Mage');
    expect(antiMage.talents, hasLength(8));
    expect(antiMage.abilities, isNotEmpty);

    final axe = _parse(files[heroDetailUnitName(2)]!);
    expect(axe.hero.id, 2);
    expect(axe.hero.localizedName, 'Axe');
    expect(axe.hero.valveKey, 'npc_dota_hero_axe');
  });

  test(
    'one Hero\'s feed failure fails the whole unit (no partial commit)',
    () async {
      feed.documents[heroListFeedUrl] = _herolist([
        _rosterHero(1, 'npc_dota_hero_antimage', 'Anti-Mage'),
        _rosterHero(2, 'npc_dota_hero_axe', 'Axe'),
      ]);
      feed.documents[heroDataFeedUrl(1)] = _herodata(heroFeed());
      // Hero 2 has no canned document — fetchJson throws, like a dead feed.
      // The refresher commits nothing when a unit throws, so a partial
      // roster's details never land.

      await expectLater(
        heroDetailSnapshotUnit.fetch(feed),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('the fan-out hits each Hero\'s herodata URL exactly once', () async {
    feed.documents[heroListFeedUrl] = _herolist([
      _rosterHero(1, 'npc_dota_hero_antimage', 'Anti-Mage'),
      _rosterHero(2, 'npc_dota_hero_axe', 'Axe'),
    ]);
    feed.documents[heroDataFeedUrl(1)] = _herodata(heroFeed());
    feed.documents[heroDataFeedUrl(2)] = _herodata(
      heroFeed()
        ..['id'] = 2
        ..['name'] = 'npc_dota_hero_axe',
    );

    await heroDetailSnapshotUnit.fetch(feed);

    // Roster read + one herodata per Hero: no retries, no double fetches.
    expect(feed.fetchCalls, 3);
  });
}
