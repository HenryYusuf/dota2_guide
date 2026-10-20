# 08: Patches

**What to build:** The Patches tab lists Patches (number, date, latest pinned) from a bundled index. Opening one shows its structured changes grouped by section, each group headed by tappable Hero/Item icons with names, and change lines rendered at their proper indentation. Tapping an entity icon opens that Hero's or Item's page. Patches beyond the bundled latest are fetched on demand, become permanently available offline once opened, and degrade to an inline retry when the fetch fails.

**Blocked by:** 04 (hero detail) and 06 (items list & detail) — entity icon jumps need both pages.

**Status:** ready-for-agent

- [ ] Snapshot tool emits the patch index and the latest Patch from the official patch feeds; parsing tests pin both schemas
- [ ] Patch list shows number and date with the latest pinned at top
- [ ] Patch detail groups changes by section; entity headers show icon and name; indent levels are respected
- [ ] Hero and Item icons in a Patch navigate to their detail pages
- [ ] Older Patches (not bundled) are fetched on demand; an opened Patch stays available offline thereafter
- [ ] A failed on-demand fetch shows an inline retry; the tab never shows a full-screen error
- [ ] Repository tests cover on-demand fetch, permanent cache, and failure path; widget tests cover list and detail
