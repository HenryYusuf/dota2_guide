# 06: Items list & detail

**What to build:** The Items tab works fully offline from bundled per-Item snapshot files. The list is grouped by shop category with neutral Items filterable by tier and searchable by name. Tapping an Item opens a detail page showing total cost, combination cost, attributes, and active/passive effect text. The Items repository rides the same override-preferred store and refresh pattern established for Heroes.

**Blocked by:** 03 (refresh & override infrastructure — the shared store pattern).

**Status:** ready-for-human

- [x] Snapshot tool emits an Item index plus per-Item detail files from the official item feed; parsing tests pin both schemas against real fixtures
- [x] List renders grouped by shop category; neutral Items filter by tier; name search works
- [x] Detail page shows total cost, combination cost, attributes, and active/passive effect text
- [x] Items repository uses the shared override-preferred store and refresh pattern (no bespoke persistence)
- [x] Repository tests and widget tests follow the pattern set by the Heroes tickets

## Comments

### 2026-10-21 — implementation complete

Delivered on branch `main`, analyzer clean (`dart analyze` reporting no issues), full suite green (151 tests).

**Snapshot & Data Conversion:**
- `tool/snapshot.dart` now emits the full Item index (`items.<locale>.json`, 544 entries) and per-Item detail files (`item_<id>.<locale>.json`, 408 listable items) using Valve's official key-free datafeeds (`itemListFeedUrl` and `itemDataFeedUrl`). Supports `--heroes-only` and `--items-only` CLI flags while defaulting to snapshotting both.
- Feed converters `item_feed_to_index.dart` and `item_feed_to_detail.dart` shared with runtime refresh units (`items_snapshot_unit.dart`), ensuring byte-shape compatibility by construction.
- Combination costs and components resolved from recipe entries (`itemRecipesFromItemlist`), with attribute heading tokens decoded (`itemHeadingTokens`).

**Repository & Store Pattern:**
- `SnapshotItemsRepository` and `SnapshotItemDetailRepository` consume `SnapshotSource` (override-first, bundled asset fallback), identical to Heroes.
- Registered `itemsSnapshotUnit` and `itemDetailSnapshotUnit` in `main.dart`'s `snapshotUnitsProvider`.

**UI:**
- `ItemsScreen`: grouped by shop categories (`ShopCategory`), searchable by name with instant refiltering, and filterable by neutral tiers (Tier 1–5 chips). Typed row hierarchy (`_ItemRow`, `_CategoryHeaderRow`, `_ItemEntryRow`) with exhaustive pattern matching.
- `ItemDetailScreen`: route `/items/:id` nested inside the Items tab branch; displays identity, shop placement, total cost, combination cost, attributes, effects (active/passive/toggle/use), notes, and lore.
- Media streamed via `ItemIcon` and stubbable via `itemIconBuilderProvider`.

**Tests:**
- Parsing tests against real fixtures: `item_index_test.dart` and `item_detail_test.dart` (including sweep over 408 bundled detail files).
- Feed-to-detail unit tests: `item_feed_to_detail_test.dart`.
- Repository tests: `items_repository_test.dart` and `item_detail_repository_test.dart`.
- Snapshot unit tests: `items_snapshot_unit_test.dart`.
- Widget tests: `items_screen_test.dart` and `item_detail_screen_test.dart`.
- Shell integration: `app_shell_test.dart` updated with `_FakeItemsRepository` to prevent fake-async bundle deadlocks.

### 2026-10-21 — code review applied

Two-axis review (standards + spec):
- **Effect card key collision risk** (spec): used `effects.indexed` to prefix effect card keys with unique indices (`item-effect-$i-...`), avoiding duplicate key collisions for untitled effects.
- **Untyped list flattening & lookahead scan** (standards): refactored `_sectionRows` in `ItemsScreen` to use a sealed type hierarchy (`_ItemRow`) and exhaustive pattern matching in `itemBuilder`.
- **Riverpod build() convention** (standards): changed `ref.read` to `ref.watch(itemIconBuilderProvider)` in `ItemsScreen.build()`.
- **Abbreviation** (standards): renamed `_fmt` to `_formatNumber`.
- **Test flake fix in Heroes video repository**: added `await _touch(file)` on fresh downloads in `ability_video_repository.dart` so files use mock clock time instead of filesystem clock, resolving eviction test flakiness.
