# T-008: Impact Camera Shake

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Todo
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

A wall hit at speed shakes that car's camera in proportion to impact
speed. This adds slapstick feedback (Pillar "Fun > Realism") using Phantom
Camera's noise emitter.

### Acceptance Criteria

- [ ] `VehicleController` emits a **local** signal
      `impacted(impact_speed: float)` once at the start of each wall
      contact, not every frame of a scrape.
- [ ] A `PhantomCameraNoiseEmitter3D` in `main.tscn` fires with intensity
      and duration scaled by `impact_speed`. Hits below a minimum speed
      produce no shake.
- [ ] The signal is per-vehicle and does not go through `EventBus`.
- [ ] No allocations in `_physics_process` for impact detection.

### Context

- Why a local signal and not EventBus: in splitscreen, only the hit car's
  viewport may shake. A global `EventBus` impact signal would shake every
  player's camera, or force every listener to filter by racer. Per
  overview.md §6, per-frame physics stays local. A future
  `vehicle_crashed` milestone for the crash-cam (`PresenterDirector`) can
  be a separate EventBus signal later.
- Floor contacts (landing a jump) are excluded here. Use
  `absf(normal.y) < 0.7` to keep wall-ish normals only. Landing feedback
  is a separate tuning decision.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scenes/main.tscn`
- `scripts/main.gd`

### Implementation Plan

1. Branch `feature/impact-camera-shake`.
2. `vehicle_controller.gd`:
   - Add `signal impacted(impact_speed: float)` with a doc comment saying
     it is local and per-vehicle.
   - Add `var _touching_wall: bool = false`.
   - Before `move_and_slide()`:
     `var pre_velocity: Vector3 = velocity`. This is a value type, so it
     does not allocate on the heap.
   - After `move_and_slide()`: loop over `get_slide_collision_count()`.
     For wall-ish normals, take the max of
     `maxf(0.0, -pre_velocity.dot(normal))`.
   - If the max is > 0 and `not _touching_wall`, emit `impacted(max)`. Then
     set `_touching_wall` to whether any wall contact exists this frame.
   - `get_slide_collision()` returns a `KinematicCollision3D` object. Check
     with the profiler whether this allocates per call. If it does, gate
     the loop on `is_on_wall()` first, so the loop only runs during
     contact.
3. `main.tscn`: add `ImpactShake` (`PhantomCameraNoiseEmitter3D`) with a
   `PhantomCameraNoise3D` resource. Start with short duration (about
   0.25 s) and moderate frequency.
4. `main.gd`: connect `_car.impacted` to `_on_car_impacted(speed)`.
   Ignore speeds below `MIN_SHAKE_SPEED` (about 3 m/s). Scale the
   emitter's amplitude by `clampf(speed / stats.max_speed, 0, 1)`, then
   call its emit method.
5. Optional, if within budget: add a test case to
   `test_vehicle_controller.gd` that drives into a `StaticBody3D` wall
   and asserts `impacted` fired exactly once (`monitor_signals`).
6. `task ci`.

### Verification

Run F5:

- A full-speed head-on wall hit gives a clear shake.
- A gentle 2 m/s bump gives no shake.
- A 3-second scrape along a wall gives at most one shake.

### Dependencies

- T-005
