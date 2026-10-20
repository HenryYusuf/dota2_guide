# 07: Recipe tree

**What to build:** The Item detail page gains the Recipe tree: components rendered as indented rows with icon, name, and price; components that are themselves combined Items auto-expand one level deeper so there are never dead ends; every row taps through to that Item's detail page, letting a player plan a complete purchase order across several Items. A combined-cost row at the top stays consistent with the component prices shown.

**Blocked by:** 06 (items list & detail — the page it lives on).

**Status:** ready-for-agent

- [ ] Tree renders each component as icon + name + price, indented by depth
- [ ] Components with their own recipes expand one level deeper automatically
- [ ] Tapping any row navigates to that Item's detail page; back navigation returns to the original Item
- [ ] Top combined-cost row is consistent with the sum of displayed component prices
- [ ] Widget test renders a multi-level tree from a fake repository and verifies tap-through navigation
