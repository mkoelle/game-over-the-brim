# T-004: Vendor Phantom Camera v0.12

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 1h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Add Phantom Camera v0.12 to `addons/phantom_camera/` and enable it, with no
gameplay changes yet.

### Acceptance Criteria

- [x] `addons/phantom_camera/` contains the v0.12 release content, unmodified.
      *Five `.import` files were rewritten by the engine's own import to add
      `etc2_astc` (the project enables ETC2/ASTC). They are in a separate
      commit.*
- [x] The plugin is enabled in `project.godot`, and its
      `PhantomCameraManager` autoload is registered by the plugin.
      *Enabled through the `ProjectSettings` API with a throwaway script
      that mirrors the plugin's `_enable_plugin`. The headless editor does
      not run `EditorScript`s, and no GUI editor was used.*
- [x] `task ci` is green. The C# wrapper files cause no parse or import
      errors on the non-.NET editor.
- [x] `CHANGELOG.md` has an entry.

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

### Outcome (2026-11-25)

- v0.12 is still the latest release (checked with `gh api`). The pin is
  unchanged. The notes for T-005 are in ADR-013.
- The plugin registers one autoload, `PhantomCameraManager`. It is needed at
  runtime (it tracks cameras, hosts and noise). It coexists with `EventBus`,
  `GameConfig` and `_mcp_game_helper` (godot-ai).

### Assumptions (owner to validate)

- **Assumption:** The `ProjectSettings`-API enable is equivalent to ticking
  the plugin in the editor.
  **Evidence:** `plugin.gd:42-47` only calls `add_autoload_singleton`, which
  writes `autoload/PhantomCameraManager="*res://..."`. The resulting
  `project.godot` diff is that line plus the `editor_plugins` entry.
  **Owner check:** Open the project in the editor. Confirm Project Settings
  > Plugins shows Phantom Camera enabled, the bottom panel loads, and Output
  has no errors.
- **Assumption:** The Nunito fonts bundled in the addon are OFL-1.1.
  **Evidence:** Nunito is OFL-1.1 upstream, but the addon ships no font
  license (see `assets/CREDITS.md` open items).
  **Owner check:** Confirm, or exclude the fonts from exports.
