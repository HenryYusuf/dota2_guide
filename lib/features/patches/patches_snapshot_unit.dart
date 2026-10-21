import 'dart:convert';

import '../../core/data/datafeed_client.dart';
import '../../core/data/snapshot_refresher.dart';
import 'patch_feed_to_index.dart';
import 'patches_repository.dart';

/// The Patch index snapshot unit registered with the refresher.
const SnapshotUnit patchesSnapshotUnit = SnapshotUnit(
  fetch: _fetchPatchesIndex,
);

Future<Map<String, String>> _fetchPatchesIndex(DatafeedClient feed) async {
  final patchnoteslist = await feed.fetchJson(
    '$datafeedBaseUrl/patchnoteslist?language=english',
  );
  return {
    patchIndexUnit: jsonEncode(
      patchIndexFromFeed(patchnoteslist, locale: 'english'),
    ),
  };
}
