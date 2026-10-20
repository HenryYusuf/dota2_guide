# 03: Refresh & override infrastructure

**What to build:** The app keeps its bundled snapshot current without user action. On cold start or foreground resume, at most once per 24 hours, it probes the official feed's meta data version (a small response); only when the version bumps does it refetch the snapshot and write override files. All reads prefer overrides over bundled assets, governed by a manifest recording data version and fetch time. Any network or parse failure is silent: stale data is kept, no error UI appears, and the Hero roster demonstrably reflects a version bump.

**Blocked by:** 02 (heroes grid — the first consumer).

**Status:** ready-for-agent

- [ ] File-override store: reads prefer override files, fall back to bundled assets; manifest records data version and fetch timestamp
- [ ] Refresh triggers on cold start/foreground with a 24 h TTL; probe never runs more than once a day
- [ ] Full refetch happens only when the probed data version differs from the manifest's
- [ ] Refresh writes override files atomically from the user's perspective: a failed refresh leaves all previous data intact
- [ ] Network and parse failures are silent — no error UI, no crash, stale data preserved
- [ ] Repository tests cover: within-TTL skip, expired-TTL probe, version-bump refetch, failed-refresh-keeps-stale, override-preferred-over-asset
- [ ] End-to-end demonstration: after a version bump, the Hero roster shows refreshed data
