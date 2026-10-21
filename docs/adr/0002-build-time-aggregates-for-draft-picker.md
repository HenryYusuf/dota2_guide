# Build-time match aggregates for the offline Draft Picker

The app needs hero-vs-hero matchup win rate data for the offline Draft Picker, but Valve's official `dota2.com/datafeed/*` endpoints (mandated by ADR-0001) do not provide matchup statistics. We decided: permit build-time snapshotting of public factual match aggregates from OpenDota (`/api/heroes/{hero_id}/matchups`) into a bundled, precomputed static matrix (`assets/data/hero_matchups.json`); the mobile client makes zero runtime network calls to third-party APIs and ships zero Valve proprietary game binaries or KV files.

## Considered Options

- **Runtime OpenDota API queries** — rejected because it requires network access (violating offline-first), risks hitting the 3,000 req/day rate limit, and introduces API-key leakage or proxy backend requirements.
- **Valve datafeeds exclusively** — ADR-0001 baseline, but Valve publishes no matchup or counter-pick statistical feeds; adopting this would preclude any drafting tool.
- **Build-time OpenDota snapshot to static matrix** — factual win/loss aggregates compiled into a ~32 KB bundled matrix. Chosen.

## Consequences

- The Draft Picker remains 100% functional offline with instant local calculation.
- The app preserves its zero-backend, zero-runtime-third-party-API architecture.
- Matchup matrix updates occur only during app builds or via bundled data updates, accepting minor meta-shift latency between balance patches.
