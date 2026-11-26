# T-031: Drift Charge, Three Tiers and Boost

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Todo
**Estimate:** 4h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §2
(three tiers: owner decision, FC-1)

### Goal

Drifting charges a boost in three tiers. Releasing pays out the highest
tier reached.

### Acceptance Criteria

- [ ] Charge is counted in physics ticks. It runs at the full rate when
      steering into the drift and about 40% of that when steering out.
- [ ] Tier 1 is reached at about 0.85 s (§6, casual-friendly), tier 2 at
      about 1.9 s and tier 3 at about 3.0 s of in-turn drifting.
- [ ] Releasing pays out a boost of +15-25% of top speed. It lasts 0.5-0.8
      s for tier 1, 1.2-1.7 s for tier 2 and 2.0-2.6 s for tier 3.
- [ ] Dropping below the minimum speed or a hard wall hit cancels the
      charge with no payout.
- [ ] The tier and the boost are public. Signals `drift_tier_reached` and
      `boost_started` let the visuals and the camera react.
- [ ] Tests cover the tier timing, the payout and the cancels, ticks
      included. `task ci` is green.

### Dependencies

- T-028
