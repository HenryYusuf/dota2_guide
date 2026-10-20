# 09: Home — news & latest patch card

**What to build:** Home becomes the current-version dashboard: a latest-Patch card that reflects the current game version and taps through into the Patches tab, a Valve news list fetched from the official news feed filtered to Valve's own announcements (cached for 24 hours), quick entries into Heroes and Items, and a small inline retry when the news load fails — with the rest of Home fully usable offline.

**Blocked by:** 08 (patches — the latest-Patch card sources the patches data).

**Status:** ready-for-agent

- [ ] News repository fetches official Dota 2 news filtered to Valve's own announcements, with a 24 h cache
- [ ] Latest-Patch card shows the current Patch from the patches data and navigates into its detail
- [ ] News items render title, date, and open externally
- [ ] Quick entries navigate to Heroes and Items tabs
- [ ] Failed news load shows a small inline retry; Home never shows a full-screen error
- [ ] Repository and widget tests follow the established pattern
