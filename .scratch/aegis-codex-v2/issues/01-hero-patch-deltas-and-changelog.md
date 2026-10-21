# 01: Hero Patch Deltas & Historical Changelog

**What to build:** When a player inspects any Hero Detail screen, modified Ability cards display a distinct "Changed in [Patch]" chip. Tapping the chip or expanding the ability reveals an inline diff of the recent patch notes alongside ability stats. At the bottom of the Hero screen, a chronological Changelog section aggregates all stat, ability, and talent changes for that hero across the last 5 gameplay balance patches. This functionality works 100% offline from bundled patch data without network requests.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] The build-time snapshot pipeline inverts recent patch notes (last 5 patches) into a bundled patch history dataset indexed by hero ID.
- [ ] A dedicated repository interface provides typed patch delta records per hero, backed by the bundled asset.
- [ ] Ability cards on the Hero Detail screen identify whether an ability was modified in recent patches and render a visual patch chip.
- [ ] Expanding an affected Ability card reveals the exact historical patch notes and numerical changes.
- [ ] A collapsible or card-based "Changelog" section at the bottom of the Hero screen displays chronological patch notes for stats, talents, and abilities.
- [ ] Widget and unit tests verify correct delta extraction, badge rendering, and changelog presentation without network calls.
