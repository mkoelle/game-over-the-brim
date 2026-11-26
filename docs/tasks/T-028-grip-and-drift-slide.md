# T-028: Speed and Heading Model, Grip and Drift Slide

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 4h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §2, §6

### Goal

A visible, controllable drift that does not bleed speed, on a
frame-rate-independent grip model.

### Acceptance Criteria

- [x] Velocity comes from a signed scalar speed and a travel heading. The
      heading turns toward the body heading with a time constant: about
      0.06 s gripping and about 0.4 s drifting. There are no per-tick
      lerp factors.
- [x] The car drifts only with the drift button held, steer applied,
      speed above 40-55% of top, and on the ground.
- [x] The drift direction locks at entry. Steering inside a drift maps
      to 20-80% of the drift turn and cannot flip the drift.
- [x] The slide angle in a held in-turn drift reaches 25-45 degrees,
      capped at 35 degrees to start (§6).
- [x] Drifting does not lose speed by itself.
- [x] The drift ends on release, below the minimum speed, or in the air.
- [x] `is_drifting`, `drift_direction` and `slide_angle_deg` are public
      for the debug overlay and the visuals.
- [x] Unit tests and a probe cover these. `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `resources/vehicles/stovepipe_speedster.tres`
- `scripts/ui/debug_overlay.gd`
- `test/unit/test_vehicle_controller.gd`

### Verification

**Model.**
- Each tick reads the speed (the signed length of the flat velocity) and
  the travel direction (its unit direction) straight from `velocity`.
  It no longer projects the velocity onto the facing direction, so a
  slide or a wall cannot bleed speed by itself, and an outside velocity
  change (a respawn, a wall, a test) is kept.
- On the ground the travel direction turns toward the body heading by
  `1 - exp(-delta / tau)` per tick:
  - `grip_time` 0.06 s
  - `drift_slide_time` 0.4 s (handling-reference §2, derived slide time
    constant)
- In the air the travel direction is kept.

**Drift.**
- **Entry:** the drift button is held, raw steer is at least 0.3, the
  car is moving forward at `drift_min_speed` (11 m/s, 46% of top) or
  more, and it is grounded.
- **Lock:** the direction is fixed at entry.
- **Steering:** steer maps to 20-80% (STK [P]) of
  `steering_rate x drift_turn_multiplier` (1.5).
- **Slide cap:** `max_slide_angle_deg` 35 (§6).
- **End:** on release, below 80% of the minimum speed, or after 0.3 s in
  the air.
- **Public state:** `speed`, `is_drifting`, `drift_direction` and
  `slide_angle_deg`, plus the signals `drift_started` and `drift_ended`.
  The debug overlay shows the drift side and the slide.

**Probe** (open floor, 20 m/s, 2 s of held drift):

| Steer inside the drift | Slide angle | Speed after 3 s |
|---|---|---|
| full in-turn | 35.0 degrees (cap) | 20.00 m/s |
| neutral | 23.2 degrees | 20.00 m/s |
| full out-turn | 9.4 degrees | 20.00 m/s |
| no drift, full lock (grip) | 4.2 degrees | 20.00 m/s |

- Releasing returns the slide to 0 within 40 ticks.
- At 9 m/s no drift starts.

**Tests** (8 new):
- speed and direction helpers
- the slide clamp and the turn
- the 20-80% steer share
- the entry rules
- a held drift slides at 25-35 degrees with no speed loss
- the direction lock holds through a steer flip, and release ends the
  drift
- no drift below the minimum speed
- a grip circle keeps its speed

`task ci`: `Overall Summary: 85 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-027

### Assumptions (owner to validate)

- **Assumption:** A 35-degree slide cap, about 23 degrees neutral and
  about 9 degrees steering out, gives a drift that reads clearly and
  stays controllable.
  **Evidence:** §2 targets 25-45 degrees, and §6 caps it at 35 for hat
  readability. The probe numbers are above.
  **Owner check:** Hold a drift through the barrier corners with F3 on.
  The slip label should read about 20-35 degrees. If it feels too loose,
  lower `drift_slide_time` (0.4) or `max_slide_angle_deg`.
- **Assumption:** Drifting does not slow the car at all.
  **Evidence:** §2 says there is no speed loss from drifting itself
  (MKW [S]).
  **Owner check:** If drifting feels like a free lunch, ask for a small
  drift drag.
- **Assumption:** A minimum drift speed of 11 m/s (46% of top) suits
  casual players.
  **Evidence:** §2 range 40-55%. STK uses 10 m/s [P].
  **Owner check:** Try to drift a slow hairpin. If you cannot start one
  where you want to, lower `drift_min_speed`.
- **Assumption:** Normal grip with a 0.06 s time constant (about 4
  degrees of slip at full lock) feels planted, not icy.
  **Evidence:** §2 says 0.05-0.08 s while gripping [E].
  **Owner check:** A normal full-lock turn should feel stuck to the road.
  If it feels slidey, lower `grip_time` toward 0.04.
- **Assumption:** A drift should survive a short hop (0.3 s in the air).
  **Evidence:** Genre hops keep the drift. T-032 adds the visual hop.
  **Owner check:** Drift over a bump or a ramp lip. It should not cancel
  unexpectedly.
