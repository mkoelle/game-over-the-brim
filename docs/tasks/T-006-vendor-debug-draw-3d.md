# T-006: Vendor Debug Draw 3D v1.7.3 (ADR-015 Checks)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md), [ADR-015](../adr/ADR-015-native-gdextension-addon-policy.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Add Debug Draw 3D as a dev-only native addon. Prove it passes the ADR-015
native-addon checklist, and decide how release builds treat it.

### Acceptance Criteria

- [ ] `addons/debug_draw_3d/` contains the v1.7.3 release content, unmodified.
- [ ] All seven ADR-015 checks are recorded in ADR-016 (pass/fail plus a note).
- [ ] `.gitattributes` marks `*.dll`, `*.so`, `*.dylib`, `*.framework/**`
      and `*.aar` as `binary`.
- [ ] Release-build behavior is decided and implemented: either the release
      library is inert, or an export filter excludes the addon (and, in
      T-007, the debug component).
- [ ] `task ci` is green, and `task export` succeeds for all four platforms.

### Context

- v1.7.3 was released 2026-04-04 under MIT. The README lists Windows,
  Linux, macOS, Android 5.0+, iOS and Web.
- Known 4.7 issue #112: `DebugDraw2D.set_text` is broken in the **editor**
  for `@tool` scripts. Runtime is not affected.
- The release workflow ad-hoc signs macOS builds (commit `59cb630`). The
  extension's dylib inside the `.app` must survive this.

### Files Likely Affected

- `addons/debug_draw_3d/` (vendored)
- `.gitattributes`
- `export_presets.cfg` (only if an exclude filter is needed)

Plus a doc update: the ADR-016 checklist results.

### Implementation Plan

1. Branch `chore/vendor-debug-draw-3d`.
2. Re-verify the pin with `gh api` against
   `DmitriySalnikov/godot_debug_draw_3d` releases. Download
   `debug-draw-3d_1.7.3.zip`; per the README, use this asset rather than
   the source archive for versions ≥ 1.4.5. Copy `addons/debug_draw_3d/`.
3. Add the `.gitattributes` binary lines before `git add`, so the binaries
   are never text-normalized.
4. ADR-015 checklist:
   1. **Platforms:** list the library files in the `.gdextension` manifest
      for Windows x86_64, Linux x86_64, macOS and Android arm64.
   2. **Engine:** `task import && task ci` on 4.7.2.
   3. **License:** MIT. Confirm `LICENSE` is present in the vendored folder.
   4. **Export:** run `task export`, then launch the builds on the
      owner's hardware:
      - the macOS `.app` (ad-hoc signed) from Finder
      - the Windows or Linux build on the second machine
      - the Android APK, with `adb install -r build/android/*.apk`, then
        launch it on the device

      Each one must reach the test track with no extension-load error.
   5. **Git:** record the vendored size (`du -sh addons/debug_draw_3d`).
   6. **Dev-only:** check whether the release-template library exists and
      no-ops. Read the addon's docs and the `.gdextension` entries.
      - If it no-ops in release, there is nothing to do.
      - If it does not, add an `exclude_filter` for `addons/debug_draw_3d/*`
        to every preset in `export_presets.cfg`. Confirm the export has no
        missing-extension error. Add `scripts/vehicles/vehicle_debug_draw.gd`
        to the same filter in T-007.
   7. **Pure-GDScript alternative:** none equal; see ADR-016 alternatives.
5. Record the results in ADR-016 under a new "ADR-015 checklist results"
   section.

### Verification

`task export` produces all four builds, and the host-OS desktop build
launches to the test track with no extension errors in its log.

### Dependencies

None.
