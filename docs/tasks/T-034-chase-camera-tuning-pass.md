# T-034: Chase Camera Tuning Pass

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Done
**Estimate:** 2h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §4

### Goal

The camera sells speed, boost and drift.

### Acceptance Criteria

- [x] A boost widens the FOV by about 8 degrees (up to 12 for tier 3),
      with about 0.15 s attack and 0.5 s decay.
- [x] Speed alone adds 0-4 degrees of FOV.
- [x] While drifting, the camera follows about 50-70% of the velocity
      heading, with slower rotation lag (0.35-0.5 s), so the road stays
      in view.
- [x] A boost pulls the camera 0.3-0.6 m further back.
- [x] Split-screen FOV by player count is recorded for later, not built.
- [x] A probe logs the FOV and yaw against the drift and boost state.
      Tests cover this. `task ci` is green.

### Verification

**Model.**
- `ChaseCamSpeedFx` (`GameCamera/SpeedFx`) owns the FOV. `CarFollowCam`
  has no `Camera3DResource`, so `PhantomCameraHost` never writes it.
- **FOV:** `75 + 4 x speed share + boost FOV`. The boost FOV is +10 for
  a trick, and +8, +10 or +12 for tiers 1, 2 and 3.
- **Timing:** attack 0.15 s, decay 0.5 s, frame-rate independent.
- **Pull-back:** a boost adds 0.45 m of spring length, with
  tau 0.25 s.
- **Drift heading:** `ChaseCamYawDriver` blends, over 0.2 s, to 60% of
  the velocity heading while drifting.
- **Deviation from §4:** section 4's 0.35-0.5 s rotation lag in a drift
  multiplied with the drift yaw rate (about 1.7 rad/s). The camera
  lagged 38 degrees and pointed 55 degrees off the body, past the travel
  direction. The drift yaw lag therefore stays 0.15 s, and the 0.2 s
  blend keeps drift entry smooth.

**Probe** (main track, 22 m/s, a tier-2 drift held and released):

| Moment | FOV | Spring length |
|---|---|---|
| top speed, no boost | 79.0 | 4.66 m |
| tier-2 boost | 89.0 at peak | 5.11 m |
| after the boost | back toward 75-79 | 4.66 m |

| Drift camera | Offset from the car body | The slide (travel direction) |
|---|---|---|
| `main`, before | -14.5 degrees (camera stays behind the body) | -35.0 |
| drift lag 0.4 s | -55.4 (past the travel direction) | -35.0 |
| **this PR**, drift lag 0.15 s | **-34.7 (on the travel direction)** | -35.0 |

**Split-screen FOV by player count**, recorded for later and not built:
- 1 player: 75 degrees
- 2 players: 70 degrees
- 3-4 players: 57 degrees (§4: STK uses 80, 65 and 50 [P])

Each viewport will need its own `SpeedFx`.

**Tests** (4 new):
- FOV target math
- the approach rises faster than it falls
- on the real track, top speed gives 79 degrees, and a tier-2 boost
  gives 89 degrees plus the pull-back
- a real drift keeps the camera within 10 degrees of the travel
  direction

`task ci`: `Overall Summary: 111 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-031

### Assumptions (owner to validate)

- **Assumption:** +4 degrees from speed, and +8 to +12 from a boost,
  sells speed without making you sick.
  **Evidence:** §4: +0 to +4 by speed, +8 (up to +12) for boost, with
  0.15 s in and 0.5 s out.
  **Owner check:** Boost down the long straight. If the widening feels
  like a fish-eye, lower `boost_fov_by_tier` in `GameCamera/SpeedFx`.
- **Assumption:** In a drift the camera should look down the travel
  direction, so the slide shows as the car angled across the screen.
  **Evidence:** §4 says to follow 50-70% of the velocity heading so the
  road stays in view. The probe shows the camera on the travel
  direction.
  **Owner check:** Hold a drift through a full circle. If the car looks
  too sideways, lower `drift_velocity_heading_weight` toward 0.4.
- **Assumption:** A 0.45 m pull-back on a boost reads as "faster",
  without losing the car.
  **Evidence:** §4: 0.3-0.6 m.
  **Owner check:** None needed unless the car looks small in a boost.
