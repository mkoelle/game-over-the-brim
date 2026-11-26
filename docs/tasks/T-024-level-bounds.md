# T-024: Keep the Car Inside the Test Track

**Assignee:** Claude (Opus, ADR-022 FC-1 feedback)
**Date:** 2026-11-25
**Priority:** P1
**Status:** Done
**Estimate:** 2h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md)), FC-1 feedback

### Goal

Stop the car from leaving the level. This was FC-1 owner feedback
([checklist](../plans/fc-1-owner-checklist.md), track): "making a right
turn while driving off the second ramp can allow you to jump out of the
level".

### Acceptance Criteria

- [x] The escape is reproduced and measured.
- [x] No scripted turn off either ramp clears a boundary wall.
- [x] If a car ever falls out of the level, it is put back at its spawn
      pose, and the camera follows without a long swoop.
- [x] The rule is written down
      ([track-geometry.md](../design/track-geometry.md) rule 4).
- [x] `task ci` is green. The new tests fail on the old walls.

### Context

- **Cause.** Ramp2 is 22 m from the west wall (x = -49.5), and the car
  leaves its top edge at 8.6 m and 24 m/s. A right turn near the top edge
  points it west. It reaches the wall still about 6 m up, and the wall was
  3 m tall. Outside there is no floor, so it fell forever (y = -92 after
  a few seconds). The same happens off the Kenney ramp, jumping onto
  Ramp2.
- **Fix 1, walls.** All four boundary walls go from 3 m to 12 m
  (`size.y` 12, centre y 6). That covers the highest car origin measured,
  8.64 m, plus half the car and 2 m of margin. The highest point will rise
  when the handling rework makes ramps launch upward (T-017 section 3),
  so track-geometry rule 4 says to re-measure then.
- **Fix 2, safety net.** A new `OutOfBoundsReset` (`scripts/tracks/`)
  runs once per car. Below `kill_height` (-20 m) it puts the car back at
  the pose it had when assigned, zeroes its velocity, resets physics
  interpolation, and emits `car_reset`. `main.gd` creates one for the car
  and calls the follow camera's `teleport_position()` on `car_reset`. A
  race manager with checkpoints can later replace the spawn pose.

### Files Likely Affected

- `scenes/arenas/test_track.tscn` (the four `Boundary*` walls only)
- `scripts/tracks/out_of_bounds_reset.gd` (new)
- `scripts/main.gd`
- `test/integration/test_level_bounds.gd` (new)

### Verification

The escape probe gives full throttle up a ramp, then full or 0.6 steer
left or right, starting at 5 points around the top edge. It counts runs
where the car crosses |x| or |z| > 49.

| Walls | Runs | Escaped | Highest car origin |
|---|---|---|---|
| 3 m (main) | 40 | **13** | n/a |
| 12 m (this branch) | 40 | **0** | 8.65 m |

`test/integration/test_level_bounds.gd`:
- Every boundary wall's top is at least apex + 0.5 + 2 m.
- A car placed airborne just past Ramp2's top, 9 m up and flying west at
  top speed, never crosses a boundary and never needs the reset.
- A car placed below `kill_height` is back at spawn within 3 physics
  ticks, with `car_reset` emitted once for that car.

On the old 3 m walls, the first two tests fail (6 failures).

Screenshot (windowed, not committed): the 12 m orange walls now fill the
horizon band behind the track.

### Dependencies

- T-021 (Ramp2 wedge).

### Assumptions (owner to validate)

- **Assumption:** 12 m solid walls are acceptable on the test track, even
  though they fill much more of the view.
  **Evidence:** They are the simplest visible bound (track-geometry
  rule 3), and this track is a sandbox.
  **Owner check:** Drive around once. If the walls feel boxed-in, ask for
  a 3 m wall plus a see-through fence above it.
- **Assumption:** Respawning at the start pose is fine for feel testing.
  **Evidence:** It only fires after a fall below -20 m, which the walls
  now prevent in all scripted cases.
  **Owner check:** None needed unless it triggers during a drive. If it
  does, note where you left the level.
