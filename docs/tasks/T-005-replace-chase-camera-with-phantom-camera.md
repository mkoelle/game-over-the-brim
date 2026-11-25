# T-005: Replace `ChaseCamera` with `PhantomCamera3D`

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

Run the gameplay chase camera on Phantom Camera, with geometry collision
avoidance and damping. The current framing is **not** a reference: the
owner's 2026-11-24 feel-test found the camera wrong. Start from the old
values only as a first guess, then tune by feel.

### Acceptance Criteria

- [x] `main.tscn` has a `Camera3D` with a `PhantomCameraHost` child, plus a
      `PhantomCamera3D` (`CarFollowCam`) following the car.
      *`GameCamera` + `PhantomCameraHost`, and `CarFollowCam` with a
      `YawDriver` child (`ChaseCamYawDriver`).*
- [ ] Kart-racer framing: close behind and slightly above, low-lag
      follow, and the camera turns with the car's heading. Start from
      4.5 m / 1.8 m, then tune by feel. Record the final values in the PR.
      *Tuned against a scripted drive instead of a hand drive. The final
      values are under Outcome.* *Pending owner: FC-1 feel drive.*
- [x] The camera never ends up inside a wall while hugging walls on
      `test_track.tscn`. Collision checks only the **Track** layer (1),
      never Vehicles (2).
      *Met by the scripted drive: 0 frames inside geometry, with line of
      sight blocked, or within 0.08 m of a surface, over 2,251 measured
      frames. `collision_mask == 1` is pinned by a test.*
- [x] `follow_target` is assigned in `main.gd`, never hardcoded as a node
      path in the camera.
- [x] `test/integration/test_main.gd` still passes.
- [x] The `godot-ai` MCP spike result (reliable or not, and what failed)
      is recorded in ADR-022 §6, and the PR includes a screenshot of the
      running camera framing.
      *Recorded as ADR-022 §6a. The screenshots are listed under Outcome,
      for the checker to attach to the PR.*

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
4. **`godot-ai` MCP spike** (ADR-022 §6): open the editor with the
   project, then make the scene edits below through the MCP
   (`node_create`, `node_set_property`, `scene_save`). Verify with
   `project_run` plus `editor_screenshot`/`logs_read`. If the MCP is
   unreliable, do the same edits by hand in the editor and record why.
   Edit `main.tscn`:
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
- T-019 (godot-ai vendored and wired, for the MCP spike)

### Outcome (2026-11-25)

**Mode.** Third Person, with yaw fed each frame. Only Third Person does
collision (ADR-013 notes, `phantom_camera_3d.gd:1581-1621`), so Simple
follow was ruled out from the source. It was not run.

**Rig.** `scripts/camera/chase_camera.gd` became
`chase_cam_yaw_driver.gd` (`class_name ChaseCamYawDriver`, 47 code lines).
It has no position logic. It is a child of `CarFollowCam` and reads that
camera's `follow_target`. Each frame it does two things:
- It smooths yaw toward the car heading and writes pitch and yaw with
  `set_third_person_rotation`.
- While airborne, it holds the aim height at the takeoff level.

All `main.tscn` edits went through the godot-ai MCP (ADR-022 §6a).

**Final values** (researched start from handling-reference §4, then
tuned on the probe):

| Setting | Value | Why |
|---|---|---|
| `spring_length` | 4.657 m | 4.5 m behind and 1.2 m above the aim point at rest |
| `vertical_rotation_offset` (pitch) | 0.2606 rad (14.9 degrees) | atan(1.2 / 4.5); §4 range 12-15 degrees |
| `follow_offset` (aim point) | (0, 1.0, 0) | §4: about 1.0 m above the car origin |
| Camera height at rest | 2.2 m above the car origin | §4 range 2.2-2.5 m |
| `follow_damping_value` | (0.06, 0.2, 0.06) s | see the table below |
| `shape` / `margin` | `SphereShape3D` r = 0.25 m / 0.2 | keeps the camera 0.25 m off walls |
| `collision_mask` | 1 (Track only) | the car is on layer 2 |
| `priority` | 10 | |
| `GameCamera.fov` | 75 (default) | §4 base FOV for one player |
| `yaw_smooth_time` | 0.15 s | 20 degrees of lag at full lock |
| `velocity_heading_weight` | 0.0 (toggle) | 0.6 made wall crashes 10x jerkier |
| `hold_height_in_air` / `air_release_time` | on / 0.4 s | §4 airborne behaviour |

Distance grows with speed on its own. The X/Z damping lags the rig by
speed × 0.06 s, so the camera sits 6.1 m back at 24 m/s (§4 target:
6.0 m). No separate speed-linked distance code was needed.

**Scripted windowed drive** (`main.tscn`, 1280x720, `--fixed-fps 60`,
with a scripted `InputSource` on the car). Every frame it measures:
- a point query at the camera on layer 1
- a ray from the aim point to the camera
- a 0.08 m sphere for near-plane clipping
- whether the car is inside the camera frustum
- camera-to-car distance, yaw lag, acceleration and jerk

The first 20 frames of a segment are excluded from acceleration and jerk,
because the probe presets the speed.

| Segment | §4 start values (0.15/0.3/0.15, yaw 0.25, pyramid) | Final |
|---|---|---|
| Full-speed straight: distance min/mean/max | 6.66 / 7.93 / 8.21 m | 5.64 / 6.06 / 6.14 m |
| Straight: peak acceleration / jerk | 14 m/s² / 69 m/s³ | 14 m/s² / 165 m/s³ |
| Hard corner, full lock at 24 m/s: steady yaw lag | 34.6 degrees | 19.5 degrees |
| Half lock: steady yaw lag | 17.3 degrees | 9.8 degrees |
| 3 m boundary wall hug, then a crash into the NE corner | 149 near-plane frames, 3,133 m/s² peak | 0 near-plane frames, 380 m/s² peak (at the crash) |
| 3 m wall, steering hard away (the boom swings into the wall) | 0 bad frames | 0 bad frames, 262 m/s² peak |
| 1.05 m barrier hug | 0 bad frames | 0 bad frames, 53 m/s² peak |
| Ramp, Ramp2 and both landings | 7 near-plane frames, car off screen 21 frames (partly a probe artifact) | 0 bad frames, car between 0.36 and 0.77 of screen height |
| Synthetic 2.4 m hop: camera world-height range | not run | 0.29 m with hold on (2.63 m with hold off) |
| Drift weave | 0 bad frames, 35.5 degrees max lag | 0 bad frames, 19.5 degrees max lag |

"Bad frames" means inside geometry, line of sight blocked, near-plane or
off screen. Across all final segments every count was 0.

Sweeps behind the choices:
- **Yaw smoothing:** lag at full lock was 14 / 16.8 / 20.9 / 27.7 degrees
  for 0.10 / 0.12 / 0.15 / 0.20 s. At 0.10 and 0.12 s the boom swung into
  the wall faster on the steer-away run (769 and 966 m/s² against 259).
- **Y damping:** 0.3 s let the camera drop into Ramp2 on the 30 degree
  climb. The boom pulled in to 1.67 m with a 17,500 m/s² jump. 0.2 and
  0.15 s both stay clear.
- **Velocity-heading blend:** 0.6 versus 0 gave 3,967 versus 380 m/s² at
  the corner crash. Velocity collapses on impact, so the yaw target jumps.

**Evidence screenshots** (running project, not the editor). All are in
`/private/tmp/claude-501/-Users-mkoelle-src-github-com-mkoelle-game-over-the-brim/9880b461-5823-4d17-baec-4d611c2731b0/scratchpad/t005/`:
- `shot_final_straight.png`
- `shot_final_corner.png`
- `shot_final_wall3m.png` and `shot_final_wall3m_corner.png` (the wall hug)
- `shot_final_barrier.png`
- `shot_final_airborne.png` and `shot_final_hop_peak.png` (airborne)
- `shot_final_drift.png`
- `mcp_game_final_2_0.png` (MCP `editor_screenshot` of the running game)

**Observed, not camera bugs (for the handling rework):**
- Ramps never launch the car upward. `VehicleController` zeroes
  `velocity.y` while grounded, so the car leaves a ramp lip level and only
  falls. Hold-in-air therefore never triggers on `test_track.tscn` today.
  It was verified with a synthetic hop.
- Reverse has no lower speed cap. Holding brake reaches 24 m/s backwards,
  and the car backs into the camera.

**Follow-ups:**
- Compare `physics_interpolation` on and off on a 120 Hz+ display
  (ADR-013 Consequences).
- The addon does not smooth the boom after a collision pull-in, so a
  corner crash gives a 1-3 frame jolt. If FC-1 finds it jarring, ease the
  boom back out. That needs a small driver-side change, or an upstream
  issue.
- Re-test `velocity_heading_weight` at 0.5-0.7 once the drift rework gives
  real slip. Mean slip is 2 degrees today.
- Split-screen FOV per player count (§4) when split screen lands.

### Assumptions (owner to validate)

- **Assumption:** Third Person is the right mode; Simple follow was not
  run.
  **Evidence:** Only Third Person runs the collision cast
  (`phantom_camera_3d.gd:1581-1621`, ADR-013 notes). The scripted drive
  shows it turning with the car through `ChaseCamYawDriver`.
  **Owner check:** At FC-1, confirm that the camera turns with the car and
  never goes through a wall.
- **Assumption:** The §4 framing (4.5 m behind, 2.2 m up, aim 1.0 m, pitch
  15 degrees, FOV 75) suits our car. The ticket's old 1.8 m height was
  raised to the §4 value.
  **Evidence:** Handling-reference §4. In the probe the car sits at
  0.57-0.63 of screen height on flat ground (screenshots above).
  **Owner check:** FC-1 drive. If the car feels too small or too high in
  frame, try `spring_length` 4.0-5.0 or `follow_offset.y` 0.8-1.4.
- **Assumption:** X/Z damping of 0.06 s is a low-lag follow, and the
  6.1 m top-speed distance it causes is right.
  **Evidence:** Measured distances above. 0.15 s gave 8.2 m and put the
  car at screen centre.
  **Owner check:** Full-throttle straight. Does the car keep a steady
  size? Does a crash feel too abrupt?
- **Assumption:** Y damping of 0.2 s (not the §4 0.3 s) is smooth enough
  over ramps.
  **Evidence:** 0.3 s let the camera hit Ramp2. At 0.2 s the landing peak
  is 52 m/s² vertical, with 0 bad frames.
  **Owner check:** Drive up Ramp2 and land. If landings jolt, try
  0.25 s. If climbs drop the camera too low, try 0.15 s.
- **Assumption:** A yaw smoothing time of 0.15 s (20 degrees of lag at
  full lock, 10 degrees at half) is a sane kart-racer turn feel.
  **Evidence:** Sweep above. This is the low end of the §4 range
  (0.15-0.4 s).
  **Owner check:** Hard corners at full speed. Lower it if the camera
  feels loose, raise it if it feels twitchy.
- **Assumption:** The velocity-heading (follow-skid) blend should start
  off.
  **Evidence:** It made a wall crash 10x jerkier, and today's drift has
  about 2 degrees of mean slip, so it adds nothing yet. §4 says to keep it
  as a toggle.
  **Owner check:** After the drift rework, set `velocity_heading_weight`
  to 0.6 on `YawDriver` and compare drifts.
- **Assumption:** Holding the camera at takeoff height in the air reads
  well. The car rises in frame instead of the view bobbing up.
  **Evidence:** Synthetic hop: the camera height range was 0.29 m with
  hold on against 2.63 m with it off. The car stayed on screen, and its
  highest point reached 0.30 of screen height.
  **Owner check:** Once ramps launch upward, jump and judge it. Turn
  `hold_height_in_air` off to compare.
- **Assumption:** A 0.25 m sphere collision shape (with `margin` 0.2) is
  enough clearance.
  **Evidence:** The default pyramid gave 149 near-plane frames in a wall
  corner. The sphere gave 0 across all segments.
  **Owner check:** Hug every wall, including the corners. Look for wall
  texture filling the screen or flickering.
