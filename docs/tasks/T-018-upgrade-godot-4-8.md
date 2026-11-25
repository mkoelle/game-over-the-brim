# T-018: Upgrade to Godot 4.8 Stable

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Blocked (4.8 stable not released; 4.8-beta5 shipped 2026-11-24)
**Estimate:** 3h
**Phase:** Maintenance ([plan](../plans/addon-adoption-plan.md))

### Goal

Move the project from Godot 4.7.2 to 4.8 stable once it ships **and** the
vendored addons support it. Do the upgrade in one PR that bumps every
version pin together.

### Acceptance Criteria

- [ ] `mise.toml` (`godot`), `release.yml` (`GODOT_VERSION` and the
      `barichello/godot-ci` image tag) and `project.godot`
      (`config/features`) all name 4.8. `task check:versions` passes.
- [ ] Every vendored addon is on a release that states 4.8 support. The
      GDExtension ones (Debug Draw 3D, and LimboAI if adopted by then)
      pass the [ADR-015](../adr/ADR-015-native-gdextension-addon-policy.md)
      export check again.
- [ ] The 4.8 breaking changes below are checked against the project, and
      the result is noted in the PR.
- [ ] `task ci` is green, and `task export` works for all four platforms.

### Context

From the 4.8-beta1 notes (2026-10-15), the items relevant to this project:

- **GDScript:** strings used as comments are disallowed (GH-121833), and a
  script may no longer inherit its own inner classes (GH-121171).
- **Input:** "Ignore joypads on unfocused window" is now on by default
  for **new** projects (GH-120399). Ours is an existing project, so the
  setting must stay **off**. The multi-window presenter/operator setup
  (ADR-006) moves focus to another window while players drive. Check this
  explicitly after the upgrade.
- **Network:** mbedTLS 4.1.0. Re-test with netfox when it is adopted.
- **Core:** using the local debugger in release exports now fails.
- **Export:** options without `PROPERTY_USAGE_STORAGE` are no longer
  serialized. Diff `export_presets.cfg` after opening the project in 4.8.
- **New, useful:**
  - a native `Trail3D` node (GH-117107) for drift and steam trails
  - non-allocating physics queries (`intersect_ray_into`,
    `cast_motion_into`), which fit the AGENTS.md "no allocations in
    `_process`" rule
  - Jolt 5.6.0
  - the editor can download and manage the Android and Java SDKs itself
    (GH-121849), which may replace the manual Android CLI setup

### Files Likely Affected

- `mise.toml`, `.github/workflows/release.yml`, `project.godot`
- Vendored addons, only for version bumps (each one per AGENTS.md
  Boundaries)

### Implementation Plan

1. Wait for 4.8 stable. Check it with
   `gh api repos/godotengine/godot/releases/latest`.
2. Check each vendored addon's releases and Asset Store page for 4.8
   support. If any lacks it, leave this ticket Blocked and name the
   blocker.
3. Branch `chore/godot-4-8`. Bump all pins together.
   `barichello/godot-ci:4.8` must exist on Docker Hub first.
4. Open the project in 4.8 and let it upgrade. Review the `project.godot`
   and `export_presets.cfg` diff.
5. Run `task ci`, then `task export`. Launch the desktop build and the
   Android build, using the T-006 hardware path.
6. Check the input focus setting stays off (see Context).
7. Record the results in the PR, and in ADR-007 if the pipeline changed.

### Verification

`task ci` is green and all four exports launch on 4.8.

### Dependencies

- 4.8 stable released, plus addon support (external).
