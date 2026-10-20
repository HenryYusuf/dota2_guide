# 01: Walking skeleton

**What to build:** An app that launches into the Home tab and navigates cleanly: four bottom tabs (Home, Heroes, Items, Patches) with preserved state, dark-only theme, Riverpod + go_router established as the only state/routing mechanisms, feature-first folder structure (home / heroes / items / patches / about features plus a shared core layer), and a working test harness. Placeholder content per tab, clearly marked as placeholders.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] App launches to Home; bottom nav switches between all four tabs with preserved scroll/nav state
- [ ] Dark-only theme applied globally, no light-mode flicker on startup
- [ ] Feature-first structure established (four features + About stub + shared core layer)
- [ ] Riverpod and go_router are wired; no other state or navigation mechanism present
- [ ] Default scaffold counter demo and template clutter removed
- [ ] Widget smoke test renders the shell and switches tabs; test suite green
