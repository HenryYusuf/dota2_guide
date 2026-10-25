# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Aegis Codex (Dota 2 Companion)  
**Updated:** 2026-10-25  
**Category:** Esports / Tactical Companion  
**Theme:** Dark-only (Obsidian Slate & Dota Crimson)

---

## Global Rules

### Color Palette

| Role | Hex | Flutter Token | Usage |
|------|-----|---------------|-------|
| Scaffold Background | `#0C0F17` | `AppTheme.scaffoldBackground` | Deep obsidian slate base background |
| Surface (Card) | `#141A24` | `AppTheme.surface` | Standard cards and containers |
| Surface Elevated | `#1B2332` | `AppTheme.surfaceElevated` | Interactive cards, input fields, modals |
| Surface Highlight | `#263248` | `AppTheme.surfaceHighlight` | Active states, hover, leading badges |
| Primary Accent | `#E53935` | `AppTheme.primary` | Dota crimson brand accent |
| Primary Glow | `rgba(229, 57, 53, 0.2)` | `AppTheme.primaryGlow` | Glow rings and subtle overlays |
| Gold Accent | `#F59E0B` | `AppTheme.gold` | Aegis / Shop gold badges and highlights |
| Gold Light | `#FBBF24` | `AppTheme.goldLight` | Tier 5 / Mythic highlights |
| Text Primary | `#F8FAFC` | `AppTheme.textPrimary` | Primary headers, labels, hero titles |
| Text Secondary | `#94A3B8` | `AppTheme.textSecondary` | Subtitles, descriptions, muted stats |
| Text Muted | `#64748B` | `AppTheme.textMuted` | Rank numbers, placeholders, borders |
| Border | `#222B3B` | `AppTheme.border` | Container boundaries and outlines |
| Border Light | `#334155` | `AppTheme.borderLight` | Focused or interactive borders |

### Faction & Attribute Colors

| Role | Hex | Flutter Token | Usage |
|------|-----|---------------|-------|
| Radiant | `#38BDF8` | `AppTheme.radiant` | Radiant ally indicators |
| Dire | `#F43F5E` | `AppTheme.dire` | Dire enemy indicators |
| Strength | `#EF4444` | `AppTheme.strength` | Strength attribute ruby red |
| Agility | `#10B981` | `AppTheme.agility` | Agility attribute emerald green |
| Intelligence | `#0EA5E9` | `AppTheme.intelligence` | Intelligence celestial cyan |
| Universal | `#A855F7` | `AppTheme.universal` | Universal amethyst purple |

---

### Typography

- **System Font:** High-legibility system sans-serif (Inter / Roboto)
- **App Bar & Headlines:** 20px, `FontWeight.w700`, letterSpacing: 0.3
- **Card Titles:** 15–18px, `FontWeight.w700`–`w800`
- **Body Text:** 13–14px, `FontWeight.w400`–`w500`
- **Badges & Overlines:** 10–12px, `FontWeight.w700`–`w800`, letterSpacing: 0.5–1.2

---

### Spacing & Metrics

| Token | Value | Usage |
|-------|-------|-------|
| `--space-xs` | `4px` | Inline gaps, badge padding |
| `--space-sm` | `8px` | Icon gaps, tight padding |
| `--space-md` | `12px`–`14px` | Standard card margins |
| `--space-lg` | `16px` | Screen and container padding |
| `--space-xl` | `24px` | Major section spacing |

---

### Component Specs & Border Radii

- **Standard Cards:** `14px` (`BorderRadius.circular(14)`)
- **Featured / Hero Cards:** `16px` (`BorderRadius.circular(16)`)
- **Inputs & Search Bars:** `12px` (`BorderRadius.circular(12)`)
- **Modals & Dialogs:** `18px` (`BorderRadius.circular(18)`)
- **Filter Chips:** `10px` (`BorderRadius.circular(10)`)
- **Draft Slots & Avatars:** `8px` (`BorderRadius.circular(8)`)

---

## Anti-Patterns (Do NOT Use)

- ❌ Light mode or light scaffolds (Aegis Codex is strictly dark-only).
- ❌ Generic neon purple or non-Dota color palettes.
- ❌ Emojis as icons — Use Material SVG icons (`Icons.shield`, `Icons.bolt`, `Icons.auto_awesome`).
- ❌ Hardcoded bright white backgrounds.
- ❌ Layout-shifting hovers or uncached remote network images.

---

## Pre-Delivery Checklist

Before delivering any UI code, verify:
- [ ] Uses tokens from `AppTheme` exclusively (no hardcoded ad-hoc Hex colors).
- [ ] Dark theme only (`ThemeMode.dark` forced with obsidian scaffold).
- [ ] Responsive across phone and tablet breakpoints.
- [ ] Contrast ratio at least 4.5:1 against slate/obsidian surfaces.
- [ ] Accessible touch targets (minimum 44x44px).
