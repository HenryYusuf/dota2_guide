# 02: Heroes grid from bundled snapshot

**What to build:** The Heroes tab shows the real Hero roster entirely offline. A snapshot tool fetches the official hero-list datafeed once and emits an English Hero index file (id, Valve key name, localized name, primary attribute, complexity, portrait URL) into bundled assets; the app renders a portrait grid with primary-attribute filter chips (Strength / Agility / Intelligence / Universal), a complexity filter, and name search. Portrait images stream from the Valve CDN at runtime and are never bundled.

**Blocked by:** 01 (walking skeleton).

**Status:** ready-for-human

**Implemented:** 2026-10-21 by agent — all seven checkboxes satisfied (see `## Comments`).

- [x] Snapshot tool fetches the official hero-list feed and emits an app-schema English index file; accepts a locale flag for future languages
- [x] Hero index model parses the real emitted fixture; parsing test pins the schema and fails on drift
- [x] Heroes tab renders the portrait grid from the bundled asset with no network on first launch
- [x] Attribute chips and complexity filter narrow the grid; name search matches against localized names
- [x] Portraits load from the Valve CDN at runtime; no Valve media in the asset bundle
- [x] Repository test covers the asset-first read path with a fake loader
- [x] Widget test covers grid, filters, and search over a fake repository

## Comments

### 2026-10-21 — agent implementation

- **Snapshot tool** (`tool/snapshot.dart`): fetches `dota2.com/datafeed/herolist?language=<token>`, maps the feed's int `primary_attr` to stable wire names (unknown int → loud `FormatException`, so Valve-side renumbering breaks the snapshot rather than mislabelling heroes), emits `assets/data/heroes.<locale>.json` with a `schema_version`. `--locale` accepts any Valve language token (verified: `--locale russian` runs clean), `--out` redirects the output dir. Live run 2026-10-21 emitted 127 heroes.
- **App schema** (`lib/features/heroes/hero_index.dart`): `HeroIndex` / `HeroSummary` with strict hand-written `fromJson` (schema_version gate, non-empty strings, complexity 1–3, known attribute only). The contract is the emitted file; `hero_index_test.dart` parses the real fixture and pins CDN URL shape as a literal so tool and test can't agree on a shared wrong constant.
- **Repository seam** (`heroes_repository.dart` + `core/data/asset_loader.dart`): `AssetHeroesRepository` reads the bundled asset through an injectable `AssetLoader`; no HTTP client exists on this read path, which is what makes first launch work offline. `heroesRepositoryProvider` is the provider seam issue 03 layers overrides onto.
- **Heroes tab** (`heroes_screen.dart`): search field + attribute FilterChips (coloured dots, original palette — no Valve artwork) + complexity chips, all combinable (AND across categories, OR within), alphabetical presentation, quiet "No heroes match." empty state. Grid tiles are the CDN portrait edge-to-edge under a bottom gradient with the name overlay.
- **Portraits** (`core/cdn/cdn_urls.dart`, `widgets/hero_portrait.dart`): CDN URL conventions live in pure-Dart core shared with the snapshot tool (single source of truth; `windrunner.png` vs `windranger.png` lesson documented). `CachedNetworkImage` streams at runtime with a neutral silhouette fallback; `portraitBuilderProvider` lets widget tests stand in for the CDN. `assets/` contains only the JSON index — zero Valve media bundled (ADR-0001).
- **Tests**: parsing test over the real fixture (pins schema + drift rejection); repository test with a fake loader (asset-first path, exact asset path, pubspec wiring); widget tests over a fake repository (grid order, attribute/complexity/search/filter-combination, first-launch render through the real asset bundle in `heroes_screen_test.dart`).
- **Fixed a latent hang from the prior session's WIP**: `test/app_shell_test.dart`'s scroll test hung on `pumpAndSettle` after the Heroes tab became real — flutter_test's fake-async zone never completes a `rootBundle` load after the first one in an isolate, so any widget test touching the bundle after an earlier one deadlocks (the previous session left two `_debug_*` bisect files behind; removed). Fix: shell tests override `heroesRepositoryProvider` with an empty in-memory fake — they cover navigation, not data; the real-asset read path stays covered by `heroes_screen_test.dart` (first bundle load in its isolate) and the repository test.
- **Empirical note for future-locale work**: `language=russian` currently returns English `name_loc` values on `herolist` — worth re-checking the feed's language handling before snapshotting a second locale.

`flutter analyze` clean; `dart format` clean; full suite green (21 tests).
