# T-034: Chase Camera Tuning Pass

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Todo
**Estimate:** 2h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §4

### Goal

The camera sells speed, boost and drift.

### Acceptance Criteria

- [ ] A boost widens the FOV by about 8 degrees (up to 12 for tier 3),
      with about 0.15 s attack and 0.5 s decay.
- [ ] Speed alone adds 0-4 degrees of FOV.
- [ ] While drifting, the camera follows about 50-70% of the velocity
      heading, with slower rotation lag (0.35-0.5 s), so the road stays
      in view.
- [ ] A boost pulls the camera 0.3-0.6 m further back.
- [ ] Split-screen FOV by player count is recorded for later, not built.
- [ ] A probe logs the FOV and yaw against the drift and boost state.
      Tests cover this. `task ci` is green.

### Dependencies

- T-031
