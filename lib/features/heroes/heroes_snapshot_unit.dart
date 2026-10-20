// The Heroes feature's refresh unit: fetches the live herolist feed and
// emits the same app-schema index the snapshot tool bundles (one converter,
// `hero_feed_to_index.dart`), so the override is a fresher copy of the
// asset — nothing downstream changes.
//
// v1 is English-only (per spec): the unit reads the English feed and stores
// it under the same unit name as the bundled asset's base name.

import 'dart:convert';

import '../../core/data/datafeed_client.dart';
import '../../core/data/snapshot_refresher.dart';
import 'hero_feed_to_index.dart';
import 'heroes_repository.dart';

/// Feed → app-schema builder registered with the refresher. Reads the same
/// herolist URL the probe already fetches (one URL, two consumers).
const SnapshotUnit heroesSnapshotUnit = SnapshotUnit(
  name: heroIndexUnit,
  fetch: _fetchHeroesIndex,
);

Future<String> _fetchHeroesIndex(DatafeedClient feed) async {
  final herolist = await feed.fetchJson(heroListFeedUrl);
  return jsonEncode(heroIndexFromFeed(herolist, locale: 'english'));
}
