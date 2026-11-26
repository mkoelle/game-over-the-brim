# T-031: Drift Charge, Three Tiers and Boost

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 4h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §2
(three tiers: owner decision, FC-1)

### Goal

Drifting charges a boost in three tiers. Releasing pays out the highest
tier reached.

### Acceptance Criteria

- [x] Charge is counted in physics ticks. It runs at the full rate when
      steering into the drift and about 40% of that when steering out.
- [x] Tier 1 is reached at about 0.85 s (§6, casual-friendly), tier 2 at
      about 1.9 s and tier 3 at about 3.0 s of in-turn drifting.
- [x] Releasing pays out a boost of +15-25% of top speed. It lasts 0.5-0.8
      s for tier 1, 1.2-1.7 s for tier 2 and 2.0-2.6 s for tier 3.
- [x] Dropping below the minimum speed or a hard wall hit cancels the
      charge with no payout.
- [x] The tier and the boost are public. Signals `drift_tier_reached` and
      `boost_started` let the visuals and the camera react.
- [x] Tests cover the tier timing, the payout and the cancels, ticks
      included. `task ci` is green.

### Verification

**Model.**
- **Charge:** an integer count, +5 per tick when steering into the drift
  and +2 otherwise (MKW 5/2 [S]).
- **Tiers:** a tier is reached at `round(drift_tier_times[i] x 60) x 5`,
  with `drift_tier_times` = 0.85, 1.9 and 3.0 s.
- **Payout:** releasing the button ends the drift and pays out the tier
  reached.
- **Boost:** for `boost_times` (0.7, 1.45 and 2.3 s), the top speed rises
  by `boost_speed`, 4.8 m/s (+20%), and `boost_acceleration` (25 m/s^2)
  pushes toward it. Afterwards the speed eases back at 8 m/s^2 rather
  than snapping down.
- **Cancel, with no payout:** speed below 80% of the minimum, more than
  0.3 s in the air, or a wall hit of 6 m/s or more.
- **Public state:** `drift_tier`, `boost_tier` and `boost_time_left`,
  plus the signals `drift_tier_reached`, `boost_started` and
  `boost_ended`. The overlay shows the tier and the boost.

**Probe** (22 m/s, full throttle, drift held, then released):

| Hold | Steer | Tiers reached (time in drift) | Boost paid | Boost length | Peak speed |
|---|---|---|---|---|---|
| 0.67 s | in | none | none | — | — |
| 0.95 s | in | t1 at 0.85 s | tier 1 | 0.70 s | 28.8 m/s |
| 2.00 s | in | t1 at 0.85, t2 at 1.90 | tier 2 | 1.47 s | 28.8 |
| 3.17 s | in | t1 at 0.85, t2 at 1.90, t3 at 3.00 | tier 3 | 2.30 s | 28.8 |
| 0.95 s | out | none | none | — | — |
| 2.50 s | out | t1 at 2.08 s (40% rate) | tier 1 | 0.70 s | 28.8 |

After each boost the speed returns to 24.0 m/s.

**Tests:**
- tier thresholds
- a tier-2 release pays a boost above top speed, then eases back
- steering out charges slower
- braking below the minimum cancels with no boost

`task ci` is green (see the PR).

### Dependencies

- T-028

### Assumptions (owner to validate)

- **Assumption:** Tier times of 0.85, 1.9 and 3.0 s suit casual players,
  so tier 1 comes on a normal corner.
  **Evidence:** §2 targets 0.9-1.0, 1.9-2.5 and 3.0 s. §6 says to shorten
  tier 1.
  **Owner check:** Drift the barrier corners. If tier 1 rarely lands,
  shorten `drift_tier_times[0]`. If tier 3 is too easy, lengthen it.
- **Assumption:** One boost strength (+4.8 m/s) for every tier, with only
  the length growing, reads clearly.
  **Evidence:** This is the genre pattern (§2).
  **Owner check:** If tier 3 does not feel worth the risk, ask for a
  stronger tier-3 boost.
- **Assumption:** A boost keeps working with throttle released on the
  ground. In the air it adds no speed.
  **Evidence:** It is an arcade convention. T-030 removed throttle in the
  air, and the boost follows the same rule.
  **Owner check:** None needed unless a boost off a ramp feels wasted.
- **Assumption:** The tier is readable from the overlay until T-032 adds
  sparks and tint.
  **Evidence:** Until T-032, the overlay line `Drift: R, slide +35 deg,
  tier 2` is the only cue.
  **Owner check:** Check this at FC-2, after T-032.
