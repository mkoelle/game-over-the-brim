# T-039: Boost Gauge, Contextual Boost Tap, Overcharge Drain

**Assignee:** Claude (Opus)
**Date:** 2026-11-26
**Priority:** P2
**Status:** Done
**Estimate:** 3h
**Phase:** Boost and drift depth ([proposal](../design/boost-meter-and-drift-chains.md), owner choices 2b and 3c)

### Goal

Build up a boost over time, and spend it with the drift button when not
turning. Unused overcharge drains away. This follows the owner's FC-2
questions and the choices "Hybrid + contextual space" and "Overcharge
drain".

### Acceptance Criteria

- [x] **Hybrid:** a drift release still pays its tier at once (T-031),
      **and** banks 1/3, 2/3 or 1 segment for tiers 1, 2 and 3, times the
      chain bonus (T-038). A trick landing banks 1/3.
- [x] **Gauge:** 3 base segments, and above them a hot 4th overcharge
      segment. Charge beyond that is lost. The overcharge drains at 0.25
      per second after 2 s with no new charge. The base never drains.
- [x] **Contextual space:** on the ground, a tap of the drift button
      (under 0.15 s, never steered past 0.3, never became a drift) spends
      one segment, the overcharge first: +4.8 m/s for 1.0 s, stacked
      onto a running boost.
      - hold and steer is a drift, as before
      - in the air the button still tricks
- [x] **On the car:** four pips on its back show the gauge, with no HUD
      bar (§6). The hot pip pulses orange. The gauge boost glows gold, and
      the FOV widens by 9 degrees.
- [x] Tests cover these. `task ci` is green.

### Context

- **Tap rule.** The proposal warned about the press-before-steer habit.
  A press that is still held after 0.15 s, or that steers, is never a
  boost, so a drift started by pressing first and then steering never
  spends the gauge. The cost is that the boost starts on release, up to
  0.15 s after the press.
- **Public state:**
  - `boost_gauge` and `boost_overcharge`, and the signal
    `gauge_changed(segments, overcharge)`
  - `boost_tier` 4 is a gauge boost
- `bank_into()`, `is_boost_tap()` and `VehicleVisualBody.pip_fill()` are
  pure and tested.

### Verification

Probe: an open floor at 22 m/s and full throttle, scripted presses.

| Step | Result |
|---|---|
| Drift right 2.0 s (tier 2), release | tier-2 boost of 1.45 s; gauge 0.667 |
| 0.3 s later, drift left 3.2 s (tier 3, chain x1) | boost 2.87 s (2.3 x 1.25); bank 1.25; gauge 1.917 |
| Tap with no steer | gauge boost (tier 4) stacked onto the rest: 2.16 s; gauge 0.917; peak 28.8 m/s |
| Tap while steering | it starts a drift and the gauge stays 0.917 |

Screenshot (chase camera, gauge 2.5 plus hot 0.8): two bright gold pips,
one at half, and the hot pip pulsing orange on the car's back.

Tests (7 new):
- banking fills the base, then the overcharge, then drops the rest
- the tap rule
- a tier-1 release banks 1/3
- a tap spends a segment and boosts
- no spend under one segment, on a long press, or on a steered tap
- the overcharge drains at 0.25 per second and the base does not
- the pips fill by segment and exist on the car

`task ci`: `Overall Summary: 129 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-031, T-033, T-038

### Assumptions (owner to validate)

- **Assumption:** The tap rule stops accidental spends for players who
  press before they steer.
  **Evidence:** A held or steered press never spends. The probe and the
  tests show it.
  **Owner check:** Drive normally for a few laps. If the gauge ever
  empties when you meant to drift, say so, and the tap window can
  shrink.
- **Assumption:** Up to 0.15 s of boost lag on a tap is acceptable.
  **Evidence:** The boost has to start on release to tell a tap from a
  hold.
  **Owner check:** If boosts feel late, consider a separate boost button
  (proposal option 2a).
- **Assumption:** The segment sizes (1/3, 2/3, 1), +4.8 m/s for 1 s, and
  the overcharge rules (2 s grace, 4 s to drain) are a fair first
  balance.
  **Evidence:** One tier-3 drift buys one boost, and a chained S-bend
  overfills into the hot segment.
  **Owner check:** Chain the chicane into the sweeper on the circuit and
  watch the pips. Tune the constants at the top of
  `vehicle_controller.gd`.
- **Assumption:** The pips are readable at chase distance.
  **Evidence:** The screenshot above. They are small (0.16 m).
  **Owner check:** Say if they need to be bigger or brighter
  (`PIP_SIZE` in `vehicle_visual_body.gd`).
