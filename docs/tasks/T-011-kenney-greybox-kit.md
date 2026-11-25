# T-011: Import Kenney Greybox Kit into the Test Track

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Done
**Estimate:** 3h
**Phase:** 2 — Assets ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md)

### Goal

Replace some of the hand-made boxes in `test_track.tscn` with readable
greybox props: barriers, cones and a ramp from Kenney's CC0 Racing Kit.
This makes speed and corner reading more realistic during feel testing,
with no art cost.

### Acceptance Criteria

- [x] Only the used Racing Kit models are imported under
      `assets/art/tracks/kenney_racing_kit/`. *The kit ships glTF
      (`.gltf` + `.bin`), not GLB. Files are kept as shipped, per ADR-019
      rule 3.*
- [x] Each prop has simple collision: box or convex shapes, not trimesh,
      except for the ramp surface. Collision is on layer 1 (Track).
      Scaling is uniform only (Jolt, T-001).
- [x] `test_track.tscn` uses the props. The existing collision layout
      (walls, mid-field obstacle, ramp) stays drivable.
- [x] Each file is listed in `assets/CREDITS.md` with `placeholder: yes`.

### Context

- Kenney Racing Kit is CC0. Imported version: 1.2 (the latest on both
  OpenGameArt and kenney.nl as of 2026-11-25). kenney.nl's download endpoint
  refuses scripted requests, so the zip came from Kenney's own upload on
  OpenGameArt: <https://opengameart.org/content/racing-kit> (published
  2017-04-18, CC0). Its `License.txt` is Kenney's CC0 text and ships in
  the pack folder.
- `.import` files ARE committed (PR #5, asset-organization.md). They hold
  the import scale and the UIDs.
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

### Result (2026-11-25)

Imported (glTF, import scale 8): `barrierWall`, `barrierRed`, `pylon`,
`roadRampLong`. Wrapper scenes sit next to them.

- Inner walls A and B, both end caps: now `barrierWall` and `barrierRed`
  runs. Each run keeps its old centre line and length (34 m and 12 m).
  The end caps are 1 m shorter than before (12 m, was 13 m); the overlap
  with the inner walls remains. Boundary walls stay CSG (3 m high).
- Ramp: `roadRampLong` replaces the 15 degree CSG ramp. Convex wedge
  collision. `Ramp2` (30 degrees) stays CSG: the kit has no 30 degree ramp.
- New: four pylons as a slalom at (-6,18), (-12,24), (-6,30), (-12,36).
- No tire stack: the Racing Kit has none. Pylons (cones) and barriers only.
- Wall height drops from 3 m to 1.05 m on the replaced walls. The car is
  1 m high, so a wall still blocks it on the ground.

Ramp, measured with ray casts on layer 1 at x = -25 (Jolt):

| | Before (CSG) | After (Kenney) | Change |
| --- | --- | --- | --- |
| Height at z = -25 | 0.473 m | 0.442 m | -0.03 m |
| Height at z = -13 | 3.688 m | 3.562 m | -3.4% |
| Slope | 0.2679 (15.0 deg) | 0.2600 (14.6 deg) | -2.9% |
| Car rest height on crest, crawl probe | 4.43 m | 4.31 m | -2.7% |
| Launch peak, 24 m/s ramp probe | 8.592 m | 8.577 m | -0.2% |
| Air runs after launch | 37, 77 frames | 36, 77 frames | same |

Probe evidence (headless, Jolt, 60 Hz; `t001_probe.gd` plus T-011 routes).
Files: `$SCRATCH/t011/probe_before_full.txt`, `probe_after_full.txt`,
`probe_before_ctl.txt`.

- No NaN in any route, before or after. No floor flicker anywhere.
- Original T-001 routes (wall slides, ramp, incline stop, seam crawl, drift):
  identical to before within noise (for example `drift_into_walls`
  stuck_frames 506 and 506; incline creep 0.0000 and 0.0000).
- Wall-slide seams: the 20 degree slide along inner walls A and B dips
  to 0.81 to 1.35 m/s at a seam (before: 1.87 m/s flat) and recovers to
  1.7 to 1.87 m/s within the run. A 5 degree approach stops the car,
  before and after alike, by the T-001 wall rules.
- Pylons: head-on, glancing and angled hits stop or slide exactly like a
  CSG box of the same size placed at the same spot (control run).
- Step cost: 160 to 210 microseconds per physics tick, same band as
  before (150 to 250).
- Running `main.tscn` (non-headless, vsync-bound ~94 FPS both): physics
  1.56 ms before, 1.73 ms after in the default view. Draw calls 35 to 57,
  objects 35 to 104 in the default view. The props are instanced scenes
  that share meshes.

Screenshots: `$SCRATCH/t011/before_default.png`, `after_default.png`,
`after_ramp.png`, `after_slalom.png`, `after_walls.png` (and `before_*`).

### Assumptions (owner to validate)

- **Assumption:** An import scale of 8 (one uniform factor) fits the car.
  **Evidence:** `roadRampLong` at 8 is exactly 8 m x 16 m and 15 degrees,
  the old ramp footprint. Barriers become 1.05 m high and 0.98 m thick,
  vs a 1 m high car. **Owner check:** drive past a barrier and a cone in
  `main.tscn`; confirm they read as the right size.
- **Assumption:** Kenney's glTF files are used as shipped (`.gltf` +
  `.bin`) and not converted to GLB. **Evidence:** ADR-019 rule 3 says keep
  original names; the pack has no GLB. **Owner check:** none needed unless
  you want a single-file format.
- **Assumption:** Lower walls (1.05 m, was 3 m) are acceptable for the
  inner walls and end caps. **Evidence:** probes show they stop and slide
  the car like before; the boundary walls stay 3 m. **Owner check:** at
  the ramp's 30 degree jump (`Ramp2`), confirm the car does not hop an
  inner wall.
- **Assumption:** Pylon collision is a box over the base footprint
  (0.96 x 1.056 x 0.96 m), not a cone. **Evidence:** control run with a CSG
  box matches the pylon probes. **Owner check:** clip a pylon's top
  edge; confirm the box corner feels fair.
- **Assumption:** The floor grid change is not included. **Evidence:**
  `uv1_scale` 0.25 shows only a faint grid (screenshot `uv025.png`); the
  light texture has too little contrast at any tile size. **Owner check:**
  Prefer swapping `dev_grid.png` for Kenney's darker prototype texture in
  a later ticket, then judge speed readability by feel.
- **Assumption:** Mixed barrier lengths (8 m plus 2 m pieces) are fine
  seams. **Evidence:** seam dips above are small and recover. **Owner
  check:** slide along the inner walls at an angle and note any bump.
