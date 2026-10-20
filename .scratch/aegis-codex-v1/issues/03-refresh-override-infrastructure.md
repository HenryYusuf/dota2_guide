# 03: Refresh & override infrastructure

**What to build:** The app keeps its bundled snapshot current without user action. On cold start or foreground resume, at most once per 24 hours, it probes the official feed's meta data version (a small response); only when the version bumps does it refetch the snapshot and write override files. All reads prefer overrides over bundled assets, governed by a manifest recording data version and fetch time. Any network or parse failure is silent: stale data is kept, no error UI appears, and the Hero roster demonstrably reflects a version bump.

**Blocked by:** 02 (heroes grid — the first consumer).

**Status:** ready-for-human

- [x] File-override store: reads prefer override files, fall back to bundled assets; manifest records data version and fetch timestamp
- [x] Refresh triggers on cold start/foreground with a 24 h TTL; probe never runs more than once a day
- [x] Full refetch happens only when the probed data version differs from the manifest's
- [x] Refresh writes override files atomically from the user's perspective: a failed refresh leaves all previous data intact
- [x] Network and parse failures are silent — no error UI, no crash, stale data preserved
- [x] Repository tests cover: within-TTL skip, expired-TTL probe, version-bump refetch, failed-refresh-keeps-stale, override-preferred-over-asset
- [x] End-to-end demonstration: after a version bump, the Hero roster shows refreshed data

## Comments

**Implemented 2026-10-21.** Seams added (all under `lib/core/data/` unless noted):

- `SnapshotManifest` — strict parse; `dataVersion` is `int?` (null = feed served no version → always refetch on probe, per the live-feed drift observed 2026-10-21).
- `FileStore` (interface) + `DirectoryFileStore` — the dart:io seam; `writeAtomic` = temp file + rename. `fileStoreProvider` / `appSupportDirProvider` (path_provider resolved once in `main()`, then a sync `Provider<String>` so everything downstream constructs synchronously).
- `OverrideStore` — `generations/<fetchedAt-micros>/…` blobs with the manifest written LAST as the commit point; readers only reach blobs through the manifest, so any mid-commit failure leaves the previous generation fully live. Best-effort pruning. Probe stamp (`probe.json`) kept separate from the manifest so "probe at most once a day" holds even when nothing is worth committing.
- `SnapshotSource` — override-preferred read with unconditional asset fallback (corrupt manifest → asset fallback, never a crash).
- `DatafeedClient` + `HttpDatafeedClient` — probes `herolist?language=english` (~16 KB) for `result.meta.data_version`; throws on HTTP/parse problems, refresher keeps those silent.
- `SnapshotRefresher` + `SnapshotUnit` — feature-generic: features contribute feed→app-schema units; TTL gate → record probe → version gate → fetch all units → single atomic commit. Never throws; every failure returns `false` with stale data intact.
- `RefreshEpochNotifier` — bumped by the trigger after a committed refresh so `heroesProvider` re-reads.
- `RefreshTrigger` — observer widget in `AegisApp`: cold start + every resume.
- `hero_feed_to_index.dart` — the feed→app-schema converter extracted from `tool/snapshot.dart` and SHARED with the runtime refresh unit, so an override is byte-shape compatible with the bundled asset by construction (one converter, two writers — drift impossible).
- `heroes_snapshot_unit.dart` — the Heroes feature's unit (issue 04/06/08 add their own; core never imports a feature, `main()` composes the unit list).

**Design notes / gotchas:**
- No live feed currently serves a stable `meta.data_version` (Valve drifted since the research doc). A null probe version can never match the manifest → every probe refetches; combined with the 24 h TTL that's ≤1 refetch/day, which satisfies the spec's intent. When the meta block reappears, the version gate starts saving fetches with no code change.
- Widget tests that pump `AegisApp` must stub `fileStoreProvider` + `datafeedClientProvider` (the cold-start trigger reaches both); real dart:io futures never complete in the fake-async test zone.
- E2E: `test/refresh_e2e_test.dart` — real app over fakes; legal lifecycle chain `paused → hidden → inactive → resumed` to simulate a foreground resume.

**Code-review fixes (2026-10-21):**
- `SnapshotRefresher.refresh()` now catches all throwables (`catch (_)`), not just `Exception` — feed-shape drift surfaces as `TypeError` (an `Error`), and the spec demands "no crash". Regression test added.
- A backward clock jump (wall clock set back) is treated as TTL-expired → re-probe, instead of blocking refreshes until the clock catches up. Regression test added.
- Dedup/refactors: shared `refreshSeamOverrides()` test helper; `OverrideStore._readJsonObject()` shared by manifest/probe reads; single `heroListFeedUrl` const; `tool/snapshot.dart` now reuses `HttpDatafeedClient.fetchJson`; renames for clarity (`now` → `clock`, `_nested` → `_section`, `_at` → `_absolute`).

**Tests:** 64 pass; `flutter analyze` clean; `dart format` applied.
