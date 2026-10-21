# 02: Draft Shell, Matchup Matrix Pipeline & Initial Draft Screen

**What to build:** The app navigation shell is expanded to 5 tabs with the addition of the "Draft" tab in the bottom bar, routing to an initial Draft screen. An independent CLI tool compiles the pairwise hero Matchup Matrix from OpenDota into a bundled asset. A dedicated repository interface loads this matrix in memory and serves it to the Draft screen, which displays an initial 5v5 draft layout with heroes ranked by baseline win rate.

**Blocked by:** None (can start immediately)

**Status:** ready-for-human

- [x] An independent snapshot script fetches pairwise hero matchup data from OpenDota with rate throttling and compiles a bundled JSON matchup matrix.
- [x] A dedicated repository interface exposes the precomputed matchup matrix, backed by the bundled asset.
- [x] The app shell navigation bar and declarative router are updated with the 5th "Draft" destination.
- [x] Navigating to the Draft tab renders a baseline 5v5 draft screen with 5 allied slots, 5 enemy slots, and the hero roster.
- [x] In the absence of draft selections, the hero roster is sorted by baseline win rate.
- [x] Repository and screen tests verify that the 5th tab navigates correctly and loads the matrix without network calls.
