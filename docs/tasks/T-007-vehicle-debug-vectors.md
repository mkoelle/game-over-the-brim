# T-007: In-World Vehicle Debug Vectors (F3)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Done
**Estimate:** 2h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md)

### Goal

While F3 debug mode is on, draw the car's handling state in the world:

- facing
- velocity
- slip angle
- floor normal
- grounded state

This makes drift and ramp tuning readable at a glance during the hand
feel-test.

### Acceptance Criteria

- [x] F3 on draws:
  - a blue facing arrow (`-basis.z`, 2 m)
  - a green flat-velocity arrow (length scaled by `speed / max_speed`, max 3 m)
  - a yellow floor-normal arrow (only while grounded)
  - slip angle in degrees and grounded state as text near the car
- [x] F3 off draws nothing and costs nothing beyond one bool check.
- [x] `VehicleController` has **no** reference to `DebugDraw3D` (ADR-016).
- [x] Release builds never load the component (ADR-015 check 6).
  *Met by the runtime guard: `main.gd` loads the script only when
  `OS.is_debug_build()` and `ClassDB.class_exists(&"DebugDraw3D")`. No scene
  references it (tested).*

### Context

- Reads public state only: `velocity`, `transform`, `is_on_floor()`,
  `get_floor_normal()`, `stats.max_speed`, `last_input`. This is the same
  pattern as `DebugOverlay`, keeping Architecture Decision 01 intact.
- Attach it at runtime from `main.gd` instead of placing it in
  `tophat_car.tscn`. If release exports exclude the script (T-006 outcome),
  a scene that references it statically would fail to load.

### Files Likely Affected

- `scripts/vehicles/vehicle_debug_draw.gd` (new)
- `scripts/main.gd`

### Implementation Plan

1. Branch `feature/vehicle-debug-vectors`.
2. `vehicle_debug_draw.gd`:
   ```gdscript
   class_name VehicleDebugDraw
   extends Node
   ## Dev-only in-world handling vectors (ADR-016). Attached at runtime by
   ## main.gd in debug builds only — never referenced by gameplay code.

   var target: VehicleController

   func _process(_delta: float) -> void:
       if target == null or not GameConfig.debug_mode:
           return
       # DebugDraw3D.draw_arrow(...) facing / velocity / floor normal
       # DebugDraw3D.draw_text(...) slip angle + grounded
   ```
   - Slip angle:
     `rad_to_deg(forward.signed_angle_to(flat_velocity, Vector3.UP))`, and
     only when `flat_velocity.length() > 0.5`.
   - Text formatting allocates. This is accepted for debug-only code;
     leave a comment saying so.
3. `main.gd` `_ready()`:
   ```gdscript
   if OS.is_debug_build() and ClassDB.class_exists(&"DebugDraw3D"):
       var script: GDScript = load("res://scripts/vehicles/vehicle_debug_draw.gd")
       var debug_draw: Node = script.new()
       debug_draw.set(&"target", _car)
       add_child(debug_draw)
   ```
   Use `load()` rather than `preload()`, so nothing is pulled into release
   builds statically.
4. ~~If T-006 added an export exclude filter, add the script to it.~~
   Skipped: T-006 decided on no exclude filter (the `template_release`
   library is inert, see ADR-016 "ADR-015 checklist results"). The runtime
   guard in step 3 already keeps the script out of release.
5. `task ci`.

### Verification

Run F5 and press F3:

- Straight-line driving: blue and green arrows overlap.
- Held drift through a corner: green swings off blue, and the slip angle
  reads non-zero.
- On the ramp: the yellow arrow tilts.
- Press F3 again: everything disappears.

### Dependencies

- T-006

### Verification results

- `test/unit/test_vehicle_debug_draw.gd`: slip angle (0 straight, +30 and
  -30 for 30 degree sideways velocity, 0 below 0.5 m/s), arrow length scale
  and cap, no-op with null target or F3 off, no `DebugDraw3D` text in
  `vehicle_controller.gd`, no reference in `main.tscn` or `tophat_car.tscn`.
- Screenshot, non-headless, F3 on, full throttle then steer right for about
  2 s: blue facing arrow, small green velocity arrow overlapping it, a yellow
  floor-normal arrow pointing straight up, and white text "slip +1.4 deg /
  grounded" above the car. The same run with F3 off shows no arrows or text.
- Scripted probe, drift held at 12 m/s with steer left: slip -2.4 to -3.5
  degrees (non-zero, and it grows while the drift is held). Straight
  driving: 0.0.
- Scripted probe on a synthetic 15 degree slope: `get_floor_normal()` tilts
  15.0 degrees from up, which is what the yellow arrow follows.
- Checker probe on the in-scene `Ramp2`, from its low end at full throttle
  (start x=-27.69, z=-5, heading +Z): the car climbs to y=8.5 and leaves
  the top at 24 m/s. `get_floor_normal()` tilts 30.0 degrees on the ramp.
  A second run from z=-45 jumps the Kenney `Ramp` and lands on `Ramp2`.

### Assumptions (owner to validate)

- **Assumption:** the 3D text and arrows in `DebugDraw3D` are readable at the
  chase camera distance with the defaults used here (arrowhead 0.2 m
  absolute, text size 32).
  **Evidence:** `shot-on.png` from a non-headless run shows them clearly
  (the throwaway PNGs are not committed).
  **Owner check:** F5, press F3 and drive; adjust the constants at the top of
  `vehicle_debug_draw.gd` if they feel too big or small.
- **Assumption:** the slip angle sign is positive when velocity is to the
  left of the facing direction (counter-clockwise around +Y).
  **Evidence:** unit test, and the probe reads negative while steering left
  in a drift (velocity lags to the right of the nose).
  **Owner check:** hold a drift in a corner and confirm the sign reads
  sensibly to you.
- **Assumption:** the yellow arrow is readable when it tilts on a ramp.
  The tilt itself is measured: 30.0 degrees on `Ramp2` and 15.0 degrees on
  a synthetic slope (see Verification results). The builder's first probe
  "stopped dead" at `Ramp2` because it drove into the ramp's 8 m high end
  from the +Z side. Its "fell out of the world" run started inside the
  Kenney `Ramp` collider. Neither is a track bug.
  **Evidence:** checker probe output above.
  **Owner check:** drive up `Ramp2` by hand with F3 on and confirm the
  yellow arrow visibly tilts forward.
- **Assumption:** a held drift through a real corner, and the F3 toggle by
  key press, behave as the scripted probes show.
  **Owner check:** the hand run listed under Verification above.
