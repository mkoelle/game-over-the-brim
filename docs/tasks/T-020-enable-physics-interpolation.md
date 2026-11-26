# T-020: Enable Physics Interpolation (Car Vibration at 120 Hz)

**Assignee:** Claude (Opus, ADR-022 camera-feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 1h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md)), FC-1 feedback
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

Stop the car from vibrating and looking blurry while driving. This was
FC-1 owner feedback ([checklist](../plans/fc-1-owner-checklist.md) §5):
"While driving car/box looks like it is vibrating, and is blurry because
of it".

### Acceptance Criteria

- [x] `physics/common/physics_interpolation` is `true` in `project.godot`.
      No other setting changes.
- [x] Every `_process` reader of the car's transform uses
      `get_global_transform_interpolated()`: `ChaseCamYawDriver` (heading
      and air height) and `VehicleDebugDraw` (arrows). Phantom Camera
      already does.
- [x] The car's frame-to-frame screen motion at top speed is smooth on a
      120 Hz display. Measured RMS deviation is under 0.5 px, against
      about 8 px before.
- [x] `task ci` is green. A test locks the setting on and the camera's own
      interpolation off.

### Context

- **Cause.** The car moves in `_physics_process` at 60 Hz. The camera
  moves every rendered frame in `_process`: Phantom Camera v0.12 reads the
  car's interpolated transform (ADR-013 Consequences). The owner's
  MacBook Pro (`MacBookPro18,1`) has a 120 Hz ProMotion built-in display,
  and the game renders at 119-120 FPS. So every other frame has no physics
  tick: the car stands still on screen while the camera keeps moving, and
  then jumps two frames' worth. At 24 m/s that is about 8 px of
  back-and-forth per frame. On a sample-and-hold display it reads as
  vibration and motion blur.
- **T-005 skipped this check**, because the plan recorded "no
  high-refresh monitor". The built-in display is high-refresh. ADR-013
  already predicted the stepping.
- **Godot 4.7.2 docs** (`doc/classes/ProjectSettings.xml` at
  `4.7.2-stable`): interpolation "will interpolate the transforms of
  objects ... between the last two transforms, so that smooth motion is
  seen even when physics ticks do not coincide with rendered frames".
  `physics_jitter_fix` "is automatically disabled" when it is on, so that
  setting needs no change.
- **The camera stays non-interpolated.** `PhantomCameraHost` sets the
  `Camera3D` to `PHYSICS_INTERPOLATION_MODE_OFF` and moves it in
  `_process`, which is correct for a camera driven per frame.

### Files Likely Affected

- `project.godot`
- `scripts/camera/chase_cam_yaw_driver.gd`
- `scripts/vehicles/vehicle_debug_draw.gd`
- `test/integration/test_car_follow_cam.gd`

### Verification

A windowed probe drives `main.tscn` at full throttle on the owner's
machine (120 Hz). It samples the car's screen position at
`RenderingServer.frame_pre_draw` over about 200 frames above 15 m/s, and
reports the RMS deviation of the per-frame screen step from its mean.

| Run | FPS | Physics ticks per frame | Straight RMS / max | Turning (steer 0.4) RMS / max |
|---|---|---|---|---|
| Before: interpolation off | 118-120 | alternating 0 and 1 | 7.91 px / 10.09 px | 8.29 px / 10.50 px |
| Interpolation on, driver unchanged | 117-118 | alternating 0 and 1 | 0.12 px / 0.66 px | 0.13 px / 0.66 px |
| After: interpolation on + interpolated reads | 120 | alternating 0 and 1 | 0.09 px / 0.52 px | 0.12 px / 0.33 px |

`task ci`: `Overall Summary: 63 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, `Exit code: 0`.

### Dependencies

- T-005 (Phantom Camera rig).

### Assumptions (owner to validate)

- **Assumption:** The vibration the owner saw is this 60/120 Hz stepping,
  not something else, such as the camera shake or the damping.
  **Evidence:** the measurements above. The 8 px per-frame back-and-forth
  goes away with interpolation alone, and the shake only fires on wall
  hits.
  **Owner check:** pull `main`, `task run`, and drive the long straight
  and a few corners. The box should look sharp and steady. If it still
  vibrates, note whether this happens on the straight or only in corners.
- **Assumption:** The added latency is acceptable. Interpolation draws
  the car up to one physics tick (about 17 ms) behind its simulated
  position.
  **Evidence:** this is how the method works (it blends the last two
  ticks). It is the standard Godot approach, and the input path itself
  is unchanged.
  **Owner check:** steering should not feel laggy compared to before. If
  it does, `physics/common/physics_ticks_per_second` = 120 is the
  alternative. It costs twice the physics work and would need its own
  ticket.
