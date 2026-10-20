# 06: Items list & detail

**What to build:** The Items tab works fully offline from bundled per-Item snapshot files. The list is grouped by shop category with neutral Items filterable by tier and searchable by name. Tapping an Item opens a detail page showing total cost, combination cost, attributes, and active/passive effect text. The Items repository rides the same override-preferred store and refresh pattern established for Heroes.

**Blocked by:** 03 (refresh & override infrastructure — the shared store pattern).

**Status:** ready-for-agent

- [ ] Snapshot tool emits an Item index plus per-Item detail files from the official item feed; parsing tests pin both schemas against real fixtures
- [ ] List renders grouped by shop category; neutral Items filter by tier; name search works
- [ ] Detail page shows total cost, combination cost, attributes, and active/passive effect text
- [ ] Items repository uses the shared override-preferred store and refresh pattern (no bespoke persistence)
- [ ] Repository tests and widget tests follow the pattern set by the Heroes tickets
