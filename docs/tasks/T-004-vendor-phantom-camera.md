# T-004: Vendor Phantom Camera v0.12

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Todo
**Estimate:** 1h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Add Phantom Camera v0.12 to `addons/phantom_camera/` and enable it, with no
gameplay changes yet.

### Acceptance Criteria

- [ ] `addons/phantom_camera/` contains the v0.12 release content, unmodified.
- [ ] The plugin is enabled in `project.godot`, and its
      `PhantomCameraManager` autoload is registered by the plugin.
- [ ] `task ci` is green. The C# wrapper files cause no parse or import
      errors on the non-.NET editor.
- [ ] `CHANGELOG.md` has an entry.

### Context

- v0.12 was released 2026-11-17. It requires Godot 4.4+ and uses the 4.6+
  editor dock. Verified 2026-11-24.
- The `PhantomCameraManager` autoload is an accepted exception (ADR-013).
- Vendoring requires owner approval (AGENTS.md Boundaries). Approving this
  ticket grants it for this addon and version only.

### Files Likely Affected

- `addons/phantom_camera/` (vendored)
- `project.godot`
- `CHANGELOG.md`

### Implementation Plan

1. Branch `chore/vendor-phantom-camera`.
2. Re-verify the pin:
   `gh api repos/ramokz/phantom-camera/releases/latest --jq .tag_name`.
   If it is newer than v0.12, read its notes and update ADR-013 before
   continuing.
3. Download the v0.12 release archive. Copy **only**
   `addons/phantom_camera/` into the repo.
4. Open the editor and enable it under **Project → Project Settings →
   Plugins → Phantom Camera**. Confirm the `PhantomCameraManager` autoload
   appears and the Phantom Camera bottom panel loads.
5. `task import && task ci`. Expect `gdscript-formatter` (fmt and lint) to ignore
   `addons/` (Taskfile `GD_PATHS` is `scripts/ test/`).
6. Add a `CHANGELOG.md` line under Unreleased.

### Verification

`task ci` is green, and the editor shows the Phantom Camera panel with no
errors in Output.

### Dependencies

None.
