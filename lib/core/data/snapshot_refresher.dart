// The refresh policy (spec: "refresh triggers on cold start/foreground with
// a 24h TTL; the probe is never more than once a day; full refetch only when
// the probed data version differs from the manifest's; network/parse failures
// are silent — stale data preserved").
//
// Feature-generic by design: features contribute [SnapshotUnit]s (feed →
// app-schema file builders), so later tickets add units without touching
// core. Every failure path returns `false` (nothing committed) and lets the
// previous generation keep serving.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'datafeed_client.dart';
import 'override_store.dart';
import 'snapshot_manifest.dart';

/// The refresh TTL (spec: 24 hours).
const Duration snapshotRefreshTtl = Duration(hours: 24);

/// One refreshable set of files: a feature-owned builder that turns live
/// feed data into the same app-schema JSON the snapshot tool emits (so an
/// override is just a fresher copy of the bundled asset — readers can't
/// tell, and don't need to).
class SnapshotUnit {
  const SnapshotUnit({required this.fetch});

  /// Fetches live data and returns the app-schema JSON files to store, as
  /// unit name → JSON. One unit may produce many files (the Heroes detail
  /// unit produces one per Hero); names should match the bundled assets'
  /// base names. Throws on network or feed-shape problems — the refresher
  /// keeps those silent.
  final Future<Map<String, String>> Function(DatafeedClient feed) fetch;
}

class SnapshotRefresher {
  SnapshotRefresher({
    required this.feed,
    required this.units,
    required this.overrides,
    required this.clock,
  });

  final DatafeedClient feed;
  final List<SnapshotUnit> units;
  final OverrideStore overrides;

  /// Injectable clock (tests drive TTL boundaries without sleeping).
  final DateTime Function() clock;

  /// Runs one refresh cycle. Returns true when new data was committed.
  /// Never throws: EVERY failure — network, parse, even shape-drift Errors
  /// like a TypeError from a cast — is swallowed with stale data preserved
  /// (spec: "no error UI, no crash, stale data preserved").
  Future<bool> refresh() async {
    try {
      return await _refresh();
    } catch (_) {
      // Feed-shape drift surfaces as Errors (TypeError from list.cast or a
      // null-index on a non-map), not just Exceptions — the spec's posture
      // is "no crash", so nothing is rethrown.
      return false;
    }
  }

  Future<bool> _refresh() async {
    final at = clock();

    // TTL gate: no probe (therefore no network at all) more than once a day.
    // A backward clock jump reads as "already probed in the future" — treat
    // that as expired rather than blocking probes until wall-clock catches up.
    final lastProbe = await overrides.readLastProbeAt();
    if (lastProbe != null) {
      final since = at.difference(lastProbe);
      if (since >= Duration.zero && since < snapshotRefreshTtl) return false;
    }
    // Record the attempt before probing so even a failed probe spends the
    // day's budget — an unreachable feed must not be hammered on every
    // foreground event.
    await overrides.recordProbe(at);

    final probedVersion = await feed.probeDataVersion();

    // Version gate: refetch only when the probed version differs from the
    // committed one. A manifest-less store always fetches (first refresh);
    // a null probed version can never match, so it also fetches.
    final manifest = await overrides.readManifest();
    final upToDate =
        manifest != null &&
        probedVersion != null &&
        probedVersion == manifest.dataVersion;
    if (upToDate) return false;

    // Fetch every unit first, commit last: a mid-refresh failure writes
    // nothing visible (atomic-from-the-user's-perspective).
    final blobs = <String, String>{};
    for (final unit in units) {
      blobs.addAll(await unit.fetch(feed));
    }
    await overrides.commit(
      manifest: SnapshotManifest(dataVersion: probedVersion, fetchedAt: at),
      blobs: blobs,
    );
    return true;
  }
}

/// How the app reaches Valve's datafeeds. Overridden in tests with a fake.
final datafeedClientProvider = Provider<DatafeedClient>(
  (ref) => HttpDatafeedClient(),
);

/// The app's refresher, assembled from the feed client and every feature's
/// units. Overridden in widget tests; repository tests build one over fakes.
final snapshotRefresherProvider = Provider<SnapshotRefresher>(
  (ref) => SnapshotRefresher(
    feed: ref.watch(datafeedClientProvider),
    units: ref.watch(snapshotUnitsProvider),
    overrides: ref.watch(overrideStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Injectable clock: widget tests drive TTL boundaries without sleeping.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Every feature's refresh unit. Features append here (one line each) —
/// core never imports a feature.
final snapshotUnitsProvider = Provider<List<SnapshotUnit>>((ref) => const []);
