# T-027: Steering Curve, Standstill Fade and Steer Ramp

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Todo
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §1

### Goal

Steering that feels like the genre: a turn radius that grows with speed,
no spinning on the spot, and a keyboard that feels like a soft analog
stick.

### Acceptance Criteria

- [ ] Full-lock yaw rate is flat once the car is moving: 1.1-1.4 rad/s at
      10 m/s and 1.2-1.6 rad/s at top speed. The turn radius is 7-9 m at
      10 m/s and 15-20 m at top speed.
- [ ] There is no rotation below about 1 m/s. Steering fades in to full by
      about 6-8 m/s.
- [ ] The steer input ramps from centre to full lock in 0.15-0.2 s, and
      across centre in 0.25-0.3 s. The ramp is tick-based and
      deterministic.
- [ ] Steering in reverse is still not inverted.
- [ ] Unit tests cover the curve and the ramp. A probe measures the
      radius at 3 speeds.
- [ ] `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `resources/vehicles/stovepipe_speedster.tres`
- `test/unit/test_vehicle_controller.gd`

### Verification

A probe drives full-lock circles at 5, 10 and 24 m/s and logs the yaw
rate and the radius.

### Dependencies

None.
