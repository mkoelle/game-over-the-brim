# T-030: Ramp Launch, Air Control and Landing

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §3

### Goal

Ramps launch the car. The air keeps launch momentum, and landings keep
speed.

### Acceptance Criteria

- [x] On the ground, the car's velocity follows the floor surface, so it
      leaves a ramp top with the slope's upward speed.
- [x] In the air there is no throttle, no re-blend toward the facing
      direction, and yaw at 15-30% of ground yaw.
- [x] Gravity in the air is 1.3-1.8 x 9.8 m/s^2 (start 1.5).
- [x] A clean landing loses no horizontal speed.
- [x] Hang time off the test track's ramps is 0.6-1.2 s or close to it,
      with the ramp geometry adjusted if needed. The car never leaves the
      level: re-measure the apex for the T-024 walls.
- [x] Probes log the launch speed, the apex, the hang time and the
      landing speed. Tests cover these. `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `scenes/arenas/test_track.tscn` (if a ramp needs reshaping)
- tests

### Verification

**Model.**
- **Air:** no throttle, and yaw at `air_steer_share` (0.25) of ground
  yaw. The travel direction is kept from launch (T-028). Gravity is
  `air_gravity_scale` (1.6) x 9.8 m/s^2. These two replace
  `air_control`.
- **Ground:** velocity stays flat, and `move_and_slide()` carries it up
  slopes. This keeps floor contact. An along-slope velocity points
  upward, which turns off Godot's floor snap; the car then flickered
  between ground and air and lost speed on every transition, so that
  approach was dropped.
- **Slope reading:** a short `RayCast3D` from the car's centre reads the
  face under the car. The contact normal at a ramp's foot blends floor and
  slope: it measured 44 degrees on the 15-degree Kenney ramp. If used, it
  kicked the car 15 m/s upward off the base.
- **Launch:** on the first airborne tick going uphill, the car gets the
  last slope's climb rate, `speed x sin(slope)`
  (`launch_vertical_speed`). The flat speed is kept, so a takeoff costs
  nothing.
- **Safety:** off the floor, `move_and_slide()` may never add more upward
  speed than was commanded, so a lip edge cannot launch the car.
- **Landing:** the flat speed is kept and the vertical speed is dropped,
  so there is no speed loss on a clean landing.

**Ramp2 reshaped** from 30 degrees / 8 m to **20 degrees / 2.5 m**. It
keeps the same low end, position, material and `unique_id`.
- Real launches off the old 8 m kicker reached an **apex of 13.15 m**,
  above the 12 m T-024 walls, with **2.03 s** of air. The car landed at
  the north wall.
- The 0.6-1.2 s hang-time target (handling-reference §3) needs a launch
  climb rate of about 6-9 m/s at 24 m/s, which is a 15-22 degree ramp.

**Probe** (full throttle from rest):

| Ramp | Takeoff | Apex | Hang time | Landing speed |
|---|---|---|---|---|
| Kenney ramp, 15 degrees, from z = -45 | 24.0 m/s at 4.66 m | **5.77 m** | **1.20 s** | 24.0 m/s; it clears Ramp2 and lands at z = 19.4 |
| Ramp2, 20 degrees, from z = -5 (6.5 m run-up) | 20.8 m/s at 3.0 m | 4.55 m | **1.17 s** | 20.8 m/s; lands at z = 33.9, 15 m short of the wall |
| Old Ramp2, 30 degrees / 8 m, from z = -5 | 24.0 m/s at 8.66 m | 13.15 m | 2.03 s | reaches the north wall |

**Escape check:** 10 scripted runs of a turn off a ramp, each way, gave
**0 escapes**. The highest car origin is 5.77 m, so the 12 m walls keep
6.2 m of margin (track-geometry rule 4).

**Tests:**
- `launch_vertical_speed`: flat, uphill, downhill and reversing
- airborne: throttle adds no speed, and yaw is 25% of ground
- a Kenney-ramp jump on the real track: apex above 5.3 m, hang 0.9-1.4 s,
  landing above 23.5 m/s

T-021's wedge tests and T-024's apex constant are updated to the new
geometry. `task ci` is green (see the PR).

### Dependencies

- T-028

### Assumptions (owner to validate)

- **Assumption:** About 1.2 s of air off both ramps, with 1.6 g air
  gravity, feels snappy, not floaty.
  **Evidence:** §3 targets 0.6-1.2 s and 1.3-1.8 g. Measured 1.17-1.20 s.
  **Owner check:** Jump both ramps at full speed. If it is floaty, raise
  `air_gravity_scale` toward 1.8. If it is a hop, lower it toward 1.4.
- **Assumption:** Reshaping Ramp2 to 20 degrees / 2.5 m is right for the
  test track. With real launches the old 30-degree 8 m kicker threw the
  car to 13 m and into the north wall.
  **Evidence:** The probe above. Your FC-1 Ramp2 checks were done on the
  old shape.
  **Owner check:** Is a 1.2 s Ramp2 jump big enough? If you want a "big
  air" ramp, it needs a bigger arena or taller bounds.
- **Assumption:** A small air yaw (25%), with no throttle and no
  re-steering of the line, is right.
  **Evidence:** §3 says air control is small, 15-30%, and the speed is
  kept from launch.
  **Owner check:** Steer in the air. The nose should turn a little, but
  the car should not change course. If landings feel uncontrollable,
  raise `air_steer_share`.
- **Assumption:** A takeoff should cost no speed.
  **Evidence:** It is an arcade choice: the flat speed is kept and the
  climb is added.
  **Owner check:** None needed unless jumps feel like a speed boost.
