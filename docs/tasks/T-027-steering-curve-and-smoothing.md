# T-027: Steering Curve, Standstill Fade and Steer Ramp

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §1

### Goal

Steering that feels like the genre: a turn radius that grows with speed,
no spinning on the spot, and a keyboard that feels like a soft analog
stick.

### Acceptance Criteria

- [x] Full-lock yaw rate is flat once the car is moving: 1.1-1.4 rad/s at
      10 m/s and 1.2-1.6 rad/s at top speed. The turn radius is 7-9 m at
      10 m/s and 15-20 m at top speed.
- [x] There is no rotation below about 1 m/s. Steering fades in to full by
      about 6-8 m/s.
- [x] The steer input ramps from centre to full lock in 0.15-0.2 s, and
      across centre in 0.25-0.3 s. The ramp is tick-based and
      deterministic.
- [x] Steering in reverse is still not inverted.
- [x] Unit tests cover the curve and the ramp. A probe measures the
      radius at 3 speeds.
- [x] `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `resources/vehicles/stovepipe_speedster.tres`
- `test/unit/test_vehicle_controller.gd`

### Verification

**Model.** Yaw at full lock is
`steering_rate x smoothstep(steer_min_speed, steer_full_speed, |speed|)`.
Before, it was `steering_rate x speed / max_speed`. New `VehicleStats`
fields, set in `stovepipe_speedster.tres`:

| Field | Value | Why |
|---|---|---|
| `steering_rate` | 1.4 rad/s (was 2.4) | §1 targets 1.1-1.4 at 10 m/s and 1.2-1.6 at top speed |
| `steer_min_speed` | 1.0 m/s | the recipe's cutoff is 0.75 m/s; §1 says none below about 1 m/s |
| `steer_full_speed` | 7.0 m/s | §1: full by 6-8 m/s |
| `steer_ramp_time` | 0.17 s | STK `time-full-steer` 0.17 s [P] |
| `steer_reverse_time` | 0.28 s per unit when crossing centre | STK 0.28 s when reversing [P] |

The ramp runs in `_physics_process` (`ramp_steer`, pure and tick-based).
`steer_applied` is public for readouts.

**Probe** (full lock at a fixed speed on an open floor, 60 ticks):

| Speed | Yaw rate | Radius | Before (from §1 "Current") |
|---|---|---|---|
| 0.5 m/s | 0 | none (no rotation) | spins slowly |
| 3.0 m/s | 0.36 rad/s | 8.3 m | 10 m |
| 4.9 m/s | 1.03 rad/s | 4.8 m | 10 m |
| 9.8 m/s | **1.40 rad/s** | **7.0 m** | 1.0 rad/s, 10 m |
| 23.5 m/s | **1.40 rad/s** | **16.8 m** | 2.4 rad/s, 10 m |

Steer ramp: centre to full in 0.183 s (11 ticks). Full left to full
right takes 0.467 s.

Speed drifts down a little in a held circle (24 → 23.5 m/s). That is the
re-projection loss T-028 removes.

**Tests:**
- `steer_speed_fade` endpoints
- the ramp reaches full lock on tick 11
- the ramp is slower across centre
- full-lock radius at 10 and 24 m/s on a real car

`task ci`: `Overall Summary: 77 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, `Exit code: 0`.

### Dependencies

None.

### Assumptions (owner to validate)

- **Assumption:** A flat 1.4 rad/s yaw rate, giving a 17 m radius at top
  speed, feels planted at speed and agile in hairpins.
  **Evidence:** It is inside every §1 target range (STK-derived [P/E]).
  **Owner check:** Drive the long straights and the barrier corners. If
  top speed feels too wide, raise `steering_rate` toward 1.6. If it is
  twitchy, lower it toward 1.2.
- **Assumption:** The 0.17 s steer ramp makes the keyboard feel analog
  without adding lag.
  **Evidence:** STK `time-full-steer` [P]. §1 says to get turn-in from
  the ramp, not from a dead time.
  **Owner check:** Tap left and right on the straight. The nose should
  move smoothly, not snap. If corners feel late, lower
  `steer_ramp_time` toward 0.12.
- **Assumption:** The ramp also applies to analog sticks, as in STK.
  **Evidence:** STK ramps all steering input [P].
  **Owner check:** With a gamepad, small stick movements should still
  feel direct. If they feel smeared, ask for the ramp to skip analog
  input.
- **Assumption:** No rotation below 1 m/s is right, even when parking
  against a wall.
  **Evidence:** §1 convention, and the recipe's 0.75 m/s cutoff [P].
  **Owner check:** Stop against a wall and try to turn away. If you feel
  stuck, say so; reversing a little should free the car.
