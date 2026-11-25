# T-008: Impact Camera Shake

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Done
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-013](../adr/ADR-013-camera-addon-phantom-camera.md)

### Goal

A wall hit at speed shakes that car's camera in proportion to impact
speed. This adds slapstick feedback (Pillar "Fun > Realism") using Phantom
Camera's noise emitter.

### Acceptance Criteria

- [x] `VehicleController` emits a **local** signal
      `impacted(impact_speed: float)` once at the start of each wall
      contact, not every frame of a scrape.
      *It also fires once more if the car hits much harder during a
      contact, such as scraping one wall into another in a corner. See
      Outcome.*
- [x] A `PhantomCameraNoiseEmitter3D` in `main.tscn` fires with intensity
      and duration scaled by `impact_speed`. Hits below a minimum speed
      produce no shake.
      *`ImpactShake`, plus an `ImpactShakeDriver` child that does the
      scaling. The values are researched assumptions (see below).*
- [x] The signal is per-vehicle and does not go through `EventBus`.
- [x] No allocations in `_physics_process` for impact detection.
      *Only `is_on_wall()` and `get_wall_normal()` are read, which return a
      bool and a `Vector3`. The Object count stayed flat over an 8 s
      scrape (Outcome).*

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

### Outcome (2026-11-25)

**Detection** (`vehicle_controller.gd`, handling unchanged). The velocity
is copied just before `move_and_slide()`. The car stops dead on a wall
(`floor_block_on_wall`, ADR-021 finding), so the speed must be read
before the slide. After the slide, `_detect_wall_impact()` reads
`is_on_wall()` and `get_wall_normal()`. The impact speed is the copied
velocity along the wall normal. Normals with `|y| >= 0.7` are skipped.
- **No `get_slide_collision()`.** In Godot 4.7.2 it hands out a
  `KinematicCollision3D`. The engine caches one per slot, but makes a new
  one whenever a script still holds the last one
  (`scene/3d/physics/character_body_3d.cpp:725-739` at `4.7.2-stable`).
  `is_on_wall()` (`:663`) and `get_wall_normal()` (`:683`) return a bool
  and a `Vector3`. Both are reset by every `move_and_slide()` (`:96`,
  `:151`).
- **Re-arm time 0.1 s.** Raw wall contact flickers: one frame off in a
  head-on hit held against the wall, and in the barrier scrape. A contact
  that starts within 0.1 s of the last one counts as the same hit.
  Without this, the 60-degree test hit emitted twice (mutation check).
- **Harder hit inside a contact.** The probe found a gap: a car scraping
  the east wall into the NE corner only shook because contact happened to
  break 0.18 s before the corner. A contact now emits again if the
  into-wall speed beats its fastest frame so far by 3 m/s. Steering harder
  into the same wall adds at most about 1 m/s per frame
  (2.4 rad/s × 24 m/s / 60). Disabling this branch fails the new corner
  test.

**Shake** (`main.tscn`, all edits through the godot-ai MCP). `ImpactShake`
is a `PhantomCameraNoiseEmitter3D` with a `PhantomCameraNoise3D`
sub-resource, on noise layer 1. `CarFollowCam.noise_emitter_layer` is now 1
too (the default 0 ignores every emitter). Its child `ImpactShakeDriver`
(new, `scripts/camera/impact_shake_driver.gd`) maps the hit to the
emitter. `main.gd` connects `_car.impacted` to it. The driver also:
- uses its own copy of the noise resource, because it rewrites the
  amplitude on every hit, and a scene sub-resource is shared by every
  instance of that scene (one per player later);
- ignores a hit weaker than the shake still playing, so a tap cannot cut
  a big shake short.

How Phantom Camera v0.12 maps the values (read from the source, and the
docs agree in wording):
- Rotation per axis, in degrees, is `amplitude × multiplier × trauma² ×
  Perlin(t)`. Position is the same divided by 10, in metres
  (`phantom_camera_noise_3d.gd:157-173`).
- The emitter holds trauma at 1 for `duration`, then fades it linearly
  over `decay_time` (`phantom_camera_noise_emitter_3d.gd:122-156`). The
  host multiplies the result onto the camera in camera space, after the
  follow and collision (`phantom_camera_host.gd:872-873`).
- `frequency` is the Perlin frequency over time in seconds. At 15, the
  rotation returns to zero every 1/15 s (every 4th frame at 60 fps).
- The online docs list `frequency` 0.5 and positional noise on as
  defaults. The v0.12 source says 0.2 and off. The source wins.

| Setting | Value | Why |
|---|---|---|
| `min_shake_speed` | 3 m/s into the wall | ticket; a 2 m/s bump must not shake |
| strength | `(speed − 3) / (max_speed − 3)`, clamped 0–1 | linear, starts at 0 at the threshold (the ticket's `speed / max_speed` jumps to 0.125 there) |
| `max_amplitude` | 10 (× strength) | median peak 2.3–2.5 degrees at a full-speed head-on hit |
| hold (`duration`) | 0.03–0.08 s | short, sharp |
| `decay_time` | 0.10–0.22 s | total 0.13–0.30 s; trauma² makes most of it fade early |
| `growth_time` | 0 | full kick on the impact frame |
| `frequency` | 15 | 2–3 swings per shake; 4 frames per swing at 60 fps |
| rotational multipliers x / y / z | 1.0 / 0.5 / 0.25 | pitch-led nod, little roll |
| positional noise | off | cannot move the camera into a wall |

**Shake size through the real `main.tscn` pipeline** (headless,
`--fixed-fps 60`, 40 hits per speed, `shake_stats_amp10.log`). Peak camera
rotation away from `CarFollowCam`'s own output:

| Into-wall speed | p10 / p50 / p90 / max | Visible (≥ 0.25 degrees) |
|---|---|---|
| 3 m/s | 0 / 0 / 0 / 0 | none |
| 5 m/s | 0.10 / 0.19 / 0.32 / 0.34 degrees | at most 0.03 s |
| 8 m/s | 0.20 / 0.44 / 0.63 / 0.81 degrees | 0.03 s |
| 12 m/s | 0.59 / 1.03 / 1.45 / 1.55 degrees | 0.10 s |
| 17 m/s | 0.85 / 1.22 / 2.09 / 2.32 degrees | 0.12 s |
| 24 m/s | 1.47 / 2.31 / 3.19 / 3.48 degrees | 0.18 s (max 0.22 s) |

The peak varies from hit to hit, because the noise is random. A sweep at
24 m/s (80 hits each, `sweep1.log`) shows no setting that narrows it much:

| frequency / hold | p10 / p50 / p90 / max |
|---|---|
| 15 / 0.08 s (chosen) | 1.74 / 2.46 / 2.97 / 4.06 degrees |
| 20 / 0.08 s | 1.55 / 2.51 / 3.20 / 4.42 degrees |
| 15 / 0.12 s | 1.74 / 2.88 / 3.56 / 3.62 degrees |
| 20 / 0.12 s | 1.95 / 2.97 / 3.84 / 4.77 degrees |

**Scripted windowed run** of `main.tscn` (1280x720, `--fixed-fps 60`,
scripted `InputSource`; probe adapted from T-005's `drive_probe.gd`).
Every rendered frame, after `PhantomCameraHost`, it logs wall contact,
the shake angle, the camera position offset from noise, the boom length,
and near-plane, inside-geometry and line-of-sight checks.

| Segment | `impacted` (frame, m/s) | Wall frames / raw contact starts | Peak shake | Shake frames (> 0.05 degrees) |
|---|---|---|---|---|
| 3 m wall, head-on, 24 m/s, held 1.5 s | (20, 24.0) | 99 / 2 | 2.0 degrees | 12, over 0.25 s |
| 3 m wall, 45 degrees, 24 m/s | (43, 16.97) | 47 / 1 | 2.2 degrees | 9 |
| 3 m wall, head-on, 5 m/s | (24, 5.0) | 36 / 1 | 0.29 degrees | 5 |
| 3 m wall, head-on, 2 m/s | (30, 2.0) | 30 / 1 | 0 | 0 |
| 3 s scrape along the east wall | (26, 1.66) | 154 / 1 | 0 | 0 |
| 1.05 m barrier scrape | (10, 0.80) | 61 / 2 | 0 | 0 |
| T-005 corner crash (east wall into NE corner) | (27, 2.01), (231, 21.74) | 340 / 4 | 2.6 degrees | 10 |

- In every segment the camera position offset from noise was 0 m, with 0
  near-plane, 0 inside-geometry and 0 line-of-sight-blocked frames.
- Thirteen windowed head-on 24 m/s runs peaked at 0.93, 1.07, 1.13,
  1.80, 2.00, 2.24, 2.36, 2.43, 2.59, 2.60, 2.65, 3.59 and 3.71 degrees
  (median 2.36).
- **Stacking with the collision pull-in.** In the corner crash the boom
  pulled in from 4.49 m to 3.33 m over about 25 frames (at most 0.11 m per
  frame). That overlaps the shake. The car's largest on-screen jump per
  frame was 40.5 px with shake and 14.4 px with `max_amplitude = 0`. The
  shake only rotates the camera in place, so it never moves the camera
  toward the wall. The two-frame 4.66 → 3.07 m jump noted in T-005 did
  not happen in this run.
- **Allocation check.** The car scraped a wall for 8 s (453 of 480 physics
  frames in contact, 1 `impacted`). `Performance.OBJECT_COUNT` read 1541 at
  frames 60, 120, 240, 360 and 480.
- **MCP run.** After `project_run`, the first `editor_state` poll (1 s
  later) already read `"live"`, and `editor_screenshot source="game"`
  worked. The only log
  line was the existing `race_started` unused-signal warning. One call
  failed: `resource_manage inspect` on `ImpactShake.noise`
  (`PROPERTY_NOT_ON_CLASS`: it only inspects native resource properties,
  not script ones). `resource_manage create` with
  `type: "PhantomCameraNoise3D"` did create the script resource, unlike
  `node_create` for script node classes.

**Tests:**
- `test/unit/test_vehicle_controller.gd`, 6 new tests:
  - one `impacted` for a head-on hit held against the wall, at 24 m/s;
  - only the into-wall part of the speed is reported (10 m/s from 20 m/s
    at 60 degrees);
  - one `impacted` over a 3 s scrape that is in contact for more than 120
    of 180 frames;
  - a second `impacted` when the scrape runs into a cross wall;
  - a second `impacted` after backing off and hitting again;
  - none on a 3 m landing at full speed.
- `test/unit/test_impact_shake_driver.gd` (new, 6 tests):
  - no shake at or below the minimum speed;
  - full-speed and half-speed hits scale the amplitude, hold and decay;
  - clamping above full speed;
  - a weak hit does not cut a strong shake short;
  - the driver scales its own copy of the noise.
- `test/integration/test_impact_shake.gd` (new, 3 tests):
  - the emitter layer reaches `CarFollowCam`, and the noise is rotational
    only;
  - a 24 m/s hit on the east wall rotates `GameCamera` away from
    `CarFollowCam`'s output, which sat exactly on it before the hit;
  - a 2 m/s bump fires `impacted` but leaves the camera still.
- The floor and wall helpers in `test_vehicle_controller.gd` now
  `auto_free` their bodies. Before, each body stayed in the tree after its
  test, and walls from earlier tests broke the landing test.

**Evidence files** (scratch, for the checker to attach to the PR), all in
`/private/tmp/claude-501/-Users-mkoelle-src-github-com-mkoelle-game-over-the-brim/9880b461-5823-4d17-baec-4d611c2731b0/scratchpad/t008/`:
- `shot_final5_before_hit.png` and `shot_final5_mid_shake.png`: the same
  head-on approach, before the hit and mid-shake at 2.19 degrees (the
  wall's top edge tilts).
- `mcp_game_shot.png`: MCP `editor_screenshot` of the running game.
- `drive_final.log` (all segments, per-frame trace), `drive_noshake.log`,
  `shake_stats_amp10.log`, `sweep1.log`.

**Follow-ups:**
- Split screen: give each player their own emitter, a unique
  `noise_emitter_layer` (bit per player) on both the emitter and that
  player's `PhantomCamera3D`, and their own `impacted` connection. The
  emitter broadcasts through the global `PhantomCameraManager` signal, so
  the layer is the only filter (ADR-013 T-008 notes).
- Accessibility: add a camera-shake off switch and intensity slider to
  settings when a settings menu exists
  ([Xbox Accessibility Guideline 117](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117)).
  `ImpactShakeDriver.max_amplitude` is the one value to scale.
- Car-vs-car bumps also count as wall contacts (a `CharacterBody3D` hit is
  a wall to `move_and_slide()`). That is untested until there are two
  cars.

### Assumptions (owner to validate)

- **Assumption:** 3 m/s into the wall is the right shake threshold. Below
  it nothing shakes, and at 5 m/s the shake is tiny (median 0.19
  degrees).
  **Evidence:** The ticket's 3 m/s, and a common pattern of gating
  collision feedback on a speed threshold
  ([CollisionFX 2](https://www.gta5-mods.com/ca/scripts/collisionfx-2)). In
  the probe, a 2 m/s bump gave 0 degrees and a 5 m/s hit 0.29 degrees.
  **Owner check:** At FC-1 (or the next feel checkpoint), tap a wall at
  low speed. Raise `min_shake_speed` on `ImpactShake/ImpactShakeDriver`
  if taps still shake, or lower it if a medium bump feels dead.
- **Assumption:** A full-speed head-on hit should peak at about 2.5
  degrees of camera rotation (`max_amplitude` 10) and stay visible for
  about 0.2 s (0.30 s total). That reads as a clear slapstick jolt
  without motion sickness.
  **Evidence:** Trauma-style shake from Squirrel Eiserloh's GDC 2016 talk
  "Juicing Your Cameras With Math"
  ([GDC Vault](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing)).
  Bevy's example of that talk calls 10 degrees "somewhat high but still
  reasonable" for full trauma
  ([Bevy 2D screen shake](https://bevy.org/examples/camera/2d-screen-shake/)).
  KidsCanCode caps roll at 0.1 rad (5.7 degrees) and says "use sparingly"
  ([Godot Recipes](https://kidscancode.org/godot_recipes/3.x/2d/screen_shake/)).
  A 3D chase camera, often in a split-screen quarter, should sit well
  below those. Measured: median 2.3–2.5 degrees, p90 3.2, max 4.4.
  **Owner check:** Drive head-on into a boundary wall at full speed about
  five times. If it feels weak, raise `max_amplitude` to 14. If it feels
  harsh or nauseating, lower it to 6–7.
- **Assumption:** Shake strength should rise linearly with the speed into
  the wall, from 0 at 3 m/s to full at the car's `max_speed`.
  **Evidence:** The ticket asks for scaling by `speed / max_speed`. The
  remap starts at 0 at the threshold, so there is no jump there.
  Phantom Camera already squares trauma over time, which gives the punchy
  start Eiserloh recommends (Bevy example: "camera shakes don't feel punchy
  when they go up linearly").
  **Owner check:** Hit a wall at 45 degrees (about 17 m/s into it). It
  should shake clearly but less than head-on (median 1.2 degrees).
- **Assumption:** Rotation only, led by pitch (multipliers 1.0 / 0.5 /
  0.25), at frequency 15.
  **Evidence:** The Phantom Camera docs recommend rotational noise "to
  avoid potential issues with the camera clipping with the environment"
  ([PhantomCameraNoise3D docs](https://phantom-camera.dev/resource-types/phantom-camera-noise-3d)).
  The probe measured 0 m of camera offset and 0 clipping frames. Little
  roll keeps the horizon steadier. 15 gives 2–3 swings in a 0.3 s shake
  (sweep above).
  **Owner check:** If the shake looks like a buzz, lower `frequency` on
  the `ImpactShake` noise to 10. If it feels like a slow wobble, raise it
  to 20.
- **Assumption:** Hit-to-hit variation in strength is acceptable. The
  noise is random, so two identical full-speed hits can peak at 1.5 and
  3.2 degrees (p10 and p90).
  **Evidence:** The sweep above: no frequency or hold setting narrowed it
  much. A longer hold (0.12 s) raises the median to 2.9 degrees.
  **Owner check:** If some full-speed hits feel too weak, set
  `max_hold_time` to 0.12 s.
- **Assumption:** A 0.1 s re-arm time and a 3 m/s harder-hit margin give
  one shake per crash: not one per frame of a scrape, and not a missed
  corner crash.
  **Evidence:** All scrapes in the probe emitted once (154 and 61 wall
  frames). The corner crash emitted at the corner at 21.7 m/s. The unit
  tests and mutation checks above.
  **Owner check:** Scrape a wall for 3 s, then drive along a wall into a
  corner at full speed. Expect no shake from the scrape, and one shake at
  the corner.
