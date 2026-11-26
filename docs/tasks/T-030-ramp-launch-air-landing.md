# T-030: Ramp Launch, Air Control and Landing

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Todo
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §3

### Goal

Ramps launch the car. The air keeps launch momentum, and landings keep
speed.

### Acceptance Criteria

- [ ] On the ground, the car's velocity follows the floor surface, so it
      leaves a ramp top with the slope's upward speed.
- [ ] In the air there is no throttle, no re-blend toward the facing
      direction, and yaw at 15-30% of ground yaw.
- [ ] Gravity in the air is 1.3-1.8 x 9.8 m/s^2 (start 1.5).
- [ ] A clean landing loses no horizontal speed.
- [ ] Hang time off the test track's ramps is 0.6-1.2 s or close to it,
      with the ramp geometry adjusted if needed. The car never leaves the
      level: re-measure the apex for the T-024 walls.
- [ ] Probes log the launch speed, the apex, the hang time and the
      landing speed. Tests cover these. `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `scenes/arenas/test_track.tscn` (if a ramp needs reshaping)
- tests

### Dependencies

- T-028
