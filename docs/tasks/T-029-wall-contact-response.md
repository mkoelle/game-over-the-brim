# T-029: Wall Contact Response

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Todo
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §7
item 8 (owner request, FC-1)

### Goal

Walls keep momentum on glancing contact and bounce the car on hard hits.
The owner's FC-1 comment on wall slides was "slow, boring, would like
car to bounce off or keep momentum some".

### Acceptance Criteria

- [ ] A 30-degree glancing contact keeps at least 85% of the speed, and
      the car turns along the wall instead of grinding.
- [ ] A head-on hit above 3 m/s bounces back with 0.3-0.5 of the
      into-wall speed.
- [ ] `impacted` still fires once per hit. The camera shake (T-008) still
      works.
- [ ] A hard hit cancels a drift.
- [ ] A probe at 15, 30, 45 and 90 degrees logs the speed kept and the
      bounce. Tests cover the bounce and the speed kept.
- [ ] `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `test/unit/test_vehicle_controller.gd`

### Verification

A wall-angle probe on the test track's boundary walls.

### Dependencies

- T-028
