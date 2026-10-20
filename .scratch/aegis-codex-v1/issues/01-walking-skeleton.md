# 01: Walking skeleton

**What to build:** An app that launches into the Home tab and navigates cleanly: four bottom tabs (Home, Heroes, Items, Patches) with preserved state, dark-only theme, Riverpod + go_router established as the only state/routing mechanisms, feature-first folder structure (home / heroes / items / patches / about features plus a shared core layer), and a working test harness. Placeholder content per tab, clearly marked as placeholders.

**Blocked by:** None (can start immediately).

**Status:** ready-for-human

**Implemented:** 2026-10-20 by agent — commit `bee8a42` on `main`, all six checkboxes satisfied (see `## Comments`).

- [x] App launches to Home; bottom nav switches between all four tabs with preserved scroll/nav state
- [x] Dark-only theme applied globally, no light-mode flicker on startup
- [x] Feature-first structure established (four features + About stub + shared core layer)
- [x] Riverpod and go_router are wired; no other state or navigation mechanism present
- [x] Default scaffold counter demo and template clutter removed
- [x] Widget smoke test renders the shell and switches tabs; test suite green

## Comments

### 2026-10-20 — agent implementation (commit `bee8a42`)

- Structure: `lib/core/` (router, shell, theme, ui) + `lib/features/{home,heroes,items,patches,about}/`, one screen per feature; About is a stub outside the tab shell, pushed from Home's top-bar menu per the spec's navigation decision.
- Navigation: single `routerProvider` (`Provider<GoRouter>`) wrapping a `StatefulShellRoute.indexedStack` — each branch keeps its navigation stack and scroll state across tab switches (verified in `test/app_shell_test.dart`).
- Dark-only: `AppTheme.dark()` supplied as both `theme` and `darkTheme` with `themeMode: ThemeMode.dark`; Android `LaunchTheme`/`NormalTheme` in both `values` and `values-night` use dark parents, and both `drawable` and `drawable-v21` launch backgrounds use a `#101010` color (`drawable-v21` is the variant that actually applies at minSdk 24) — no light frame even when the system is in light mode.
- Template cleanup: counter demo and `test/widget_test.dart` removed; pubspec trimmed (cupertino_icons dropped, description updated); application id / namespace / launcher label set to `com.henry.dota2guide` / "Aegis Codex" per spec.
- Tests: `test/app_shell_test.dart` — launch-to-Home, dark-only under simulated light platform brightness, tab switching, About-via-menu, exact-offset scroll-state preservation. Suite green; `flutter analyze` clean.

### 2026-10-20 — agent code-review round (commit `a82f039`)

Two-axis review (standards + spec) surfaced four fixes, all applied:
- **About now sits behind an actual popup menu** on Home (spec: "behind a top-bar menu on Home") — was a bare IconButton; new test covers menu → About.
- **minSdk pinned to 24** (spec) instead of inheriting `flutter.minSdkVersion`.
- **`drawable-v21/launch_background.xml` fixed** — it shadows `drawable/` on every supported device, so the earlier `#101010` change never applied; both variants now use the dark color.
- **Re-tap-current-tab reset removed** from the shell — un-asked-for, and it discarded the nav state the ticket requires preserved.
Also: scroll test now asserts the exact saved offset (was `> 0`), and the duplicated nav-bar finder in tests is extracted to a `navLabel` helper. Deliberately not addressed: the three tab screens stay near-identical (feature-first structure is the documented standard and later tickets diverge them), and the About placeholder card stays bespoke (its content diverges next ticket).
