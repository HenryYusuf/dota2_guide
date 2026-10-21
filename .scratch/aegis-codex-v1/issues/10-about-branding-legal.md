# 10: About, branding & legal

**What to build:** The app presents itself correctly and is legally presentable: an About screen carrying the "Unofficial â€” not affiliated with Valve Corporation" disclaimer, source attributions (Valve datafeeds for reference data, the Steam CDN for icons and videos, the official Steam news feed), and a "last updated" line driven by the refresh manifest. The app displays as "Aegis Codex â€” Dota 2 reference" with package id com.henry.dota2guide and an original placeholder launcher icon (no Valve art). About is reachable from a top-bar menu on Home.

**Blocked by:** 03 (refresh & override infrastructure â€” the manifest feeding "last updated") and 09 (home â€” the top-bar host).

**Status:** ready-for-agent

- [x] About screen shows the disclaimer, all source attributions, and a "last updated" line sourced from the refresh manifest
- [x] App display name and package id set as decided
- [x] Launcher icon is original placeholder art; no Valve logo, screenshot, or trademark art anywhere in the app or icon set
- [x] Top-bar menu on Home opens About
- [x] Widget test renders About including the "last updated" line
