// Override-manifest model: the record that governs every snapshot read
// (issue 03: "governed by a manifest recording data version and fetch time").
// Parsing is strict — drift in a manifest written by an older app version must
// degrade to "no overrides" (asset fallback), never to a crash.

import 'package:dota2_guide/core/data/snapshot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fetchedAt = DateTime.utc(2026, 10, 21, 12, 30);

  test('round-trips data version and fetch timestamp', () {
    final manifest = SnapshotManifest(dataVersion: 7422, fetchedAt: fetchedAt);

    final parsed = SnapshotManifest.fromJson(manifest.toJson());

    expect(parsed.dataVersion, 7422);
    expect(parsed.fetchedAt, fetchedAt);
  });

  test('serializes the fetch timestamp as a UTC ISO-8601 string', () {
    final json = SnapshotManifest(
      dataVersion: 7422,
      fetchedAt: fetchedAt,
    ).toJson();

    expect(json['schema_version'], 1);
    expect(json['data_version'], 7422);
    expect(json['fetched_at'], '2026-10-21T12:30:00.000Z');
  });

  test('accepts a manifest with no data version yet', () {
    // Fresh install, or a feed that served no meta block: the fetch happened
    // but the feed carried no version to record.
    final manifest = SnapshotManifest(dataVersion: null, fetchedAt: fetchedAt);

    final parsed = SnapshotManifest.fromJson(manifest.toJson());

    expect(parsed.dataVersion, isNull);
    expect(parsed.fetchedAt, fetchedAt);
  });

  test('rejects an unknown schema version', () {
    final json = SnapshotManifest(
      dataVersion: 7422,
      fetchedAt: fetchedAt,
    ).toJson()..['schema_version'] = 2;

    expect(() => SnapshotManifest.fromJson(json), throwsFormatException);
  });

  test('rejects a missing or malformed fetch timestamp', () {
    final good = SnapshotManifest(
      dataVersion: 7422,
      fetchedAt: fetchedAt,
    ).toJson();

    expect(
      () => SnapshotManifest.fromJson(good..remove('fetched_at')),
      throwsFormatException,
    );
    expect(
      () => SnapshotManifest.fromJson(good..['fetched_at'] = 'yesterday'),
      throwsFormatException,
    );
  });

  test('rejects a non-int data version', () {
    final json = SnapshotManifest(
      dataVersion: 7422,
      fetchedAt: fetchedAt,
    ).toJson()..['data_version'] = '7422';

    expect(() => SnapshotManifest.fromJson(json), throwsFormatException);
  });
}
