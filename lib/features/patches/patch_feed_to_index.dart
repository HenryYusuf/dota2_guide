// Valve patchnoteslist feed → app-schema patch index.
//
// Converts the raw feed (`patches[]`) into app schema sorted latest-first.

import 'patch_index.dart';

Map<String, Object?> patchIndexFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
}) {
  final rawPatches = feed['patches'];
  if (rawPatches is! List) {
    throw const FormatException('Feed response has no "patches" list');
  }

  final patchList = <Map<String, Object?>>[];
  for (final raw in rawPatches) {
    if (raw is! Map<String, dynamic>) continue;
    final patchNumber = raw['patch_number']?.toString();
    final patchName = raw['patch_name']?.toString() ?? patchNumber;
    final timestamp = raw['patch_timestamp'];
    final ts = timestamp is num ? timestamp.toInt() : null;

    if (patchNumber != null && ts != null) {
      patchList.add({
        'patch_number': patchNumber,
        'patch_name': patchName ?? patchNumber,
        'timestamp': ts,
      });
    }
  }

  // Sort descending by timestamp so latest patch is first.
  patchList.sort(
    (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
  );

  return {
    'schema_version': patchIndexSchemaVersion,
    'locale': locale,
    'patches': patchList,
  };
}
