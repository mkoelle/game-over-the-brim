# T-014: Vendor ProtonScatter (`main@7198cc00078e`)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P3
**Status:** Blocked (1-Car Fun gate not passed)
**Estimate:** 3h
**Phase:** 3 — Track building ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-017](../adr/ADR-017-track-tooling-road-generator-and-scatter.md)

### Goal

Add ProtonScatter and use it to dress the test track with props along a
curve, verifying it on Godot 4.7.2.

### Acceptance Criteria

- [ ] `addons/proton_scatter/` (the folder name as shipped) is vendored
      from commit `7198cc00078e` and enabled. The SHA is recorded in
      ADR-017.
- [ ] One `ProtonScatter` node places cones along a corner of
      `test_track.tscn` in MultiMesh mode (no collision). A second places
      barrier instances that have collision.
- [ ] No errors on scene load, play or **quit** (upstream #261, "Error
      exiting game").
- [ ] F3 FPS is unchanged within noise.

### Context

- The last release tag (`4.0`, 2023) predates the 4.7 fix, which is on
  `main` as of 2026-07-26 ("fix compatibility issue with 4.7"). Pin by SHA.
- Uniform scaling only on colliding props (T-001 Jolt note), unless the
  2026-09-27 upstream change covers our case.

### Files Likely Affected

- `addons/proton_scatter/` (vendored)
- `project.godot`
- `scenes/arenas/test_track.tscn`

### Implementation Plan

1. Owner approval to vendor. Branch `chore/vendor-scatter`.
2. Re-check upstream `main` for newer 4.7 fixes. If there are any, choose
   the newer SHA and update ADR-017.
3. Fetch the archive into a fresh empty directory:
   `gh api repos/HungryProton/scatter/tarball/7198cc00078e > scatter.tgz`.
   Extract it and copy only the addon folder.
4. Enable the plugin. List any autoloads it adds and check them against
   the AGENTS.md Autoload Policy (note the result in ADR-017).
5. Add the two scatter nodes, using T-011 props if merged, otherwise
   primitive meshes.
6. Play, then quit, and check Output for errors.
7. `task ci`.

### Verification

Run F5: props are placed, driving into the barriers collides, and quitting
leaves no errors in Output.

### Dependencies

- T-011 (for real props; primitives are acceptable if T-011 has not landed)
