# T-033: Trick Boost Off Ramps

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Todo
**Estimate:** 2h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §3

### Goal

A button press just after takeoff gives a boost on landing.

### Acceptance Criteria

- [ ] The trick input counts 0.05-0.2 s after takeoff. A press up to
      0.2 s before takeoff is buffered.
- [ ] The trick needs at least 50% of top speed. It has a 0.08 s
      cooldown.
- [ ] The boost starts on landing: +25-30% of top speed for 0.6-1.2 s.
- [ ] A visible trick animation plays on the visual body.
- [ ] Tests cover the window, the buffer and the payout. `task ci` is
      green.

### Dependencies

- T-030, T-031
