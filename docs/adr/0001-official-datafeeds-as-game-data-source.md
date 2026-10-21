# Official Valve datafeeds as the sole game-reference-data source

The app needs offline-first hero/item/patch data, and the reverse-engineered reference app obtains it by extracting Valve's KV game files — but the Steam Subscriber Agreement (§2.A/§2.G) restricts that content to personal, non-commercial use, and this app is being built as if it will be published. We decided: all game reference data comes exclusively from Valve's key-free `dota2.com/datafeed/*` endpoints (snapshotted at build time into bundled JSON, refreshed at runtime); Valve CDN media (icons, ability videos) is streamed at runtime and never bundled; extracting or shipping KV-derived data is permanently excluded.

## Considered Options

- **KV-file extraction (via the dotabuff/d2vpkr mirror)** — what the original app does; richest data (creeps, buildings, per-level tables), but converting Valve's "Content and Services" into shippable JSON is only licensed for personal, non-commercial use. Rejected under the publish posture.
- **OpenDota constants API** — MIT-licensed code, but the hosted API's data carries no license, and its patch data lagged Valve by ~6 months at research time. Rejected as the primary source.
- **`dota2.com/datafeed/*`** — official, key-free, localized, current. Chosen.

## Consequences

- Creeps, buildings, and the Dota 1 section have no legally clean data source and are permanently out of scope.
- Per-level ability values must be derived from `special_values[]` in `herodata`, not read from a Valve table.
- Decode *logic* replicated from Valve's front-end `main.js` (behaviour/damage/dispel bitmask tables, `%token%` substitution rules — see `hero_feed_to_detail.dart`) is not a data source: every value it renders still originates in the datafeed document. Only the mapping code is copied.
- The app ships Valve attribution plus an "unofficial — not affiliated with Valve" disclaimer; CDN hotlinking is a consciously accepted ambiguity (no Valve term permits or forbids it).
