# Spec: Aegis Codex v1 — offline-first Dota 2 reference companion

Status: ready-for-agent

## Problem Statement

Dota 2 players need quick, accurate reference data while playing and learning: hero attributes, ability details with per-level values, facets, talents, Aghanim's enhancements, item costs and recipe build-ups, and the current patch's changes. Today that means browser wikis that lag patches and don't work offline, or an existing third-party Helper app whose bundled data is extracted from Valve's game files and therefore can't legally be reused or re-implemented for a published app. We need a legally clean, offline-first companion app built exclusively on official sources, that works on first launch with no network and stays current without manual effort.

## Solution

**Aegis Codex — Dota 2 reference**, an unofficial Android-first Flutter app. At build time, a Dart pipeline snapshots Valve's key-free `dota2.com/datafeed` endpoints into bundled English JSON (a short index per entity type plus per-Hero and per-Item detail files). At runtime the app refreshes at most once per day, probes the feed's data version cheaply, and only refetches when Valve ships a change; Patches older than the bundled latest are fetched on demand and cached permanently. Valve CDN icons and ability demo videos are streamed, never bundled. Four tabs — Home (latest Patch card + official Valve news), Heroes, Items, Patches — all dark-themed, all usable fully offline, with an About screen carrying the "unofficial — not affiliated with Valve" disclaimer and source attributions.

## User Stories

### Heroes

1. As a Dota 2 player, I want to browse a grid of Hero portraits, so that I can visually find a Hero quickly.
2. As a Dota 2 player, I want to filter Heroes by primary attribute (Strength / Agility / Intelligence / Universal), so that I can browse by the playstyle I want.
3. As a Dota 2 player, I want to filter Heroes by complexity, so that I can find Heroes I can pick up easily.
4. As a Dota 2 player, I want to search Heroes by name, so that I can jump straight to a Hero I already have in mind.
5. As a Dota 2 player, I want to see a Hero's base attributes and per-level gains, so that I understand how it scales.
6. As a Dota 2 player, I want to see a Hero's combat stats (attack damage, attack rate, attack range, armor, movement speed, health and mana), so that I can compare Heroes before picking one.
7. As a Dota 2 player, I want to read every Ability's description, behavior tags, mana costs, cooldown, and cast range, so that I can learn the Hero before playing it.
8. As a Dota 2 player, I want to see per-level value tables inside each Ability card, so that I can plan my skill build order.
9. As a Dota 2 player, I want Aghanim's Scepter and Shard enhancements shown inline on the Abilities they affect, so that I know what those upgrades do for this Hero.
10. As a Dota 2 player, I want Innate Abilities clearly presented as part of the Hero's kit, so that I am not confused about what I get for free.
11. As a Dota 2 player, I want to read each Facet and the abilities it changes, so that I can choose the right Facet at pick time.
12. As a Dota 2 player, I want to see the four-tier Talent tree with both options per tier, so that I can plan my Talent choices.
13. As a Dota 2 player, I want to watch an Ability's demo video in place on the Ability card, so that I can see the Ability in action without leaving the page.
14. As a Dota 2 player, I want previously watched demo videos replayed from disk without re-downloading, so that I don't burn mobile data.
15. As a Dota 2 player, I want to read the Hero's lore, so that I learn the character behind the kit.
16. As a Dota 2 player, I want the Hero detail page to be one continuous scroll with expandable Ability cards, so that browsing while playing stays fast.

### Items

17. As a Dota 2 player, I want to browse Items grouped by shop category, so that I can find Items the way the in-game shop presents them.
18. As a Dota 2 player, I want to search Items by name, so that I can jump straight to an Item.
19. As a Dota 2 player, I want to filter neutral Items by tier, so that I can look up what drops when.
20. As a Dota 2 player, I want to see an Item's total cost, combination cost, and attributes, so that I can judge whether it fits my build.
21. As a Dota 2 player, I want to read an Item's active and passive effect text, so that I know exactly what buying it gives me.
22. As a Dota 2 player, I want the Recipe tree shown as indented component rows with icons and prices, so that I can see the full build-up path.
23. As a Dota 2 player, I want to tap any component in a Recipe tree to open that Item's page, so that I can plan a complete purchase order across several Items.
24. As a Dota 2 player, I want nested Recipes (components that are themselves combined Items) expanded one level deeper, so that I never hit a dead end in a build-up.

### Patches

25. As a Dota 2 player, I want a list of Patches with number and date, latest pinned at top, so that I can see what has changed over time.
26. As a Dota 2 player, I want a Patch's changes grouped by section with Hero/Item icons and names as headers, so that I can scan for what I care about.
27. As a Dota 2 player, I want change lines rendered at their proper indentation, so that grouped changes read correctly.
28. As a Dota 2 player, I want to tap a Hero or Item mentioned in a Patch to open its detail page, so that I can see the full context of a change.
29. As a Dota 2 player, I want Patches older than the bundled latest fetched on demand, so that I can research history without a huge app.
30. As a Dota 2 player, I want an older Patch I have opened to stay available offline afterwards, so that repeated lookups are instant.

### Home & news

31. As a Dota 2 player, I want a latest-Patch card on Home, so that I always know the current game version at a glance.
32. As a Dota 2 player, I want to read official Valve announcements (filtered to Valve's own feed), so that I don't miss events and gameplay patches.
33. As a Dota 2 player, I want a failed news load to show a small inline retry, so that I am never blocked or shown a scary error screen.

### Offline & data currency

34. As a Dota 2 player, I want the app fully usable on first launch with no network, so that it works at LAN parties and on planes.
35. As a Dota 2 player, I want data refreshed automatically at most once a day, so that it is current without me doing anything.
36. As a Dota 2 player, I want a "last updated" line visible in the app, so that I can judge how fresh my data is.
37. As a Dota 2 player, I want a failed refresh to be silent (previous data kept), so that nothing I was reading disappears.

### Branding & legal

38. As a Dota 2 player, I want an About screen with the "Unofficial — not affiliated with Valve Corporation" disclaimer and source attributions (Valve datafeeds, Steam CDN, news feed), so that it is clear who owns what.
39. As a Dota 2 player, I want a consistent dark theme matching Dota's aesthetic, so that the app feels at home next to the game.
40. As a Dota 2 player, I want the app in English, so that text and data are consistent (schema already supports more languages later).

### Maintainer (build & CI)

41. As a maintainer, I want a Dart snapshot tool that fetches the official datafeeds and emits app-schema JSON per locale, so that data updates are reproducible and never involve KV-file extraction.
42. As a maintainer, I want a validate mode on the snapshot tool that re-pulls and diffs schema shape, so that Valve-side schema drift is detected before a release.
43. As a maintainer, I want parsing tests that run against real snapshot fixture files, so that a Valve schema change breaks CI loudly instead of crashing the app in the wild.
44. As a maintainer, I want repository tests driven with a fake HTTP client and fake file store, so that refresh, TTL, and fallback logic is verifiable without any network.
45. As a maintainer, I want widget tests that render real screens over in-memory fake repositories, so that UI regressions are caught without HTTP, assets, or CDN.

## Implementation Decisions

- **Platform & stack**: Android-first Flutter (minSdk 24), pure-Dart core with no platform channels outside a thin shell; Riverpod for state, go_router for navigation; dark-only theme; package id `com.henry.dota2guide`; app name "Aegis Codex — Dota 2 reference".
- **Module layout**: feature-first — `home`, `heroes`, `items`, `patches`, `about` — plus a shared core layer (HTTP client, snapshot/asset loading, override store, CDN URL construction).
- **Single test seam**: repository contracts consumed via Riverpod providers. UI never touches HTTP/files directly; repositories never touch widgets. (User-confirmed seam.)
- **Data source (per ADR-0001)**: exclusively `dota2.com/datafeed` endpoints (`herolist`, `herodata`, `itemlist`, `patchnoteslist`, `patchnotes`) and `ISteamNews/GetNewsForApp` with the `steam_community_announcements` feed filter. KV-file extraction is permanently excluded.
- **Snapshot pipeline**: a Dart tool fetches datafeeds and emits app-schema JSON — short index file per entity type plus one detail file per Hero and per Item; a Patch index plus only the latest Patch are bundled. English is bundled; the tool accepts a locale flag for future languages.
- **Refresh policy**: on cold start/foreground with a 24 h TTL, probe the feed's meta data version (small response); refetch the full snapshot only when the version bumps; fetch an individual Patch on demand and cache it permanently. Refresh failures are silent and keep stale data.
- **Persistence**: no database. Bundled assets plus a file-override directory in app storage, governed by a manifest recording data version and fetch time; reads prefer overrides and fall back to assets.
- **Models**: hand-written `fromJson` constructors; the snapshot tool's output is the schema contract (no code generation).
- **Media**: icons/images via `cached_network_image`; ability demo videos (WebM) via `video_player`, disk-cached on first play through a cache-manager with a ~300 MB cap, never preloaded, never bundled.
- **Hero detail**: one continuous scroll — collapsing header (portrait, name, primary attribute, complexity), section cards for attributes, combat stats, expandable Ability cards (behavior tags, mana/cooldown/range rows, description, per-level value table derived from `special_values`, Scepter/Shard text, ▶ in-place video), Facets with their changed abilities, four-tier Talent tree, lore.
- **Items**: list grouped by shop category with neutral tiers as a filter; detail shows cost/attributes/effects plus a Recipe tree rendered as recursive indented rows (icon, name, price), each row tappable to navigate to that Item.
- **Patches**: list with latest pinned; detail grouped by section with Hero/Item icon headers (tappable to that entity's page) and `indent_level`-respecting change lines.
- **Navigation**: four bottom tabs — Home, Heroes, Items, Patches — with About/disclaimer and the last-updated line behind a top-bar menu on Home. v2 tabs (Picker, Profile) slot in later without redesigning the bar.
- **Error posture**: reference tabs always render bundled data and never show error screens; network-dependent surfaces (news, on-demand Patches) degrade to inline retry cards; no empty states (every list has snapshot data); no onboarding.
- **Home**: latest-Patch card + Valve news feed (24 h cached) + quick entries into Heroes/Items.

## Testing Decisions

- **Good tests here exercise external behavior only**: what a repository returns and when it refreshes, what a screen shows for a given repository state — never internal call sequences or private implementation details.
- **The seam (user-confirmed)**: repository provider contracts are the single seam. Widget tests render real screens over in-memory fake repositories (override at the root). Repository tests drive the public API with a fake HTTP client and fake file store, asserting asset-first reads, override fallback, TTL refresh, data-version-bump refetch, and silent network failure. Parsing tests consume real files emitted by the snapshot tool as the pinned data contract.
- **Modules under test**: all four feature repositories, the core override/refresh store, every model's `fromJson`, and the four primary screens plus the two intricate widgets (expandable Ability card, Recipe tree).
- **Prior art**: none — this is a greenfield repo (only the Flutter scaffold exists). The first repository and widget tests establish the patterns that later features copy.
- **Release check, not a CI test**: the snapshot tool's validate mode (schema-shape diff against a fresh pull) runs manually before each release.
- **Deferred**: golden tests, until the UI stabilizes (CDN-backed images make them flaky noise in the meantime).

## Out of Scope

- Player profile / live stats (OpenDota), Steam account linking, draft Picker — v2 candidates.
- Authored Guides + quizzes and curated Builds (content projects, not data features); Guide ≠ Build per the glossary.
- Hero-page patch deltas (require diffing two snapshot versions) — v2.
- Creep encyclopedia, interactive map, Dota 1 section — permanently out (no legally clean source / original-artwork cost, per ADR-0001).
- KV-file extraction of any kind, bundling of Valve CDN assets, Valve logo or branding in the mark — permanently out (ADR-0001).
- Monetization, ads, analytics, crash reporting, accounts, any backend of our own — nothing in v1 needs them; revisit at publish time.
- iOS, desktop, web targets; RuStore distribution and RU-market specifics; a second UI language; multi-locale bundling.

## Further Notes

- Preceded by a full grilling session (2026-10-20); decisions live in `GLOSSARY.md` (domain vocabulary, incl. Guide ≠ Build) and `docs/adr/0001-official-datafeeds-as-game-data-source.md` (why the data source is what it is). Research basis: `docs/research/dota2-data-sources.md`; teardown reference: `Helper-Dota-2-ANALYSIS.md`.
- Legal posture is "build as if publishing": official datafeeds only, CDN hotlinking consciously accepted (streamed, modest caching, attribution, fallback), disclaimer everywhere. Any proposed change that touches KV-derived data or bundled Valve assets must reopen ADR-0001.
- This spec covers all of v1; implementation should be cut into per-ticket issues under `.scratch/aegis-codex-v1/issues/` (one file per ticket, numbered from 01) — suggested spine: snapshot pipeline → data models + repositories → app shell (router/theme/tabs) → Heroes → Items → Patches → Home/news → About/branding → test hardening.
- First empirical step for the implementer: run the snapshot tool against the live datafeeds once and eyeball the actual payloads before finalizing model fields — the research doc verified these endpoints live on 2026-10-20 but field-level schemas should be confirmed against reality, not the summary.
