# T-037: Smooth Ramp Takeoff (No Hitch at the Crest)

**Assignee:** Claude (Opus)
**Date:** 2026-11-26
**Priority:** P2
**Status:** Done
**Estimate:** 1h
**Phase:** FC-2 feedback ([checklist](../plans/fc-2-owner-checklist.md) §4)

### Goal

Owner feedback at FC-2 on the ramps: "adds a bounce at top, this may be
ok, still debating. The bounce feels like it occurs after leaving the ramp
instead of while on the ramp."

### Acceptance Criteria

- [x] The cause is measured.
- [x] The car rises continuously through the crest, with no level tick
      and no second pop.
- [x] Jumps keep their size, hang time and landing speed. The bounds
      still hold.
- [x] A regression test fails on the old code and passes now. `task ci`
      is green.

### Context

- **Cause, from a tick-by-tick probe of the Kenney ramp's crest:**
  - the car climbs at 5.84 m/s
  - for 4-5 ticks (about 80 ms) its height holds level at 4.66 m: it is
    still "on the floor", because its rear touches the top edge, and
    grounded velocity is flat
  - then it takeoffs with a launch of 5.78 m/s upward
  That rise, hitch and second rise is the bounce the owner felt after
  leaving the ramp.
- **Fixes**, all in `vehicle_controller.gd`:
  1. **Crest:** a grounded car whose centre ray finds nothing, after a
     climb, takes off now.
  2. **Climbing:** on an uphill slope the velocity carries the climb's
     upward speed, `speed x sin(slope)`. That is a little shallower than
     the slope, so the car still presses into it, and it leaves the edge
     already rising.
  3. **No floor snap while climbing:** the snap pulled the car down 7 cm
     onto the edge and held it level for a tick. Snap stays on for bumps
     and downhill.

### Verification

Crest trace, Kenney ramp, full throttle (height rate per tick):

| | Before | After |
|---|---|---|
| on the ramp | 5.84 m/s | 6.23 m/s |
| at the edge | 0.00 for about 5 ticks, then a launch | none: takeoff at 6.04 m/s |
| after takeoff | 5.78, then gravity | 5.78, 5.52, ... (gravity only) |
| takeoff tick | 152 | 144 |

| Jump | Apex | Hang time | Landing speed |
|---|---|---|---|
| Kenney ramp | 5.89 m (was 5.77) | 1.22 s | 24.0 m/s |
| Ramp2 (from z = -5) | 4.37 m | 1.12 s | 18.9 m/s |
| Circuit kicker (autopilot) | 3.81 m (was 3.70); walls 6.5 m | — | laps 24.42 s, no hits |

Tests:
- `test_ramp_crest_has_no_level_hitch`: no tick within 8 of takeoff rises
  slower than 3 m/s. It **fails on `main`** and passes now.
- The apex constants in the level-bounds and circuit tests are updated.

`task ci`: `Overall Summary: 119 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-030

### Assumptions (owner to validate)

- **Assumption:** The bounce you felt was this hitch. The launch itself
  (about 1.2 s of air) is the intended ramp feel.
  **Evidence:** The trace above: rise, hold level, rise again.
  **Owner check:** Jump both ramps and the kicker. If you still feel a
  "bounce", say whether it is at the edge or at the landing.
