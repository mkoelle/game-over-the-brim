# T-005: Replace `ChaseCamera` with `PhantomCamera3D`

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

Run the gameplay chase camera on Phantom Camera, with geometry collision
avoidance and damping. Keep the current framing so feel-test results stay
comparable.

### Acceptance Criteria

- [ ] `main.tscn` has a `Camera3D` with a `PhantomCameraHost` child, plus a
      `PhantomCamera3D` (`CarFollowCam`) following the car.
- [ ] The framing matches today's: about 4.5 m behind, 1.8 m up, snappy
      low-lag follow, and the camera turns with the car's heading.
- [ ] The camera never ends up inside a wall while hugging walls on
      `test_track.tscn`. Collision checks only the **Track** layer (1),
      never Vehicles (2).
- [ ] `follow_target` is assigned in `main.gd`, never hardcoded as a node
      path in the camera.
- [ ] `test/integration/test_main.gd` still passes.

### Context

Current tuning in `chase_camera.gd`: `follow_distance = 4.5`,
`follow_height = 1.8`, `follow_smoothing = 8.0` (a 1/s decay rate),
`look_smoothing = 10.0`.

Since v0.12, `PhantomCamera3D` runs in `_process` using
`get_global_transform_interpolated()`. The car moves in
`_physics_process`.

Third Person mode handles distance and collision, but the camera *yaw* is
normally player- or script-driven. A chase cam needs yaw that follows the
car. Confirm which mode fits in step 2 below.

### Files Likely Affected

- `scenes/main.tscn`
- `scripts/main.gd`
- `scripts/camera/chase_camera.gd` (delete, or shrink to a thin yaw driver)

Plus a one-line doc update: the `ChaseCamera` mention in
`docs/standards/manual-testing.md`.

### Implementation Plan

1. Branch `feature/phantom-chase-camera`.
2. **Mode spike (about 30 min).** In a scratch scene, try both:
   - **Third Person**, with
     `spring_length = 4.5`, `follow_offset = Vector3(0, 1.8, 0)`,
     `follow_damping = true`, and yaw fed each frame from the car.
   - **Simple follow**, with the offset rotated into car space (if v0.12
     exposes a local-space offset), plus Look At Mimic or Simple on the car.

   Pick the one that turns with the car smoothly and still gets collision
   avoidance. Third Person is expected to win, because only it does
   collision.
3. If yaw must be fed, shrink `chase_camera.gd` to about 20 lines
   (`class_name ChaseCamYawDriver`). Each frame, lerp the PCam's
   third-person yaw toward `target.global_rotation.y` with the existing
   `1 - exp(-rate * delta)` decay weight and `look_smoothing`, then call
   the PCam third-person rotation setter. Remove all position logic.
   Otherwise, delete the file.
4. Edit `main.tscn` in the editor:
   - Replace the `ChaseCamera` node with `GameCamera` (`Camera3D`) +
     `PhantomCameraHost`.
   - Add `CarFollowCam` (`PhantomCamera3D`, `priority = 10`).
   - Set the collision mask to layer 1 only, and a small collision margin
     (about 0.2).
   - Start damping at about 0.1–0.15 to match the old 8.0/s rate, then
     tune by feel.
5. `main.gd`: replace the `_chase_camera` reference with
   `@onready var _follow_cam: PhantomCamera3D = $CarFollowCam`, and set
   `_follow_cam.follow_target = _car` in `_ready()`. Update the
   `print_rich` message.
6. Drive the test track at 60 Hz. The physics-interpolation comparison is
   **skipped**, because no high-refresh monitor is available (owner,
   2026-11-24). Note the gap in ADR-013 under Consequences. Do **not**
   change `physics/common/physics_interpolation` in this ticket.
7. Update `docs/standards/manual-testing.md`: `ChaseCamera` export becomes
   the `CarFollowCam` inspector values.
8. `task ci`.

### Verification

Run F5 and drive one full lap hugging every wall at full speed, plus the
ramp. The camera follows heading changes smoothly and never clips into a
wall or the floor.

### Dependencies

- T-004
