# 02: Heroes grid from bundled snapshot

**What to build:** The Heroes tab shows the real Hero roster entirely offline. A snapshot tool fetches the official hero-list datafeed once and emits an English Hero index file (id, Valve key name, localized name, primary attribute, complexity, portrait URL) into bundled assets; the app renders a portrait grid with primary-attribute filter chips (Strength / Agility / Intelligence / Universal), a complexity filter, and name search. Portrait images stream from the Valve CDN at runtime and are never bundled.

**Blocked by:** 01 (walking skeleton).

**Status:** ready-for-agent

- [ ] Snapshot tool fetches the official hero-list feed and emits an app-schema English index file; accepts a locale flag for future languages
- [ ] Hero index model parses the real emitted fixture; parsing test pins the schema and fails on drift
- [ ] Heroes tab renders the portrait grid from the bundled asset with no network on first launch
- [ ] Attribute chips and complexity filter narrow the grid; name search matches against localized names
- [ ] Portraits load from the Valve CDN at runtime; no Valve media in the asset bundle
- [ ] Repository test covers the asset-first read path with a fake loader
- [ ] Widget test covers grid, filters, and search over a fake repository
