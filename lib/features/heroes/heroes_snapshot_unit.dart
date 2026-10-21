// The Heroes feature's refresh units: feed → app-schema file builders for
// the roster index and every Hero's detail page, emitting the same schema
// the snapshot tool bundles (one converter pair: `hero_feed_to_index.dart`,
// `hero_feed_to_detail.dart`), so an override is a fresher copy of the
// asset — nothing downstream changes.
//
// v1 is English-only (per spec): the units read the English feed and store
// under the same unit names as the bundled assets' base names.

import 'dart:convert';

import '../../core/data/concurrent_map.dart';
import '../../core/data/datafeed_client.dart';
import '../../core/data/snapshot_refresher.dart';
import 'hero_detail.dart';
import 'hero_feed_to_detail.dart';
import 'hero_feed_to_index.dart';
import 'heroes_repository.dart';

/// The roster index, registered with the refresher. Reads the same herolist
/// URL the probe already fetches (one URL, three consumers: probe, index,
/// detail-id lookup).
const SnapshotUnit heroesSnapshotUnit = SnapshotUnit(fetch: _fetchHeroesIndex);

/// One detail file per Hero (`hero_<id>.english.json`), converted with the
/// same `heroDetailFromFeed` the snapshot tool uses. Fan-out budget is
/// [heroDetailFetchConcurrency]; a failure in any Hero's fetch throws and the
/// whole refresh cycle commits nothing (stale data preserved).
const SnapshotUnit heroDetailSnapshotUnit = SnapshotUnit(
  fetch: _fetchHeroDetails,
);

Future<Map<String, String>> _fetchHeroesIndex(DatafeedClient feed) async {
  final herolist = await feed.fetchJson(heroListFeedUrl);
  return {
    heroIndexUnit: jsonEncode(heroIndexFromFeed(herolist, locale: 'english')),
  };
}

Future<Map<String, String>> _fetchHeroDetails(DatafeedClient feed) async {
  final herolist = await feed.fetchJson(heroListFeedUrl);
  final index = heroIndexFromFeed(herolist, locale: 'english');
  final heroes = (index['heroes']! as List).cast<Map<String, Object?>>();

  final files = await mapConcurrently(heroes, heroDetailFetchConcurrency, (
    hero,
  ) async {
    final heroId = hero['id']! as int;
    final detailFeed = await feed.fetchJson(heroDataFeedUrl(heroId));
    final detail = heroDetailFromFeed(detailFeed, locale: 'english');
    return MapEntry(heroDetailUnitName(heroId), jsonEncode(detail));
  });
  return Map.fromEntries(files);
}
