# T-028: Speed and Heading Model, Grip and Drift Slide

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Todo
**Estimate:** 4h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §2, §6

### Goal

A visible, controllable drift that does not bleed speed, on a
frame-rate-independent grip model.

### Acceptance Criteria

- [ ] Velocity comes from a signed scalar speed and a travel heading. The
      heading turns toward the body heading with a time constant: about
      0.06 s gripping and about 0.4 s drifting. There are no per-tick
      lerp factors.
- [ ] The car drifts only with the drift button held, steer applied,
      speed above 40-55% of top, and on the ground.
- [ ] The drift direction locks at entry. Steering inside a drift maps
      to 20-80% of the drift turn and cannot flip the drift.
- [ ] The slide angle in a held in-turn drift reaches 25-45 degrees,
      capped at 35 degrees to start (§6).
- [ ] Drifting does not lose speed by itself.
- [ ] The drift ends on release, below the minimum speed, or in the air.
- [ ] `is_drifting`, `drift_direction` and `slide_angle_deg` are public
      for the debug overlay and the visuals.
- [ ] Unit tests and a probe cover these. `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `resources/vehicles/stovepipe_speedster.tres`
- `scripts/ui/debug_overlay.gd`
- `test/unit/test_vehicle_controller.gd`

### Verification

A probe holds a drift through a long corner and logs the slide angle,
the speed and the drift state.

### Dependencies

- T-027
