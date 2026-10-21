# 04: Composition Diagnostics & Competitive Position Filtering

**What to build:** As heroes are assigned to the allied team, the drafting screen provides real-time Composition Diagnostics evaluating team balance across four vital combat archetypes: Disabler (lockdown), Durable (frontline), Initiator, and Support. When a threshold is unmet, clear diagnostic alerts surface on the board. Additionally, players can filter the candidate hero roster by 5 competitive Positions (Pos 1: Safe Lane through Pos 5: Hard Support) to find the highest-advantage counter for their assigned farm priority and lane.

**Blocked by:** 03: Bilateral Draft Board & Real-Time Counter Recommendations

**Status:** ready-for-agent

- [ ] The calculation engine evaluates cumulative team role points across Disabler, Durable, Initiator, and Support from official hero role data.
- [ ] Visual diagnostic indicators display warning alerts when essential combat thresholds are missing (e.g. "Draft lacks reliable stuns/disable").
- [ ] The candidate roster includes horizontal Position filter chips (All, Pos 1, Pos 2, Pos 3, Pos 4, Pos 5) mapped from official role levels.
- [ ] Tapping a Position filter narrows the visible counter recommendations to heroes suitable for that competitive position while preserving Advantage sorting.
- [ ] Adding heroes that fulfill missing roles dynamically resolves the diagnostic warning alerts.
- [ ] Unit tests verify role threshold evaluation and position classification; widget tests verify filtering and alert updates.
