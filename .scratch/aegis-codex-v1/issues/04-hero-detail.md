# 04: Hero detail

**What to build:** Tapping a Hero opens a complete reference page, fully offline from bundled per-Hero detail files: one continuous scroll with a collapsing header (portrait, name, primary attribute, complexity), then section cards — Attributes (base values and per-level gains), Combat stats, Abilities, Facets, Talents, Lore. Ability cards expand in place to show behavior tags, mana cost / cooldown / cast-range rows, the full description, a per-level value table derived from the feed's special values, visibly marked Innate Abilities, and Aghanim's Scepter / Shard enhancement text. Facets list each Facet with the abilities it changes; the Talent tree shows four tiers with two options each.

**Blocked by:** 03 (refresh & override infrastructure — detail files ride the shared store).

**Status:** ready-for-agent

- [ ] Snapshot tool emits per-Hero detail files from the official hero-detail feed; parsing test pins the schema against a real fixture
- [ ] Per-level value tables render from the feed's special values at the game's level steps
- [ ] Ability cards expand and collapse in place; innate abilities and Scepter/Shard enhancements are visually distinguished
- [ ] Facets section shows each Facet and its changed abilities
- [ ] Talent tree renders four tiers, two options per tier
- [ ] Grid-to-detail navigation works; detail reads via the override-preferred store (refreshed data wins)
- [ ] Lore section renders the Hero's biography
- [ ] Widget test renders the detail page from a fake repository, including an expanded Ability card with its per-level table
