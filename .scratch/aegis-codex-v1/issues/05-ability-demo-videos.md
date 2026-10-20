# 05: Ability demo videos

**What to build:** Ability cards gain an in-place play control that streams the Ability's demo video from the Valve CDN (never bundled, correct two-level URL path). The first play downloads the video into a disk cache (capped at ~300 MB); every replay uses the cache and works in airplane mode. A missing or failed video degrades to a small inline state without affecting the rest of the card.

**Blocked by:** 04 (hero detail — the card it lives on).

**Status:** ready-for-agent

- [ ] Play control appears on Ability cards whose abilities have demo videos; playback happens inline on the detail page
- [ ] CDN URL construction is correct (hero folder + full ability-name file) — verified against the real CDN paths
- [ ] First play persists the video to disk; a replay succeeds with no network
- [ ] Disk cache respects the ~300 MB cap
- [ ] Missing or failed video shows a small inline degraded state; description and stats stay visible
- [ ] Widget test covers the degraded state; cache/playback behavior verified at the repository seam with fakes
