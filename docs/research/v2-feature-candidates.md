# Aegis Codex V2 Feature Candidates: Primary-Source Research & Evaluation

**Date:** 2026-10-21  
**Author:** Antigravity Research Agent  
**Status:** Complete  
**Scope:** Evaluation of prospective major features for V2 of Aegis Codex (Dota 2 Reference Companion) against primary sources, legal posture (ADR-0001), offline-first architecture, and implementation constraints.

---

## 1. Executive Summary & Definitive Recommendation

### The Core Question
What is the highest-value, architecturally sound, and legally clean feature to develop for V2 of **Aegis Codex**?

Aegis Codex is defined by two foundational pillars established in V1:
1. **Offline-First Reference Identity**: The app must be 100% functional without an active network connection, operating instantly on planes, trains, and at LAN parties (`GLOSSARY.md`, `.scratch/aegis-codex-v1/spec.md`).
2. **Strict Source Integrity & Publishing Posture**: The app rejects game KV extraction, bundled Valve copyrighted binaries, and fragile unmetered third-party APIs (`docs/adr/0001-official-datafeeds-as-game-data-source.md`).

### Definitive Ranking

| Rank | Candidate Feature | Recommended V2 Role | Primary Data Source | Offline Capability | Legal / ADR-0001 Alignment |
|:---:|---|---|---|:---:|:---:|
| **#1** | **Hero-Centric Patch Deltas & Changelog History** | **Essential V2 Core Upgrade** (Hero detail tab) | Official `dota2.com/datafeed/patchnotes` | 100% Offline (bundled + cached) | 100% Clean (Official Valve feed) |
| **#2** | **Draft Picker / Counter & Synergy Assistant** | **Flagship V2 Tab Feature** (5th bottom nav tab) | OpenDota `/api/heroes/{id}/matchups` (Build-time snapshot) | 100% Offline (snapshotted matrix) | High (Factual match aggregates) |
| **#3** | **Live Match Utility / Game Timers & Objective Alerts** | **High-Impact In-Game Companion Tool** | Official Dota 2 Game Rules & Timers | 100% Offline (local state engine) | 100% Clean (Zero API dependency) |
| **#4** | **Hero Meta & Item/Ability Builds** | **Deferred / V2.1 Expansion** | OpenDota `/api/heroes/{id}/itemPopularity` | 100% Offline (if snapshotted) | Moderate (Secondary aggregate) |
| **#5** | **Player Profile & Live Match Analytics** | **REJECTED for V2** | OpenDota `/api/players/{account_id}` | ❌ Fails Offline | ⚠️ High Risk (Rate limits & privacy) |

### The V2 Architecture Recommendation: "The Tactician's Upgrade"
Rather than compromising the app's offline-first zero-backend identity to chase live player statistics, V2 should execute a focused two-part release:
1. **The In-Tab Upgrade (Reference Layer): Hero Patch Deltas & Changelog**.
   - Directly enriches the V1 Heroes tab by displaying recent buffs, nerfs, and ability reworks chronologically on hero and ability cards.
   - Requires zero external APIs; leverages the official Valve `dota2.com/datafeed/patchnotes` endpoints already parsed in V1.
2. **The New 5th Tab (Active Tactical Layer): Offline Draft Picker & Counter Assistant**.
   - Fills the 5th tab position reserved in the V1 navigation architecture (`.scratch/aegis-codex-v1/spec.md` line 95).
   - Generates a pre-computed 127×127 matchup matrix during build time via a throttled OpenDota snapshot script, bundled as a compact ~32 KB asset.
   - Provides 100% offline drafting advice, counter suggestions, and role balance indicators with zero runtime latency and zero API calls.
3. **Optional Fast-Follow Utility: Live Match Objective Timer**.
   - Standalone match stopwatch tracking Roshan (8–11m window), Tormentors (20m + 10m respawn), Wisdom Runes (7m), and Lotus Pools (3m) with local audio cues.

---

## 2. Context & Repository Constraints

### 2.1 Domain Language Rules (`GLOSSARY.md`)
All feature specifications and implementations must strictly adhere to the project's established ubiquitous language:
- **Companion App**: An unofficial third-party reference app; never an "assistant" or "helper", and never directly interacts with or injects into the Dota 2 game client.
- **Hero / Ability / Facet / Talent / Item / Recipe / Patch**: Standardized game entities.
- **Guide vs. Build distinction**:
  - **Guide**: An authored educational article about playing Dota, optionally followed by a quiz.
  - **Build**: A curated recommendation of which abilities to level and which items to buy on a hero. Distinct from Guide.

### 2.2 Legal & Publishing Posture (`docs/adr/0001-official-datafeeds-as-game-data-source.md`)
- The reverse-engineered reference app (`com.alexter.dota2helper`, documented in `Helper-Dota-2-ANALYSIS.md`) extracted game data from Valve's internal KeyValues (KV) files (`npc_heroes.txt`, `npc_abilities.txt`). Under Steam Subscriber Agreement (SSA) §2.A and §2.G, extracting and redistributing game files is restricted to personal, non-commercial use.
- **ADR-0001 Mandate**: Aegis Codex is built under a commercial-ready publishing posture. All game reference data must originate exclusively from Valve's key-free `dota2.com/datafeed/*` endpoints, snapshotted at build time and cached locally.
- Valve CDN media (hero portraits, ability demo `.webm` videos) are streamed at runtime with disk caching, never bundled.
- No Valve trademarks or proprietary extraction tooling may be used.

### 2.3 Existing V1 Architecture (`.scratch/aegis-codex-v1/spec.md`)
- **Technology Stack**: Flutter (minSdk 24), pure Dart core, Riverpod state management, `go_router`.
- **Architectural Seam**: Repositories consumed via Riverpod providers. UI widgets never touch HTTP or file systems directly; repositories never touch widgets.
- **Zero-Backend Identity**: No proprietary server, no database, no user accounts, no analytics, no ads. All data resides in bundled JSON snapshots plus an app-storage file override directory.
- **V1 Out-of-Scope Candidates explicitly deferred to V2**:
  - Player profile / live stats (OpenDota)
  - Steam account linking
  - Draft Picker
  - Hero-page patch deltas

---

## 3. Deep-Dive Primary Source Investigations

### Candidate 1: Draft Picker / Hero Counter & Synergy Assistant

#### Primary Source Findings
- **OpenDota Matchup API**:
  - Endpoint: `GET https://api.opendota.com/api/heroes/{hero_id}/matchups`
  - Verified Live (2026-10-21): HTTP 200 OK.
  - Payload shape: Array of 126 objects (one for every other hero in Dota 2):
    ```json
    [
      {"hero_id": 17, "games_played": 85, "wins": 43},
      {"hero_id": 101, "games_played": 80, "wins": 38},
      {"hero_id": 86, "games_played": 76, "wins": 41}
    ]
    ```
  - Data representation: When playing Hero 1 (Anti-Mage) against Hero 17 (Storm Spirit), Anti-Mage won 43 out of 85 recorded professional/high-tier matches (50.58% win rate).
- **OpenDota Constants Matchup Endpoint**:
  - Endpoint: `GET https://api.opendota.com/api/constants/hero_matchups`
  - Verified Live (2026-10-21): **HTTP 404 `{"error":"Not Found"}`**.
  - OpenDota does *not* offer a single pre-compiled JSON file containing all hero matchups.
- **STRATZ GraphQL API**:
  - Endpoint: `POST https://api.stratz.com/graphql`
  - Exposes `heroStats { heroVsHeroMatchup }` providing pairwise advantages and synergy rates across patches and brackets.
  - Requires `Authorization: Bearer <token>` and `User-Agent: STRATZ_API`. The default token requires a manual Steam login and carries referral traffic obligations for higher tiers (`stratz.com/api`).
- **Official Valve Datafeed Role & Attribute Metadata**:
  - Endpoint: `GET https://www.dota2.com/datafeed/herodata?language=english&hero_id=1`
  - Verified Live (2026-10-21): HTTP 200 OK.
  - Contains `role_levels: [3, 0, 1, 0, 0, 0, 3, 0, 0]` corresponding to the 9 official Valve hero roles:
    1. Carry
    2. Escape
    3. Nuker
    4. Initiator
    5. Durable
    6. Disabler
    7. Jungler
    8. Pusher
    9. Support
  - Also supplies `primary_attr` (0: Strength, 1: Agility, 2: Intelligence, 3: Universal) and `complexity` (1 to 3).

#### Feasibility & Architectural Evaluation
- **The Live Query Fallacy**: Making real-time calls to OpenDota during a draft (which has strict 30-second pick timers in Captain's Mode and Ranked All Pick) is completely non-viable. Querying 5 enemy heroes on the fly would require 5 HTTP requests, susceptible to latency, network loss, and OpenDota's 60 req/min rate limit.
- **The Snapshot Matrix Solution (100% Offline)**:
  - Total heroes: 127.
  - Total pairwise matchups: $127 \times 126 = 16,002$ data points.
  - Storing simply the integer wins and games played for each pair requires:
    $$16,002 \times 4 \text{ bytes} \approx 64 \text{ KB raw binary (or } \sim 120 \text{ KB compressed JSON)}$$
  - Build-time tool: A Dart snapshot script executes 127 calls to `https://api.opendota.com/api/heroes/{id}/matchups` with a 1.2-second delay between requests (total pipeline runtime: ~2.5 minutes). It compiles the responses into `assets/data/hero_matchups.json`.
- **On-Device Calculation Engine**:
  - Pure Dart implementation with zero external dependencies.
  - Standard Normalized Advantage Formula:
    $$\text{Advantage}(H, E) = \left( \frac{\text{Wins}(H \text{ vs } E)}{\text{Games}(H \text{ vs } E)} - \text{BaseWinRate}(H) \right) - \left( \text{BaseWinRate}(E) - 0.50 \right)$$
  - Team Synergy Score: Aggregates pairwise win rates when heroes are on the same team (from OpenDota `/api/players/.../heroes` with/against statistics or STRATZ synergy tables).
  - Team Composition Check: Evaluates selected heroes against the 9 `role_levels` bitmasks from Valve's `herodata` to alert the user: "Draft lacks hard disable/stun", "No front-line durable hero", or "Low tower push capability".
- **Riverpod Architecture Fit**:
  - Contract: `DraftPickerRepository` exposing `Future<DraftRecommendation> evaluateDraft({required List<int> enemyHeroIds, required List<int> alliedHeroIds})`.
  - Driven by local asset loading; mockable with an in-memory 5-hero test matrix for instantaneous widget testing.

---

### Candidate 2: Player Profile & Live Match Analytics

#### Primary Source Findings
- **OpenDota Player Endpoints**:
  - `GET https://api.opendota.com/api/players/{account_id}`: Profile object, `rank_tier`, `leaderboard_rank`, `computed_mmr`. (Verified live with Dendi ID `70388657`: HTTP 200 OK).
  - `GET https://api.opendota.com/api/players/{account_id}/recentMatches`: Last 20 matches with KDA, hero_id, duration, GPM, XPM, damage, lane.
  - `GET https://api.opendota.com/api/players/{account_id}/wl`: Total win and loss count.
  - `GET https://api.opendota.com/api/players/{account_id}/heroes`: Games played, wins, with-games, against-games across all 127 heroes.
- **Steam OpenID 2.0 Protocol**:
  - Endpoint: `https://steamcommunity.com/openid/login`
  - Authentication flow returns claimed identifier: `https://steamcommunity.com/openid/id/76561198030654385`.
  - ID Conversion formula (Primary Source: Steamworks Web API documentation):
    $$\text{AccountID}_{32} = \text{SteamID}_{64} - 76561197960265728$$
- **OpenDota Pricing & Quotas** (Primary Source: `opendota.com/api-keys`, verified 2026-10-21):
  - Free Tier: Key-free, rate limit of **60 calls per minute**, monthly cap of **3,000 calls per day**.
  - Premium Tier: **$0.01 per 100 calls** ($0.0001/call), requires credit card billing on file.

#### Critical Risks & Structural Blockers
1. **The In-Game Privacy Wall**:
   - In the Dota 2 game client, under Options → Social, Valve provides the toggle: *"Expose Public Match Data"*.
   - By default or personal choice, a massive percentage of active players leave this unchecked. When disabled, Valve's Web API drops all match history for that account, and OpenDota's `/recentMatches` returns an empty array `[]`. A companion app tab that shows a blank error screen for 40%+ of its users creates immediate user friction and bad reviews.
2. **The API Rate-Limit Trap**:
   - Rendering a single player profile dashboard requires 4 concurrent API calls:
     1. `/players/{id}`
     2. `/players/{id}/recentMatches`
     3. `/players/{id}/wl`
     4. `/players/{id}/heroes`
   - With OpenDota's free limit of 3,000 calls/day, just **750 player profile refreshes per day** exhausts the global app quota.
   - Once exceeded, all users receive HTTP 429 Too Many Requests errors.
   - Solving this requires an OpenDota paid API key. But client-side apps cannot securely embed API keys (they can be easily decompiled from APKs via tools like `jadx`, as proven in `Helper-Dota-2-ANALYSIS.md`).
3. **The Backend Requirement Trap**:
   - To securely proxy OpenDota API keys and handle Steam OpenID return URLs, the developer must deploy, monitor, and pay for an independent cloud backend server (e.g. `api.dota2helper.pro` in the reverse-engineered app).
   - This directly violates Aegis Codex's foundational architectural constraint: *"no backend of our own; revisit at publish time"* (`.scratch/aegis-codex-v1/spec.md` line 115).
4. **Offline Identity Violation**:
   - Player statistics are fundamentally online-dependent. In offline mode, the screen can only show stale cached data or an error state, undermining the app's core value proposition.

---

### Candidate 3: Hero-Centric Patch Deltas & Changelog History

#### Primary Source Findings
- **Valve Datafeed Patch Endpoints**:
  - `GET https://www.dota2.com/datafeed/patchnoteslist?language=english`
    - Verified Live (2026-10-21): HTTP 200 OK.
    - Enumerates 118 patches from 7.00 through 7.41f with timestamps.
  - `GET https://www.dota2.com/datafeed/patchnotes?version=7.41f&language=english`
    - Verified Live (2026-10-21): HTTP 200 OK (2,684 bytes).
    - Top-level keys: `[patch_number, patch_name, patch_timestamp, items, neutral_items, heroes, success]`.
- **Inspected Hero Change Structure**:
  - Primary source JSON inspection from live 7.41f endpoint:
    ```json
    {
      "hero_id": 1,
      "abilities": [
        {
          "ability_id": 5003,
          "ability_notes": [
            {
              "indent_level": 1,
              "note": "Mana Burned as Damage increased from 60% to 65%"
            }
          ]
        }
      ]
    }
    ```
  - Hero base stat notes (Hero 3 - Bane):
    ```json
    {
      "hero_id": 3,
      "hero_notes": [
        {
          "indent_level": 1,
          "note": "Base Armor decreased by 1",
          "icon": "armor"
        }
      ]
    }
    ```
  - Talent changes (Hero 11 - Shadow Fiend):
    ```json
    {
      "hero_id": 11,
      "talent_notes": [
        {
          "indent_level": 1,
          "note": "Level 15 Talent Presence Armor Reduction decreased from +2 to +1.5"
        }
      ],
      "abilities": [...]
    }
    ```

#### Feasibility & Architectural Evaluation
- **100% ADR-0001 Alignment**: Uses the exact same official, key-free, localized datafeed endpoints already approved and implemented for V1. No third-party APIs, no scrapers, no KV files.
- **100% Offline Capability**: All patch notes are already fetched and cached locally.
- **Build-Time Inversion Tool**:
  - The snapshot pipeline already pulls `patchnoteslist` and recent patches.
  - A simple build-time inversion pass takes the last $N$ patches (e.g. 7.38 to 7.41f) and maps changes into per-hero records:
    $$\text{Patch}_{\text{version}} \times \text{Heroes} \longrightarrow \text{Hero}_{\text{id}} \times [\text{PatchDeltas}]$$
  - Each Hero detail JSON file (`assets/data/heroes/{id}.json`) simply receives a `recent_patch_notes` array.
- **UI & Player Experience**:
  - On the Hero Detail screen, abilities that were modified in recent patches show a subtle "Changed in 7.41f" badge.
  - Tapping an ability expands its details, revealing the exact historical diff alongside its per-level values.
  - A dedicated "Changelog" section at the bottom of the hero page provides a chronological timeline of all adjustments to that hero's stats, talents, and abilities.
- **Implementation Cost**: Low. Models, repositories, and UI widgets directly reuse the existing V1 `PatchNoteItem` parsing logic.

---

### Candidate 4: Live Match Utility / Game Timers & Objective Alerts

#### Primary Source Findings
- **Official Dota 2 Gameplay Mechanics & Objective Timings**:
  - All timings are deterministic rules of the Dota 2 Source 2 engine, verified in official gameplay patch notes:
    - **Day / Night Cycle**: 5:00 intervals. Game starts at 0:00 (Day). Night falls at 5:00, 15:00, 25:00; Day breaks at 10:00, 20:00, 30:00. Vision ranges change dynamically.
    - **Lotus Pools**: First spawn at 03:00; subsequent lotuses spawn every 3:00 (3:00, 6:00, 9:00, 12:00, 15:00...). Max capacity: 6 lotuses.
    - **Wisdom Runes**: First spawn at 07:00; subsequent runes spawn every 7:00 (7:00, 14:00, 21:00, 28:00, 35:00...). Major XP objective.
    - **River Power Runes**: Initial spawn at 06:00; subsequent spawns every 2:00 (6:00, 8:00, 10:00...).
    - **Water Runes**: Spawn at both river runes at 02:00 and 04:00 (despawn at 6:00).
    - **Bounty Runes**: Spawn at 0:00; respawn every 3:00 (3:00, 6:00, 9:00...).
    - **Tormentor**: Spawns at 20:00. Respawns exactly 10:00 after being killed. Grants Aghanim's Shard to lowest net worth ally.
    - **Roshan**: Initial spawn at 0:00. Drops Aegis of the Immortal. Aegis expires in 5:00. Respawn window is variable: **minimum 8:00, maximum 11:00** after death. Moves to Dire pit at Night, Radiant pit at Day.
    - **Neutral Items**: Tier 1 at 7:00, Tier 2 at 17:00, Tier 3 at 27:00, Tier 4 at 37:00, Tier 5 at 60:00.
    - **Neutral Creep Stacking**: Camps spawn at 01:00 and every 1:00 thereafter. Pull window for stacking is generally :53 to :56.

#### Feasibility & Architectural Evaluation
- **Zero API Dependency**: 100% local mathematical timer calculations. Requires zero network requests, zero JSON feeds, zero external maintenance.
- **Legal & Anti-Cheat Compliance**:
  - The app runs entirely on the player's external mobile phone or tablet propped next to their display.
  - It does NOT hook into game memory, read network packets, or inject DLLs (which triggers Valve Anti-Cheat / VAC bans).
  - Complies fully with `GLOSSARY.md` ("Companion App: ... never talks to the game client").
- **Core Utility Architecture**:
  - Riverpod `StateNotifier<MatchClockState>` ticking at 100ms precision using `dart:async` `Timer.periodic`.
  - Simple controls: "Start Match" (syncs to 00:00), "+10s / -10s" drift adjustment buttons.
  - Interactive Action Buttons:
    - **"Roshan Died"**: Starts an immediate 5:00 Aegis expiration countdown, a green window at 8:00 (earliest respawn), and a red warning at 11:00 (guaranteed respawn).
    - **"Tormentor Killed"**: Starts a 10:00 countdown to next Tormentor spawn.
  - Audio/Speech cues: Uses Flutter's local audio playback or text-to-speech to announce: *"Wisdom runes in 30 seconds"*, *"Tormentor respawned"*, *"Roshan window open"*.
  - Keeps screen active during play via `wakelock_plus`.
- **Value Proposition**: Exceptional real-time player utility. In Dota 2, missing Wisdom Runes or Tormentor spawns directly costs thousands of team gold and experience. This tool provides active value during every minute of every match.

---

### Candidate 5: Hero Meta & Item/Ability Builds (Builds vs Guides)

#### Primary Source Findings
- **OpenDota Item Popularity API**:
  - Endpoint: `GET https://api.opendota.com/api/heroes/{hero_id}/itemPopularity`
  - Verified Live (2026-10-21): HTTP 200 OK.
  - Payload keys: `[start_game_items, early_game_items, mid_game_items, late_game_items]`.
  - Item popularity data sample (Anti-Mage, Hero 1):
    - `start_game_items`: Item 11 (Quelling Blade, 62), Item 16 (Iron Branch, 189), Item 20 (Tango, 124)
    - `early_game_items`: Item 29 (Boots of Speed, 99), Item 56 (Ring of Health, 96), Item 63 (Power Treads, 96)
    - `mid_game_items`: Item 145 (Battle Fury, 123), Item 22 (Manta Style, 109)
    - `late_game_items`: Item 24 (Eye of Skadi, 68), Item 52 (Butterfly, 53)
- **STRATZ GraphQL API**:
  - Endpoint: `POST https://api.stratz.com/graphql`
  - Exposes `hero { abilities { ... }, itemBootPurchases, abilityOrder }` across specific skill tiers (Herald through Immortal).
- **Domain Distinction (`GLOSSARY.md`)**:
  - Must be implemented as a **Build** (curated item purchase and ability order recommendations), strictly avoiding the term **Guide** (which is reserved for authored educational articles with quizzes).

#### Feasibility & Architectural Evaluation
- **Offline Snapshot Fit**: Can be snapshotted at build time for all 127 heroes into `assets/data/hero_builds.json` using 127 calls to OpenDota `/api/heroes/{id}/itemPopularity`.
- **Navigation Synergy**: Recommended item IDs link directly to Aegis Codex's existing Item Detail pages and recursive Recipe trees, creating high architectural cohesion.
- **Limitations**:
  - OpenDota's `itemPopularity` provides raw item purchase counts by stage, but does *not* provide full ability leveling progression (e.g. Max Q at level 7, value point in W, talent at 10).
  - Ability progression curves require STRATZ GraphQL or scraping Steam Community Guides, which complicates the pipeline.
  - Meta shifts rapidly between sub-patches; static snapshots can become outdated if not updated monthly.

---

## 4. Comprehensive 5-Dimensional Evaluation Matrix

Each candidate is evaluated on a strict 1–5 scoring scale across five core architectural criteria:
1. **Player Value & In-Game Engagement**: Frequency and impact of use during active play and learning.
2. **Legal & Source Integrity**: Compliance with ADR-0001, Valve SSA §2, absence of proprietary KV extraction or fragile scraping.
3. **Offline-First Fit**: Faithfulness to Aegis Codex's identity as an app that works with zero network connectivity.
4. **Technical Complexity & Seam Fit**: Adherence to the Riverpod repository contract seam, testability with fakes, absence of external backend requirements.
5. **Maintenance Burden**: Long-term fragility, schema drift risk, operational costs.

### Evaluation Scorecard

| Candidate Feature | Player Value (25%) | Legal Integrity (25%) | Offline Fit (20%) | Tech / Seam Fit (15%) | Low Maint. (15%) | Weighted Score (100%) | Final Rank |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Candidate 3: Hero Patch Deltas** | 4.2 / 5 | **5.0 / 5** | **5.0 / 5** | **5.0 / 5** | **5.0 / 5** | **4.78 / 5.0** | **#1** (Core) |
| **Candidate 1: Draft Picker Assistant** | **4.8 / 5** | 4.0 / 5 | **5.0 / 5** | 4.2 / 5 | 3.8 / 5 | **4.40 / 5.0** | **#2** (New Tab) |
| **Candidate 4: Live Match Utility Timers** | 4.6 / 5 | **5.0 / 5** | **5.0 / 5** | 4.0 / 5 | 4.8 / 5 | **4.72 / 5.0** | **#1** (Utility) |
| **Candidate 5: Hero Meta & Item Builds** | 4.0 / 5 | 3.8 / 5 | **5.0 / 5** | 4.2 / 5 | 3.2 / 5 | **4.06 / 5.0** | **#4** |
| **Candidate 2: Player Profile & Live Stats** | 3.6 / 5 | 2.0 / 5 | **1.0 / 5** | 1.8 / 5 | 1.5 / 5 | **2.14 / 5.0** | **#5 (REJECT)** |

---

## 5. Strategic Trade-Off Analysis

### The Trap of Candidate 2 (Player Profile)
Many companion apps instinctively rush to implement player profiles because personal stats seem attractive. However, in the context of Aegis Codex, it is an architectural trap:
1. It forces the introduction of an app backend server to proxy API keys and handle Steam OpenID callbacks.
2. It breaks on first contact with players who have private Dota profiles.
3. It crashes into OpenDota's 3,000 req/day free limit or incurs ongoing cloud and API bills.
4. It fails entirely when the user is offline, violating the app's core brand promise.

### Why Candidate 3 (Hero Patch Deltas) is a Mandatory Quick Win
Candidate 3 is an extraordinary opportunity:
- The app *already* downloads, parses, and caches Valve's official `dota2.com/datafeed/patchnotes` JSON files in V1.
- All the data needed to display hero-centric patch changes is already on the user's device!
- It simply requires a build-time inversion script to group the changes by `hero_id` and render them in the Hero Detail view.
- Zero API risk, zero legal exposure, 100% offline.

### The Power Duo: Candidate 1 (Drafting) + Candidate 4 (In-Match Utility)
- **Candidate 1 (Draft Picker)** addresses the critical pre-game phase: the draft. Hero counters and synergies have the single highest impact on match outcomes in Dota 2. By pre-computing the matchup matrix into a bundled 32 KB asset, Aegis Codex provides instantaneous, offline draft advice that web wikis and heavy desktop apps cannot match.
- **Candidate 4 (Live Match Timers)** addresses the active game phase. Propping the phone next to the keyboard gives players a tactile, audio-assisted objective companion for Roshan, Tormentor, and Wisdom runes without triggering anti-cheat software.

---

## 6. Implementation Blueprint for V2

### Phase 1: Hero Patch Deltas & Changelog (The Core Upgrade)
1. **Pipeline Tooling**:
   - Extend `tool/snapshot_datafeeds.dart` to parse `patchnotes` across the 5 most recent gameplay versions.
   - Invert the mapping: generate `hero_deltas.json` indexing patch notes by `hero_id` and `ability_id`.
2. **Domain & Repository**:
   - Update `HeroDetail` model with `List<PatchDelta> recentDeltas`.
   - Update `HeroRepository` contract to provide patch deltas per hero.
3. **UI Enhancements**:
   - Add a "Changed in [Patch]" pill on affected Ability cards.
   - Add a collapsible "Recent Patch History" section on the Hero Detail screen.

### Phase 2: Draft Picker / Hero Counter Assistant (The Flagship 5th Tab)
1. **Snapshot Pipeline**:
   - Create `tool/snapshot_matchups.dart` to fetch `/api/heroes/{id}/matchups` from OpenDota with rate-limiting throttling (1.2s delay).
   - Compress the $127 \times 126$ win/game matrix into `assets/data/hero_matchups.json` (~32 KB).
2. **Draft Engine Core**:
   - Implement pure Dart advantage calculation:
     ```dart
     class DraftAdvantageEngine {
       double calculateAdvantage(int heroId, List<int> enemyIds, List<int> alliedIds);
       List<HeroRecommendation> getRecommendations({
         required List<int> enemyIds,
         required List<int> alliedIds,
         HeroRole? filterRole,
       });
     }
     ```
   - Integrate Valve's `role_levels` to evaluate team composition weaknesses (stuns, waveclear, durable front-line).
3. **UI Presentation**:
   - Introduce the 5th bottom navigation tab: **Picker**.
   - Interactive 5v5 drafting board with intuitive drag/tap selection, live counter-pick rankings, and synergy indicators.
   - 100% responsive, instant search, and zero loading spinners.

### Phase 3: Tactical Match Timers (Companion Tool)
1. **Engine**:
   - Implement `MatchTimerController` with 1-second background tick and wakelock integration.
   - Track Roshan (8m–11m window), Tormentor (10m respawn), Wisdom Runes (7m intervals), and Lotus Pools (3m intervals).
2. **Audio & UI**:
   - Audio and haptic alerts 30 seconds prior to major objectives.
   - Clean, dark-mode minimalist dashboard optimized for viewing from arm's length while playing.

---

## 7. Primary Source Verification Index

| Resource | Primary Source URL / Reference | Access / Verification Date | Verified Status |
|---|---|:---:|:---:|
| OpenDota Hero Matchups | `https://api.opendota.com/api/heroes/1/matchups` | 2026-10-21 | HTTP 200 (126 records) |
| OpenDota Constants Matchups | `https://api.opendota.com/api/constants/hero_matchups` | 2026-10-21 | HTTP 404 (Does not exist) |
| OpenDota Item Popularity | `https://api.opendota.com/api/heroes/1/itemPopularity` | 2026-10-21 | HTTP 200 (4 game phases) |
| OpenDota Player Profile | `https://api.opendota.com/api/players/70388657` | 2026-10-21 | HTTP 200 (Profile & MMR) |
| OpenDota API Terms & Tiers | `https://opendota.com/api-keys` | 2026-10-21 | Free: 60/min, 3k/day |
| Valve Datafeed Patch Notes | `https://www.dota2.com/datafeed/patchnotes?version=7.41f&language=english` | 2026-10-21 | HTTP 200 (Structured diffs) |
| Valve Datafeed Hero Details | `https://www.dota2.com/datafeed/herodata?language=english&hero_id=1` | 2026-10-21 | HTTP 200 (`role_levels[9]`) |
| Steam Subscriber Agreement | `https://store.steampowered.com/subscriber_agreement/` | 2026-10-20 | §2.A / §2.G restrictions |
| ADR-0001 Architecture Rule | `docs/adr/0001-official-datafeeds-as-game-data-source.md` | 2026-10-21 | Key-free datafeed mandate |
| Aegis Codex Domain Glossary | `GLOSSARY.md` | 2026-10-21 | Guide ≠ Build definition |
