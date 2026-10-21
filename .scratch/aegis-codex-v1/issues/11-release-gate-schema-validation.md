# 11: Release gate & schema validation

**What to build:** Releases are protected against Valve-side schema drift. The snapshot tool gains a validate mode that re-pulls the official feeds and diffs their schema shape against the committed snapshot, exiting non-zero on drift with a clear report. The full test suite is wired for CI, and a cross-screen widget smoke pass covers all four tabs plus About navigating end-to-end over fake repositories. A short release checklist makes running validate before bundling a new snapshot mandatory.

**Blocked by:** 09 (home — last consumer of network data) and 10 (about — completes the surface area).

**Status:** ready-for-agent

- [x] Validate mode re-pulls the feeds, diffs schema shape against the committed snapshot, and exits non-zero on drift; usage documented
- [x] CI runs parsing, repository, and widget suites on every change
- [x] Cross-screen widget smoke: all four tabs plus About render and navigate with fake repositories
- [x] Release checklist written and committed, with validate-before-snapshot as a required step
