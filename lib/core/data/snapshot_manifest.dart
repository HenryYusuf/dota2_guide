/// Override manifest: the record governing every snapshot read (spec:
/// persistence is "a file-override directory … governed by a manifest
/// recording data version and fetch time").
///
/// A manifest exists only after a successful refresh attempt; its absence
/// means "use the bundled snapshot". Parsing is strict — an unreadable
/// manifest degrades to asset fallback, never to a crash.
library;

/// Current schema version of the written manifest file.
const int snapshotManifestSchemaVersion = 1;

class SnapshotManifest {
  const SnapshotManifest({required this.dataVersion, required this.fetchedAt});

  factory SnapshotManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion != snapshotManifestSchemaVersion) {
      throw FormatException(
        'Unsupported manifest schema_version $schemaVersion '
        '(app expects $snapshotManifestSchemaVersion)',
      );
    }
    final rawVersion = json['data_version'];
    if (rawVersion != null && rawVersion is! int) {
      throw const FormatException('Manifest: "data_version" not an int');
    }
    final rawFetchedAt = json['fetched_at'];
    if (rawFetchedAt is! String) {
      throw const FormatException(
        'Manifest: "fetched_at" missing or not a string',
      );
    }
    final fetchedAt = DateTime.tryParse(rawFetchedAt);
    if (fetchedAt == null) {
      throw FormatException(
        'Manifest: "fetched_at" unparseable: $rawFetchedAt',
      );
    }
    return SnapshotManifest(dataVersion: rawVersion, fetchedAt: fetchedAt);
  }

  /// Valve feed `data_version` recorded at fetch time, or null when the feed
  /// served no version (observed live 2026-10-21: the meta block comes and
  /// goes — a null version means "can never match, always refetch on probe").
  final int? dataVersion;

  /// When the refresh attempt that wrote this manifest completed (UTC).
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
    'schema_version': snapshotManifestSchemaVersion,
    'data_version': dataVersion,
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
  };
}
