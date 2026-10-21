# 04: Hero detail

**What to build:** Tapping a Hero opens a complete reference page, fully offline from bundled per-Hero detail files: one continuous scroll with a collapsing header (portrait, name, primary attribute, complexity), then section cards — Attributes (base values and per-level gains), Combat stats, Abilities, Facets, Talents, Lore. Ability cards expand in place to show behavior tags, mana cost / cooldown / cast-range rows, the full description, a per-level value table derived from the feed's special values, visibly marked Innate Abilities, and Aghanim's Scepter / Shard enhancement text. Facets list each Facet with the abilities it changes; the Talent tree shows four tiers with two options each.

**Blocked by:** 03 (refresh & override infrastructure — detail files ride the shared store).

**Status:** ready-for-human

- [x] Snapshot tool emits per-Hero detail files from the official hero-detail feed; parsing test pins the schema against a real fixture
- [x] Per-level value tables render from the feed's special values at the game's level steps
- [x] Ability cards expand and collapse in place; innate abilities and Scepter/Shard enhancements are visually distinguished
- [x] Facets section shows each Facet and its changed abilities
- [x] Talent tree renders four tiers, two options per tier
- [x] Grid-to-detail navigation works; detail reads via the override-preferred store (refreshed data wins)
- [x] Lore section renders the Hero's biography
- [x] Widget test renders the detail page from a fake repository, including an expanded Ability card with its per-level table

## Comments

**Implemented 2026-10-21.** `flutter analyze` clean, full suite 107/107, `code-review` run (standards + spec axes) with the actionable findings fixed before commit.

Seams added:

- `tool/snapshot.dart` now emits one `hero_<id>.<locale>.json` per Hero (fan-out via the shared `mapConcurrently`, `heroDetailFetchConcurrency`, `heroDataFeedUrl`) alongside the roster index. All 127 bundled files regenerated from the live feed.
- `lib/features/heroes/hero_feed_to_detail.dart` — the herodata→app-schema converter (one converter, shared by the tool and the refresh unit, so an override is byte-shape compatible with the asset by construction). Display strings replicate Valve's front-end decode tables (behaviour/targeting/damage/dispel bitmasks, `%token%` and `{s:token}` resolution), verified live 2026-10-21; every rendered value still originates in the datafeed (noted in ADR-0001's consequences).
- `lib/features/heroes/hero_detail.dart` — strict app-schema model (`schema_version` 1) + `heroDetailUnitName`/`heroDetailAssetPath` (locale lives in the file name).
- `lib/features/heroes/hero_detail_repository.dart` — override-preferred, asset-fallback, offline-by-construction read of one Hero's detail.
- `lib/features/heroes/hero_detail_screen.dart` — `CustomScrollView` + pinned collapsing `SliverAppBar` (portrait behind a gradient; primary attribute dot/label and complexity pips inside the header, so they collapse with it), Attributes / Combat Stats / expandable Ability cards (Innate/Ultimate/Scepter/Shard badges in four distinct colours, behaviour chips, cost rows, per-level table, enhancement text) / Facets (hidden while the game has none — patch 7.41 removed them) / four-tier Talent tree / Lore.
- `heroes_snapshot_unit.dart` — `heroDetailSnapshotUnit` fans out over the roster (concurrency 4); any Hero's failure fails the whole unit → the refresher commits nothing (stale data preserved). `SnapshotUnit.fetch` now returns a map of unit-name → JSON so one unit may commit many files.
- Media seams (`heroHeaderBuilderProvider`, `abilityIconBuilderProvider`) keep widget tests off the CDN (ADR-0001).

Decisions worth remembering:

- **Facets**: full pipeline kept (model, converter, UI, tests), section hidden when empty — the game currently serves none for any Hero; a widget test proves rendering with a fake facet.
- **Numbers**: truncated toward zero to 2 decimals with trailing `.0` stripped, mirroring Valve's front-end, both at conversion time and at render time.
- **Unresolvable tokens fail soft**: they survive visibly in the emitted text instead of silently blanking.
