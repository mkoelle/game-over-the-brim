# T-029: Wall Contact Response

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §7
item 8 (owner request, FC-1)

### Goal

Walls keep momentum on glancing contact and bounce the car on hard hits.
The owner's FC-1 comment on wall slides was "slow, boring, would like
car to bounce off or keep momentum some".

### Acceptance Criteria

- [x] A 30-degree glancing contact keeps at least 85% of the speed, and
      the car turns along the wall instead of grinding.
- [x] A head-on hit above 3 m/s bounces back with 0.3-0.5 of the
      into-wall speed.
- [x] `impacted` still fires once per hit. The camera shake (T-008) still
      works.
- [x] A hard hit cancels a drift.
- [x] A probe at 15, 30, 45 and 90 degrees logs the speed kept and the
      bounce. Tests cover the bounce and the speed kept.
- [x] `task ci` is green.

### Files Likely Affected

- `scripts/vehicles/vehicle_controller.gd`
- `scripts/resources/vehicle_stats.gd`
- `test/unit/test_vehicle_controller.gd`

### Verification

**Model** (`_respond_to_wall`, after `move_and_slide()`):
- **Slide:** `move_and_slide()` already removes the into-wall part. Since
  T-028, the next tick reads the rest back as speed and travel direction,
  so the speed along the wall is kept.
- **Bounce:** at 3 m/s or more into the wall (the T-008 shake
  threshold), `wall_restitution` (0.4) of the into-wall speed is added
  back out along the normal. That is `wall_bounce`, a pure function.
- **Glancing hit** (approach under 60 degrees from the wall surface): the
  body turns along the wall with `wall_align_time` (0.1 s). It keeps
  turning for 0.25 s after contact, so it does not stay pointed in and
  grind.
- **Head-on hit:** the car bounces straight back and keeps its heading.
- **Drift:** a hit of 6 m/s or more into the wall ends the drift.
- **Re-arm:** `WALL_REARM_TIME` went from 0.1 to 0.3 s. When the body
  swings parallel, its rear clips the wall, and that touch now counts as
  the same hit, so there is one shake per crash.

**Probe:** a 24 m/s approach to a long wall, logged 0.5 s after the hit
(c = coasting, t = full throttle).

| Approach | Speed kept, c / t | Bounce out | Nose into wall after | Impacts, c / t | `main` with throttle |
|---|---|---|---|---|---|
| 15 degrees | 97% / 100% | 2.5 m/s | 0.0 degrees | 1 / 1 | 100%, nose stays 15 degrees in |
| 30 degrees | **88%** / 100% | 4.8 m/s | 0.1 degrees | 1 / 1 | 94%, nose stays 30 degrees in |
| 45 degrees | 75% / 100% | 6.8 m/s | 0.3-0.6 degrees | 2 (2nd is 0.2 m/s) / 1 | 63% |
| 90 degrees (head-on) | bounces back at **9.6 m/s** (0.40) | 9.6 m/s | 90 | 1 / 3 decaying | 0%, dead stop |

**Tests:**
- `wall_bounce` and `wall_approach_deg`
- a head-on hit bounces back at 0.4 x the impact
- a 30-degree coasting hit keeps more than 85% and aligns within 2
  degrees
- a hard hit ends a drift
- two older tests were rewritten for the new behavior:
  - the shallow scrape now fires once, keeps over 95% of its speed and
    ends parallel
  - "a new hit" uses two separate coasting runs

`task ci`: `Overall Summary: 89 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-028

### Assumptions (owner to validate)

- **Assumption:** A restitution of 0.4 gives a bounce that reads as fun,
  not punishing: a head-on hit at 24 m/s sends the car back at 9.6 m/s.
  **Evidence:** It is in the owner-approved 0.3-0.5 starting range
  (handling-reference §7 item 8).
  **Owner check:** Drive head-on into a boundary wall at full speed. If
  the bounce feels too springy, lower `wall_restitution` toward 0.3. If
  it feels too dead, raise it toward 0.5.
- **Assumption:** Holding throttle into a wall after a head-on hit should
  give a few shrinking bounces, each with a small shake (24, then 9.5,
  then 3.7 m/s), not a stuck car.
  **Evidence:** The probe above, and the owner's "bounce off".
  **Owner check:** If the repeat bounces feel like jitter, ask for a
  cooldown on re-bounces.
- **Assumption:** Turning the nose along the wall on glancing hits (0.1 s,
  held 0.25 s) feels like the car glances off, not like the game steering
  for you.
  **Evidence:** Without it the nose stays pointed in and the car grinds:
  15-30 degrees into the wall on `main`.
  **Owner check:** Scrape the inner barriers at an angle. If the car
  seems to steer itself, raise `wall_align_time`.
