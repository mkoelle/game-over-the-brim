# T-026: Adopt the "Full Throttle" App Icon

**Assignee:** Claude (Opus)
**Date:** 2026-11-25
**Priority:** P3
**Status:** Done
**Estimate:** 1h
**Phase:** FC-1 close-out
**ADR:** [ADR-007](../adr/ADR-007-build-test-and-release-pipeline.md)

### Goal

Use concept "b" as the app icon for now, and keep concepts "b" and "d".
This was the owner's choice after T-025.

### Acceptance Criteria

- [x] `icon.svg` is concept 02, Full Throttle.
- [x] The Windows `.ico`, macOS `.icns` and Android launcher icons are
      regenerated from it, by a repeatable `task icons`.
- [x] Only concepts 02 and 04 remain in `docs/design/icon-concepts/`.
- [x] A Windows export embeds the new icon.
- [x] `task ci` is green.

### Context

- `tools/make_icons.gd` writes the ICO (PNG entries at 16-256 px) and the
  ICNS (PNG entries at 16-1024 px) itself, using only Godot. It replaces
  the earlier Pillow step from ADR-007.
- `tools/` has a `.gdignore`, so the tool never ships in a build.
  `tools/` is in the formatter and lint paths.
- The Android adaptive foreground is `icon.svg` without its
  `id="background"` disc, scaled into the 66/108 safe zone. The adaptive
  background is the disc's teal (`#1f6f78`). The previous foreground was
  the whole round icon, scaled down.

### Verification

- `iconutil -c iconset` decodes the generated `.icns` into 10 sizes, up
  to 1024 px. `icp6` was dropped because iconutil reads it as 48 px.
- `file` reports the `.ico` as 7 PNG icons, 16-256 px.
- In a Windows export, `pefile` finds 6 RT_ICON entries in
  `OverTheBrim.exe`, all PNG. That matches ADR-007's earlier check. The
  export exited 134 after writing: this is the known macOS MoltenVK
  shutdown crash.
- The adaptive foreground was checked visually: the art is centred, with
  a transparent background.

### Dependencies

- T-025.

### Assumptions (owner to validate)

- **Assumption:** "b" and "d" mean the second and fourth concepts. The
  concepts are numbered 1-8, not lettered.
  **Evidence:** That is the alphabet order of the eight concepts.
  **Owner check:** If you meant different ones, say which numbers, and
  run the switch steps in `docs/design/icon-concepts/README.md`.
