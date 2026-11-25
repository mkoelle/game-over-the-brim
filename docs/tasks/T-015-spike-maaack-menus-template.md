# T-015: Spike Maaack's Menus Template v1.8.0

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P3
**Status:** Blocked (menus wait for the 1-Car Fun gate)
**Estimate:** 4h
**Phase:** 4 — Menus ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-018](../adr/ADR-018-menu-framework-maaack-menus-template.md)

### Goal

Install the template, wire the menu flow around the existing test track,
and confirm it fits our architecture rules before committing to it.

### Acceptance Criteria

- [ ] The template core is vendored under `addons/` at v1.8.0. Its
      editable example scenes are copied to `scenes/ui/menus/` and
      `scripts/ui/menus/`.
- [ ] The flow works: launch → main menu → options (an audio volume change
      persists across restart) → Play loads `scenes/main.tscn` → pause →
      return to main menu → quit.
- [ ] Every autoload the template adds is listed in ADR-018 and judged
      against the AGENTS.md Autoload Policy.
- [ ] The input-remap screen calls `DeviceActionMap.rebuild()` after a
      rebind (ADR-014). Rebinding keyboard throttle changes what drives
      the car.
- [ ] The credits scene shows `assets/CREDITS.md` content, or the gap is
      documented.
- [ ] `test/integration/test_main.gd` still passes.

### Context

- v1.8.0 was released 2026-11-22. It targets Godot 4.7 and supports 4.4+.
- Template menus are UI layer only. They must not own race or tournament
  state (AGENTS.md).
- If `run/main_scene` changes to the menu, `test_main.gd` still loads
  `main.tscn` directly, so the gameplay smoke test is still valid. A menu
  smoke test can come later.

### Files Likely Affected

- `addons/maaacks_menus_template/` (vendored; the folder name as shipped)
- `scenes/ui/menus/` (copied examples)
- `project.godot`

### Implementation Plan

1. Owner approval to vendor. Branch `spike/maaack-menus`.
2. Re-verify the latest tag with `gh api` against
   `Maaack/Godot-Menus-Template`.
3. Install from the release archive. Run the template's setup or copy step,
   pointing the copied examples to `scenes/ui/menus/`. Move any scripts it
   copies into `scripts/ui/menus/` and fix the paths in the editor.
4. List new autoloads (`grep -A20 '^\[autoload\]' project.godot`).
5. Set the main menu's "Play" target to `res://scenes/main.tscn`. Add the
   pause menu to `main.tscn` per the template docs.
6. Find the remap screen's "binding changed" hook (signal or override
   point) and call `DeviceActionMap.rebuild()` there. If it requires
   editing copied example scripts, that is fine, because those are ours.
7. Point the credits scene at `assets/CREDITS.md`, if the template
   supports a configurable source file.
8. Record the findings in ADR-018. If any autoload holds gameplay state,
   or the template fights the per-device input model, record a drop
   decision instead.

### Verification

Walk the full menu flow in a desktop build or F5, including one keyboard
rebind followed by driving with the new key.

### Dependencies

- T-003 (`DeviceActionMap` in use)
- T-010 (CREDITS file)
