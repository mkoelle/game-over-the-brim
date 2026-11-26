# T-033: Trick Boost Off Ramps

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Done
**Estimate:** 2h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §3

### Goal

A button press just after takeoff gives a boost on landing.

### Acceptance Criteria

- [x] The trick input counts 0.05-0.2 s after takeoff. A press up to
      0.2 s before takeoff is buffered.
- [x] The trick needs at least 50% of top speed. It has a 0.08 s
      cooldown.
- [x] The boost starts on landing: +25-30% of top speed for 0.6-1.2 s.
- [x] A visible trick animation plays on the visual body.
- [x] Tests cover the window, the buffer and the payout. `task ci` is
      green.

### Verification

**Model.**
- **Trick button:** the drift button, used just after a ramp launch.
  There is no separate trick button yet.
- **Window:** a trick fires from 0.05 s to 0.2 s after takeoff. A press
  up to 0.2 s before takeoff is buffered (`trick_window_open`, pure).
- **Conditions:** the takeoff needs at least 1 m/s of launch climb (a
  real ramp, not a bump) and at least 50% of top speed.
- **Payout:** landing pays `trick_boost_speed` (6.7 m/s, +28%) for
  `trick_boost_time` (0.9 s). It uses the same boost as T-031, at tier 0.
- **Signals:** `trick_performed`, then `boost_started(0)`.
- **Visual body:** one eased 360-degree barrel roll over 0.45 s, and a
  white boost glow, apart from the three tier hues.

**Probe** (Kenney ramp at full throttle; takeoff at tick 152; a 3-tick
tap):

| Tap relative to takeoff | Trick | Landing boost | Peak speed |
|---|---|---|---|
| -0.40 s | no (too early) | no | — |
| -0.12 s (buffered) | yes | yes | 30.70 m/s |
| 0.00 s | yes | yes | 30.70 |
| +0.10 s | yes | yes | 30.70 |
| +0.20 s | no (window closed) | no | — |
| +0.30 s, +0.50 s | no | no | — |

**Tests:**
- the window rules
- a tap after takeoff fires one trick and one landing boost, peaking above
  29 m/s
- no tap, no trick
- 10 m/s is too slow for a trick
- a trick spin is one full turn

`task ci` is green (see the PR).

### Dependencies

- T-030, T-031

### Assumptions (owner to validate)

- **Assumption:** The drift button doubles as the trick button.
  **Evidence:** It keeps the control set small, which suits couch play,
  and the genre's later entries do the same with the hop button [S].
  There is no conflict, because a drift cannot start in the air.
  **Owner check:** If you trick by accident while trying to drift on
  landing, ask for a separate trick button.
- **Assumption:** A 0.15 s window, plus a 0.2 s buffer, is forgiving but
  still a skill.
  **Evidence:** MKW frames 3-10 plus a 13-frame buffer [S].
  **Owner check:** Tap just as you leave each ramp. If it feels random,
  ask for a wider window.
- **Assumption:** A +28% boost for 0.9 s makes tricks worth doing, but
  not stronger than a tier-3 drift overall.
  **Evidence:** §3: +25-30%, 0.6-1.2 s.
  **Owner check:** Compare a trick landing with a tier-2 drift release.
