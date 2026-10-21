# 03: Bilateral Draft Board & Real-Time Counter Recommendations

**What to build:** Players can interactively tap any of the 5 enemy or 5 allied slots on the Draft screen to assign or clear heroes. When enemy heroes are assigned, the calculation engine dynamically re-ranks the remaining hero roster in real time using the arithmetic mean of normalized Advantage scores against all selected enemies. Assigned heroes are locked out of recommendations. A prominent "Reset Draft" button clears all selections instantly. State is maintained purely in memory during the app session.

**Blocked by:** 02: Draft Shell, Matchup Matrix Pipeline & Initial Draft Screen

**Status:** ready-for-agent

- [ ] A pure-Dart calculation engine implements the normalized Advantage formula and arithmetic mean aggregation for multiple enemy picks.
- [ ] An in-memory state notifier manages draft selections (allied and enemy slots) with actions to assign, clear, and reset slots.
- [ ] Tapping an empty slot on the draft board focuses it, and tapping a hero in the candidate roster assigns that hero to the slot.
- [ ] Selected enemy heroes cause the candidate roster to immediately re-order by descending Advantage score, showing percentage badges (+X.X% / -X.X%).
- [ ] Assigned heroes (allies and enemies) are visually marked and excluded from selection as candidate counter picks.
- [ ] A "Reset Draft" action resets all 10 slots to empty and restores baseline ranking.
- [ ] Unit tests verify Advantage calculation math and exclusion logic; widget tests verify selection and re-ranking interactions.
