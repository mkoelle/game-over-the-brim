# T-021: Solid Ramp2 Wedge (Camera Jumps Through the Ramp)

**Assignee:** Claude (Opus, ADR-022 camera-feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done (Ramp2 later reshaped to 20 degrees / 2.5 m in T-030)
**Estimate:** 2h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md)), FC-1 feedback
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

Stop the camera from jumping through the blue ramp (`Ramp2`). This was
FC-1 owner feedback
([checklist](../plans/fc-1-owner-checklist.md), camera): "camera can jump
through blue ramp when backing up into the base of the ramp".

### Acceptance Criteria

- [x] The cause is reproduced and measured.
- [x] `Ramp2` has no drivable gap under its high end. It is a solid wedge,
      and its top surface is unchanged: 30 degrees, 8 m high, same
      position.
- [x] Reversing into the ramp from the high-end side keeps the car in
      view. In every frame, the line from the car to the camera is clear,
      and the camera never jumps.
- [x] Driving up the ramp behaves exactly as before.
- [x] The geometry rule is written down
      ([track-geometry.md](../design/track-geometry.md)).
- [x] `task ci` is green. The new tests fail on the old slab.

### Context

- **Cause.** The old `Ramp2` was a `CSGBox3D` slab (8 x 1 x 16 m) tilted
  30 degrees, with an open underside. From the high-end side, a car can
  reverse under it, and it wedges where the gap gets too low (z = 6.26,
  speed 0). Phantom Camera's Third Person collision is a sphere shape
  cast. It starts at the pivot, which is the damped `follow_target +
  follow_offset` (`phantom_camera_3d.gd`, `_set_third_person_camera`). The
  wedged car puts the pivot (1.5 m above the floor) inside the slab, at
  the slab's underside, which is about 1.52 m high there. A shape cast does
  not report geometry it starts inside, so the camera goes to full spring
  length on the slab's far side. That is the ramp's top surface, 4.7 m
  away in one frame.
- **Why not a camera-side fix.** Lowering `follow_offset.y` under a
  ceiling does not move the cast start in time. The pivot has 0.2 s of Y
  damping, so under a 30-degree overhang at 20 m/s it lags about 2.4 m. A
  post-correction of the camera would mean fighting the addon every frame.
  Geometry the car cannot get into is the reliable fix. It also stops the
  car from wedging.
- **The low-end side was never the problem.** Reversing up the slope
  keeps the camera 0.25 m above the surface, which is the collision
  working. The builder's T-007 probe "stopped dead" at the same z = 6.3
  from the same gap.

### Files Likely Affected

- `scenes/arenas/test_track.tscn` (only the `Ramp2` node)
- `test/integration/test_ramp2_wedge.gd` (new)
- `docs/design/track-geometry.md` (new)

### Verification

Probe: the car starts behind the ramp, facing away from it, and reverses
toward the high end. The probe logs the car, the camera, a ray from car
+ 1 m to the camera, and the largest single-frame camera step.

| Run (start z, brake, x offset, heading) | Old slab | Wedge |
|---|---|---|
| 28, 0.5, 0, 180 | 75 blocked frames, 4.69 m step, car wedged at z 6.26 | 0 blocked, 0.43 m, stops at the back face (z 16.41) |
| 28, 1.0, 0, 180 | 139 blocked, 4.69 m, wedged | 0, 0.52 m, back face |
| 28, 0.3, +2.5, 180 | 7 blocked, 4.73 m, wedged | 0, 0.41 m, back face |
| 28, 0.5, -3.5, 160 | 0 blocked, 3.92 m step | 0, 0.39 m |
| -10, 0.5, 0, 0 (up the slope) | 0, 0.30 m | 0, 0.30 m |
| Windowed (120 Hz), 28, 0.5, 0, 180 | 78 blocked, 4.71 m | 0, 0.45 m |

The 0.4-0.5 m steps are the normal wall pull-in when the camera meets the
back face. The T-005 follow-up "no boom smoothing after pull-in" still
applies.

Climb from the low end at full throttle, the same probe on `main` and on
this branch:

| Start | Old slab | Wedge |
|---|---|---|
| z = -5 | max y 8.64, floor tilt 30.0, takeoff at 24.0 m/s | identical |
| z = -45 (jump the Kenney ramp onto Ramp2) | max y 8.53, takeoff at 24.0 m/s | identical |

`test/integration/test_ramp2_wedge.gd`:
- The top surface is 4.0 m high at mid-length, tilts 30.0 degrees, and is
  8.0 m high at the top edge.
- A horizontal ray at 0.5, 1.0, 1.5 and 2.5 m high stops at the back face.
- A reverse into the back face has 0 blocked frames, a camera step under
  1 m, and the car never under the ramp.
- On the old slab, the top-surface test passes and the other two fail
  (5 failures), so the tests catch the bug.

The scene diff is only the `Ramp2` node: `CSGBox3D` becomes
`CSGPolygon3D`, same `unique_id`, material and collision settings. A
full engine re-save would have dropped the scene UID, so the node was
edited in place with the values the engine generated.

### Dependencies

- T-020 (merged first, because both touch the camera rig's behavior).

### Assumptions (owner to validate)

- **Assumption:** This is the case the owner hit: reversing from the
  high-end side into the gap under the ramp.
  **Evidence:** 13 scripted runs on the old slab. All 4 reverses from
  the high-end side made the camera jump 3.9-4.7 m in one frame, and 3 of
  them lost sight of the car for 7-139 frames. None of the 9 runs from the
  low end did.
  **Owner check:** pull `main`, `task run`, and back into Ramp2 from both
  ends. If the camera still jumps through it, note which end and the
  speed.
- **Assumption:** A vertical 8 m back face is fine for the test track.
  **Evidence:** The old slab's high end was also a cliff, just with a gap
  under it. The face now behaves like any wall.
  **Owner check:** none needed, unless you want the back face sloped for
  looks.
