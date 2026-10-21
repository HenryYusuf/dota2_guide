Status: ready-for-agent

# Aegis Codex V2: The Tactician's Upgrade

## Problem Statement

As a competitive Dota 2 player, I rely on Aegis Codex as my trusted, offline-first reference companion. However, during live gameplay and the crucial drafting phase, the app currently offers only passive static lookup:

1. **Blind Drafting**: During hero selection (which has strict 30-second timers), I have to mentally calculate hero counters and team synergies or tab out to slow, ad-ridden web wikis that fail when internet connectivity is spotty. I have no fast, offline tool to determine which hero provides the highest statistical advantage against the enemy team's picks or whether my team lacks essential combat roles like lockdown or frontline durability.
2. **Context-Free Patch Reading**: When a new gameplay patch drops, I can read the chronological patch notes in the Patches tab, but when I navigate to a specific Hero's page to study their kit, there is no indication of what recently changed. I have to cross-reference ability numbers against external patch diffs to understand whether an ability was buffed or nerfed in recent updates.

I need Aegis Codex to evolve from a static reference manual into an active tactical drafting companion, while preserving its instant responsiveness, zero-network offline functionality, and clean ad-free identity.

---

## Solution

Aegis Codex V2 ("The Tactician's Upgrade") delivers a focused, high-impact expansion consisting of:

1. **The Draft Picker (The 5th Navigation Tab)**:
   - An interactive 5v5 drafting board (Allies vs. Enemies) accessible directly from the bottom navigation bar.
   - Instantaneous offline counter recommendations powered by a precomputed Matchup Matrix, calculating normalized Advantage scores against all selected enemy heroes in real time.
   - Automated Composition Diagnostics evaluating team balance across four vital combat archetypes: Disabler (lockdown), Durable (frontline), Initiator, and Support.
   - Quick-filtering by competitive Position (Pos 1 through Pos 5) so players can immediately find the best counter for their assigned lane and role.
   - 100% offline with zero runtime third-party API dependencies.

2. **Hero-Centric Patch Deltas & Changelog History**:
   - Visual indicators on Ability cards highlighting recent modifications (e.g. "Changed in 7.41f").
   - Inline expandable diff panels on ability cards showing the exact notes and numerical adjustments from recent patches.
   - A dedicated chronological Hero Changelog section at the bottom of the Hero screen aggregating all ability, talent, and base attribute changes across the last 5 gameplay patches.

---

## User Stories

### Draft Picker & Counter Recommendations
1. As a player in a ranked draft, I want to see a dedicated "Draft" tab in the bottom navigation bar, so that I can open the drafting tool with a single tap.
2. As a player facing enemy picks, I want to tap an enemy slot and select a Hero from the roster, so that the app registers the enemy lineup.
3. As a player who selected an enemy Hero, I want the remaining Hero roster to instantly re-rank by statistical Advantage, so that I immediately see the strongest counter picks.
4. As a player facing multiple enemy heroes, I want the Advantage score to reflect the arithmetic mean of normalized advantages against all selected enemies, so that the recommendation is well-rounded rather than skewed by a single outlier.
5. As a player entering allied picks, I want to tap an allied slot and assign a Hero, so that the app marks that Hero as unavailable and updates team composition stats.
6. As a player who made a mistake during a draft, I want to tap or long-press an assigned slot to clear it, so that the recommendation list updates dynamically.
7. As a player starting a new match, I want a prominent "Reset Draft" button in the app bar, so that I can clear all 10 slots with one confirmation.
8. As a player assigned to a specific lane, I want to filter the recommended candidate list by Position (Pos 1: Safe Lane, Pos 2: Mid, Pos 3: Offlane, Pos 4: Soft Support, Pos 5: Hard Support), so that I only see heroes appropriate for my farm priority.
9. As a player evaluating a recommended Hero, I want to see their normalized Advantage percentage clearly displayed (+3.4%, -1.8%), so that I understand the statistical confidence of the recommendation.
10. As a player searching for a specific counter hero, I want an instant text filter in the Draft Picker, so that I can locate any Hero by name in under a second.
11. As a player using the app offline on a tablet or phone at a tournament, I want the Draft Picker to compute all recommendations locally without network calls, so that the tool never lags or fails due to poor venue Wi-Fi.

### Team Composition Diagnostics
12. As a drafting player, I want to see real-time Composition Diagnostic indicators for my team, so that I can spot critical strategic deficiencies before locking in.
13. As a drafting player whose team has no stuns or crowd control, I want to see a clear diagnostic alert ("Draft lacks reliable stuns/disable"), so that our team does not get overrun by mobile enemy heroes.
14. As a drafting player whose team is all squishy heroes, I want to see an alert ("Draft lacks durable frontline"), so that we know we need a durable hero to absorb enemy initiation.
15. As a drafting player whose team has no engage tools, I want to see an alert ("Draft lacks initiation"), so that we know someone must provide teamfight engagement.
16. As a drafting player whose team has drafted five core heroes, I want to see an alert ("Draft lacks sufficient support"), so that we can correct farm distribution.
17. As a drafting player whose team satisfies all core composition thresholds, I want to see green status indicators, so that I have confidence in our team balance.

### Hero Patch Deltas & Historical Changelog
18. As a player reading a Hero's details, I want modified Ability cards to display a distinct "Changed in [Patch]" chip, so that I immediately know which parts of the kit were adjusted.
19. As a player inspecting a modified Ability card, I want to tap the patch chip or card to expand an inline diff panel, so that I can read the exact historical patch notes alongside current ability stats.
20. As a player wanting a holistic overview of a Hero's balance trajectory, I want a chronological "Changelog" section at the bottom of the Hero screen, so that I can review all stat, ability, and talent changes across recent patches in one place.
21. As a player reviewing patch notes on a Hero's page, I want each entry clearly attributed to its specific Patch number and date, so that I understand the chronological context of the changes.
22. As an offline player, I want all patch deltas for recent patches to be bundled on-device, so that the changelog loads instantly without network requests.

---

## Implementation Decisions

### Modules & Seams
- **Core Seams**:
  - `MatchupMatrixRepository`: Asynchronous interface providing access to the precomputed `MatchupMatrix`. The production implementation reads from bundled assets (`assets/data/hero_matchups.json`) with in-memory caching.
  - `PatchHistoryRepository`: Asynchronous interface providing a list of `PatchDelta` objects for a given `heroId`. The production implementation reads from bundled assets (`assets/data/hero_patch_history.json`).
- **Domain Layer (`DraftEngine`)**:
  - Implemented as a pure-Dart domain calculation service with zero Flutter or framework dependencies.
  - Computes normalized Advantage scores using the arithmetic mean over all active enemy heroes.
  - Evaluates team composition against the 4 essential combat pillars (Disabler, Durable, Initiator, Support) using Valve's official `role_levels`.
- **State Management**:
  - `DraftSessionNotifier`: An in-memory Riverpod notifier managing active draft state (allied picks, enemy picks, selected position filter, text query).
  - Draft state is explicitly **ephemeral**: it does not persist to disk across cold app restarts, ensuring instant resets and zero storage footprint.
- **Routing & Shell Navigation**:
  - Bottom navigation bar updated to include 5 tabs: Home, Heroes, Items, Patches, Draft.
  - Draft tab routes to `/draft`.

### Data Assets & Pipeline Architecture
- **Bundled Matchup Matrix**:
  - `assets/data/hero_matchups.json`: A compact keyed JSON (~35 KB) mapping hero IDs to opponent record pairs `[wins, total_games]`.
  - Checked directly into version control to satisfy the zero-network cold start requirement.
- **Bundled Patch History**:
  - `assets/data/hero_patch_history.json`: Standalone pre-inverted JSON (~60 KB) containing patch notes for the last 5 gameplay patches, indexed by `hero_id`.
  - Decoupled from individual hero files to preserve clean reference models and avoid cold-start regression on the Heroes tab.
- **Dedicated Snapshot Tools**:
  - `tool/snapshot_matchups.dart`: Independent CLI tool querying OpenDota `/api/heroes/{id}/matchups` with a 1.2s inter-request throttle (~2.5 minutes runtime) to compile the matrix. Run only when meta/bracket data is updated.
  - `tool/snapshot_datafeeds.dart`: Extended to parse Valve's `patchnotes` endpoints and invert the last 5 patches into `hero_patch_history.json`.

### Domain Logic & Mathematical Formulations
- **Advantage Formula**:
  $$\text{Advantage}(H, E) = \left( \frac{\text{Wins}(H \text{ vs } E)}{\text{Games}(H \text{ vs } E)} - \text{BaseWinRate}(H) \right) - \left( \text{BaseWinRate}(E) - 0.50 \right)$$
- **Draft Score**:
  $$\text{Score}(H) = \frac{1}{|E_{\text{picked}}|} \sum_{e \in E_{\text{picked}}} \text{Advantage}(H, e)$$
- **Role Bitmask Thresholds**:
  - Evaluates cumulative team role points from Valve's official `role_levels` (thresholds: Disabler $\ge 3$, Durable $\ge 3$, Initiator $\ge 2$, Support $\ge 3$).
  - Ignores the obsolete Jungler role.

---

## Testing Decisions

### Good Test Principles
- Tests must verify external domain calculations and UI behaviors, never private state or internal map iterations.
- Unit tests must run fast and deterministically in pure Dart without disk I/O, network calls, or platform plugins.
- Widget tests must interact with screens through Riverpod provider overrides using in-memory fake repositories.

### Modules Under Test
1. **`DraftEngine` Unit Tests**:
   - Verify normalized Advantage calculations against a controlled 4-hero test matrix.
   - Verify arithmetic mean score aggregation when 0, 1, 3, and 5 enemy heroes are present.
   - Verify that already-picked allied and enemy heroes are excluded from candidate recommendations.
   - Verify Composition Diagnostic alerts fire when thresholds for Disabler, Durable, Initiator, and Support are unmet, and resolve when suitable heroes are added.
2. **`PatchHistoryRepository` & `MatchupMatrixRepository` Unit Tests**:
   - Verify correct deserialization of JSON fixtures into typed `MatchupMatrix` and `PatchDelta` domain models.
3. **Draft Screen Widget Tests**:
   - Verify initial empty state renders 5 empty allied slots, 5 empty enemy slots, and the full hero roster.
   - Verify tapping an enemy slot and selecting a hero updates the recommendation ranking.
   - Verify Position filter chips narrow the visible hero roster to the appropriate subset.
   - Verify "Reset Draft" clears all selections.
4. **Hero Detail Screen Widget Tests**:
   - Verify "Changed in [Patch]" chip appears on modified abilities and expands to show patch diff notes.
   - Verify the bottom Changelog card renders chronological patch notes.

### Prior Art
- Existing V1 repository unit tests (`test/features/heroes/hero_repository_test.dart`) and widget tests using Riverpod `ProviderContainer` overrides establish the pattern for mocking and dependency injection.

---

## Out of Scope

- **Player Profiles & Live Personal Statistics**: Permanently excluded due to privacy toggles, rate limits, and external backend requirements.
- **In-Game Objective Timers & Audio Alerts**: Deferred to a subsequent fast-follow release.
- **Steam Account Linking & Steam OpenID Auth**: Out of scope (app remains key-free and account-free).
- **Hero Item & Ability Builds**: Deferred to future meta feature exploration.
- **Live In-Match Memory Reading / Game State Integration**: Strictly prohibited to comply with anti-cheat safety and Companion App domain rules.
- **Disk Persistence for Active Drafts**: Drafts remain strictly in-memory during active sessions.

---

## Further Notes

- **Ubiquitous Language Compliance**: Specifications and code must use "Draft Picker", "Matchup Matrix", "Advantage", and "Composition Diagnostic", avoiding "Assistant", "Helper", or "Counter Tool".
- **ADR-0002 Compliance**: The app makes zero runtime network calls to OpenDota or third-party APIs. All matchup data is bundled at build time.
