# 05: Ability demo videos

**What to build:** Ability cards gain an in-place play control that streams the Ability's demo video from the Valve CDN (never bundled, correct two-level URL path). The first play downloads the video into a disk cache (capped at ~300 MB); every replay uses the cache and works in airplane mode. A missing or failed video degrades to a small inline state without affecting the rest of the card.

**Blocked by:** 04 (hero detail — the card it lives on).

**Status:** ready-for-human

- [x] Play control appears on Ability cards whose abilities have demo videos; playback happens inline on the detail page
- [x] CDN URL construction is correct (hero folder + full ability-name file) — verified against the real CDN paths
- [x] First play persists the video to disk; a replay succeeds with no network
- [x] Disk cache respects the ~300 MB cap
- [x] Missing or failed video shows a small inline degraded state; description and stats stay visible
- [x] Widget test covers the degraded state; cache/playback behavior verified at the repository seam with fakes

## Comments

### 2026-10-21 — implementation complete

Delivered on branch `main` (from `a1f062e 04: Hero detail`), TDD, analyzer clean, full suite green (122 tests).

**URL convention (verified live 2026-10-21):** the feed carries NO video field, so `CdnUrls.abilityDemoVideo(heroKey, abilityName)` builds the path by convention and existence is discovered at play time. Two-level path is required — `abilities/antimage/antimage_blink.webm` returns 200, the flat `abilities/antimage_blink.webm` 404s. A 404 is a normal state, surfaced as `VideoUnavailableException`.

**Repository seam** (`lib/features/heroes/ability_video_repository.dart`):
- `AbilityVideoRepository.videoFileFor(cdnUrl)` → local `File`; the UI never touches HTTP or paths.
- Cache mirrors the CDN's two-level path (`<heroFolder>/<abilityName>.webm` under `<appSupportDir>/ability_videos`); download goes to a `.part` temp file then renames (a crash never leaves a truncated file the replay would trust).
- Replay = pure disk read, no network (airplane-mode safe, across restarts).
- Cap `abilityVideoCacheMaxBytes = 300 MB`: least-recently-played evicted first (modified time = last-played clock, touched on every replay); eviction failures are best-effort and never break playback.
- 8 repository tests incl. offline replay after restart, cap eviction, and LRU touch on replay (injectable clock, no sleeping).

**UI** (`hero_detail_screen.dart` + new `widgets/ability_demo_player.dart`):
- Expanded Ability card gains a small "▶ Play demo" control at the top of the body; first tap streams+ caches, then the video plays inline (muted, looping, tap to pause/resume — `AbilityDemoPlayer`).
- `VideoUnavailableException` / `VideoDownloadException` / corrupt file → small inline `DemoUnavailable` note ("No demo video"); description, per-level table, and all stats stay visible. Never an error screen.
- Player widget is injected via `abilityDemoVideoBuilderProvider` and the repository via `abilityVideoRepositoryProvider` (lazy — rendering a card never touches storage), so widget tests never touch `video_player` or the platform (same posture as the icon/portrait builders).

**Also:** `video_player: ^2.14.1` added; `INTERNET` permission added to the MAIN `AndroidManifest.xml` (only debug/profile had it — release builds could not have streamed).

**Widget tests** (3 new, in `hero_detail_screen_test.dart`, fake repository + stubbed player): play control streams inline via the two-level CDN URL; 404 degrades inline with description/stats intact; transport failure degrades the same quiet way.

### 2026-10-21 — code review applied

Two-axis review (standards + spec) against `a1f062e`. Findings fixed:

- **Disk failures escaped the degrade path** (spec): `_download`'s file-write steps could throw a raw `FileSystemException` past the card's handlers. The write/rename block is now wrapped and surfaces as `VideoDownloadException`; new test "an unwritable cache degrades as a download failure, not a crash" pins it.
- **Poisoned cache entry was permanent + LRU-protected** (spec): a corrupt cached WebM degraded forever and replay-touching kept it from being evicted. `AbilityDemoPlayer` now deletes the undecodable file (best-effort) so the next play re-downloads.
- **Duplicated degrade catches** (standards): the two identical `on VideoUnavailableException` / `on VideoDownloadException` clauses collapsed onto a new shared `AbilityVideoException` base.
- **Duplicated test code** (standards): the two degrade widget tests share a `tapDemoPlay` helper; the repository cache tests share hoisted URL/fixture constants. The LRU-touch test now also asserts the *displaced* file (B) is the one evicted, not just that A survives.
- The two loading-spinner sites and the `heroKey` threading through three widgets were reviewed and left as-is (idiomatic Flutter; two sites only).

Deliberately kept: INTERNET permission in the main manifest (release builds cannot stream without it — adjacent to the ticket but load-bearing for it); hand-rolled cache instead of a `cache_manager` package (the spec's "~300 MB cap … on first play" is satisfied at the repository seam the ticket names, and the cache mirrors the CDN's two-level path, which off-the-shelf managers don't).
