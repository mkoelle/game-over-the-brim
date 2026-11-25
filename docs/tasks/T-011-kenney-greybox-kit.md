# T-011: Import Kenney Greybox Kit into the Test Track

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Estimate:** 3h
**Phase:** 2 — Assets ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md)

### Goal

Replace some of the hand-made boxes in `test_track.tscn` with readable
greybox props: barriers, cones and a ramp from Kenney's CC0 Racing Kit.
This makes speed and corner reading more realistic during feel testing,
with no art cost.

### Acceptance Criteria

- [ ] Only the used Racing Kit models are imported, as GLB, under
      `assets/art/tracks/kenney_racing_kit/`.
- [ ] Each prop has simple collision: box or convex shapes, not trimesh,
      except for the ramp surface. Collision is on layer 1 (Track).
      Scaling is uniform only (Jolt, T-001).
- [ ] `test_track.tscn` uses the props. The existing collision layout
      (walls, mid-field obstacle, ramp) stays drivable.
- [ ] Each file is listed in `assets/CREDITS.md` with `placeholder: yes`.

### Context

- Kenney Racing Kit is CC0. Check the current version on kenney.nl at
  import time.
- `.import` files are not committed (asset-organization.md).
- Performance: props should be instanced scenes or a MultiMesh, never
  unique mesh copies.

### Files Likely Affected

- `assets/art/tracks/kenney_racing_kit/` (new; imported models)
- `scenes/arenas/test_track.tscn`
- `assets/CREDITS.md`

### Implementation Plan

1. Branch `feature/greybox-kit`.
2. Download the Racing Kit and pick about 5–8 models: a barrier straight,
   a barrier corner, a cone, a ramp and a tire stack. Copy only those GLBs
   into the pack folder, keeping their original names (ADR-019 rule 3).
3. For each model, create an inherited scene or wrapper scene with a
   `StaticBody3D`, a hand-sized `BoxShape3D` or `ConvexPolygonShape3D`,
   `collision_layer = 1` and `collision_mask = 0`. Save it next to the
   GLB as `snake_case.tscn`.
4. In `test_track.tscn`, swap some walls and obstacles for prop instances.
   Keep the ramp's angle and height close to the current one, so feel
   notes stay comparable.
5. Add the CREDITS entries.
6. `task ci`.

### Verification

Run F5 and drive the manual-testing route: no clipping or snagging on
props, and the F3 FPS is unchanged from before.

### Dependencies

- T-010
