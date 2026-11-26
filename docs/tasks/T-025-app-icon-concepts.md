# T-025: App Icon Concepts

**Assignee:** Claude (Opus, ADR-022 FC-1 feedback)
**Date:** 2026-11-25
**Priority:** P3
**Status:** Done
**Estimate:** 2h
**Phase:** 1 — FC-1 feedback ([checklist](../plans/fc-1-owner-checklist.md) §4)

### Goal

Give the owner options for a better app icon. The owner asked for this
at FC-1: "feel free to generate a better one, this one is meh, create 8
samples with differing options, getting increasingly creative".

### Acceptance Criteria

- [x] Eight SVG concepts in `docs/design/icon-concepts/`, ordered from
      safe to more creative.
- [x] A contact sheet that shows each one at 256, 48, 32 and 16 px.
- [x] The drafts are not imported or exported by Godot (`.gdignore`).
- [x] `icon.svg` is unchanged. The owner picks, and a follow-up adopts it.

### Context

- The game identity comes from `docs/design/vehicles.md`: sentient,
  wheeled Victorian headwear with cartoon eyes. The archetypes are top
  hat, bowler, fez, sombrero and flat cap. The title pun is "over the
  brim".
- Every concept is original. Each uses one shared palette and only plain
  SVG shapes (one gradient in #8), which Godot's SVG importer renders.
  The contact sheet was rendered with `Image.load_svg_from_string` in
  Godot 4.7.2.
- After render review, three fixes went in:
  - Crowns on #1, #2, #4 and #5 now flare slightly toward the top, like
    a stovepipe. They had read as buckets.
  - #4's road band no longer pokes out of the rounded tile.
  - #6's stick-like trails are now dotted motion arcs.

### Files Likely Affected

- `docs/design/icon-concepts/*` (new)

### Verification

Open `docs/design/icon-concepts/contact-sheet.png`.

### Dependencies

None.

### Assumptions (owner to validate)

- **Assumption:** The same palette across all eight makes them easier to
  compare. It is also a reasonable starting brand palette (velvet red,
  gold, plum).
  **Evidence:** The vehicles doc lists velvet red and royal purple as
  hat colors.
  **Owner check:** Pick a favourite, or two to combine. Say if you want
  a different palette.
- **Assumption:** Small-size readability matters most, because the icon
  shows in the taskbar, the dock and the Android launcher.
  **Evidence:** The 16 px previews: #3 and #1 read best, while #4 and #6
  get busy.
  **Owner check:** Judge the 16-48 px row, not just the large row.
