# T-007: In-World Vehicle Debug Vectors (F3)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Todo
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

- [ ] F3 on draws:
  - a blue facing arrow (`-basis.z`, 2 m)
  - a green flat-velocity arrow (length scaled by `speed / max_speed`, max 3 m)
  - a yellow floor-normal arrow (only while grounded)
  - slip angle in degrees and grounded state as text near the car
- [ ] F3 off draws nothing and costs nothing beyond one bool check.
- [ ] `VehicleController` has **no** reference to `DebugDraw3D` (ADR-016).
- [ ] Release builds never load the component (ADR-015 check 6).

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
4. If T-006 added an export exclude filter, add
   `scripts/vehicles/vehicle_debug_draw.gd` to it.
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
