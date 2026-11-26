# T-006: Vendor Debug Draw 3D v1.7.3 (ADR-015 Checks)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Done
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md), [ADR-015](../adr/ADR-015-native-gdextension-addon-policy.md)
**Approval:** vendoring approved by the owner on 2026-11-24, at the latest release available at vendoring time ([plan](../plans/addon-adoption-plan.md#owner-decisions-2026-11-24)).

### Goal

Add Debug Draw 3D as a dev-only native addon. Prove it passes the ADR-015
native-addon checklist, and decide how release builds treat it.

### Acceptance Criteria

- [x] `addons/debug_draw_3d/` contains the v1.7.3 release content, unmodified.
- [x] All seven ADR-015 checks are recorded in ADR-016 (pass/fail plus a note).
- [x] `.gitattributes` marks `*.dll`, `*.so`, `*.dylib`, `*.framework/**`
      and `*.aar` as `binary`.
- [x] Release-build behavior is decided and implemented: either the release
      library is inert, or an export filter excludes the addon (and, in
      T-007, the debug component).
- [x] `task ci` is green, and `task export` succeeds for all four platforms.
      *`task export` has no Android step, so `task export:android` was run
      separately. One macOS run exited 134 (the known MoltenVK shutdown
      crash after the output was written). The Windows or Linux launch on a
      second machine and the Android device install are Pending owner; see
      Assumptions below.*

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

      Local Android prerequisites, set up 2026-11-24 (see ADR-007):
      - Android CLI (`android`, mise global tool `android-cli`).
        `sdkmanager` is deprecated.
      - SDK root `~/Library/Android/sdk`, with platform-tools, build-tools
        36.1.0, platform 36 and cmdline-tools/latest. These match Godot
        4.7.2's `targetSdk 36` / `buildTools 36.1.0`.
      - Godot 4.7.2 export templates installed.
      - A baseline `task export:android` already produced a working
        55.7 MB APK before this addon.

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

### Assumptions (owner to validate)

- **Assumption:** Release builds need no export filter, because the
  `template_release` library of Debug Draw 3D is inert. **Evidence:** a
  macOS release export of a probe project loads the extension and a
  `draw_box` call draws nothing, while the debug export draws it
  ([ADR-016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md#release-behavior)).
  **Owner check:** none needed unless you want release builds to carry
  zero native code. Then add `addons/debug_draw_3d/*` to every
  `exclude_filter`.
- **Assumption:** The Windows build loads the extension without error.
  *Pending owner.* **Evidence:** the export contains
  `libdd3d.windows.template_release.x86_64.dll` next to the `.exe`, and the
  manifest maps it for `windows.template_release.x86_64`. **Owner check:**
  run `task export:windows`, copy `build/windows/` (the `.exe`, `.pck` and
  `.dll`) to a Windows machine and run the `.exe` from a terminal with
  `--verbose`. The log must show no `GDExtension` error and no
  `Can't open dynamic library` line.
- **Assumption:** The Linux build loads the extension. *Pending owner.*
  **Evidence:** `build/linux/libdd3d.linux.template_release.x86_64.so` sits
  next to the binary. **Owner check:** run `task export:linux`, copy
  `build/linux/` to a Linux x86_64 machine, run
  `chmod +x OverTheBrim.x86_64 && ./OverTheBrim.x86_64 --verbose` and
  confirm there is no `Can't open dynamic library` error.
- **Assumption:** The Android APK loads the extension on arm64 devices.
  *Pending owner.* No device was attached (`adb devices` listed none).
  **Evidence:** the APK contains
  `lib/arm64-v8a/libdd3d.android.template_debug.arm64.so`. **Owner check:**
  run `task export:android`, then
  `~/Library/Android/sdk/platform-tools/adb install -r build/android/OverTheBrim.apk`,
  launch the app, then `adb logcat -d | grep -iE 'DD3D|GDExtension|libdd3d'`.
  Success is no `Can't open dynamic library` or `GDExtension` error.
- **Assumption:** The macOS build launched from Finder behaves like the
  command-line launch that was run. **Evidence:**
  `codesign --verify --deep --strict` passes and a probe `.app` exported
  with the same preset loaded the extension. **Owner check:** unzip
  `build/macos/OverTheBrim.zip`, open the app from Finder, and confirm it
  opens (a quarantine prompt is expected for ad-hoc signing).
- **Assumption:** Vendoring all upstream platform libraries (41 MB) is
  acceptable. **Evidence:** it is below the ADR-015 50 MB LFS threshold and
  the addon is vendored unmodified. **Owner check:** decide whether to trim
  the unused platforms (Web, iOS, arm32, x86) later.
