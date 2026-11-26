# T-036: Intro Camera Vantage, and Jump Walls Without Z-Fighting

**Assignee:** Claude (Opus)
**Date:** 2026-11-26
**Priority:** P2
**Status:** Done
**Estimate:** 1h
**Phase:** FC-2 feedback ([checklist](../plans/fc-2-owner-checklist.md))

### Goal

Two items of owner feedback on T-035:
- "The camera flying in from the world origin was a nice visual on the
  smaller map, but too much on the circuit. Instead of removing it
  altogether, pick a nice vantage point above and behind the car at the
  start."
- "The walls near the ramp on the circuit clip over the barriers and
  cause visual noise while driving around."

### Acceptance Criteria

- [x] Every load starts on a still shot above and behind the car, and
      flies smoothly to the chase camera. This holds on both maps, and
      again after F4.
- [x] The jump walls and the barriers share no faces, so nothing
      z-fights. The walls still contain the jump (track-geometry rule
      4), and there is no gap between wall and barrier.
- [x] Tests cover both. `task ci` is green.

### Context

- **Intro.** Phantom Camera starts its first tween from the active
  camera's own pose. Before this, that pose was `CarFollowCam` sitting
  at the origin before it followed: the old fly-in. T-035 then turned
  that tween off.
  - Now an `IntroCam` (a `PhantomCamera3D` at priority 20) is placed by
    `main.gd` at `Main.intro_vantage(car)`: 22 m behind the car, 10 m up
    and 7 m to its right, looking at it. That is about 22 degrees down
    from 25 m away.
  - After `INTRO_HOLD` (0.4 s), its priority drops to 0. Phantom Camera
    then flies to `CarFollowCam` with that camera's tween resource:
    1.8 s, cubic, ease in-out.
  - `GameConfig.play_intro` turns the intro off. The four tests that
    check the chase camera from the first frames use it.
- **Jump walls.** They were 6.5 m boxes at exactly the barrier's
  position (x = 8.8-9.3 m from the centreline, from the ground up). The
  lower 1.2 m therefore shared the barrier's faces and z-fought, which is
  the "clip over" flicker. Now each wall starts 1 cm inside the barrier
  top (y = 1.19 m) and reaches 6.5 m, with its faces 5 cm out from the
  barrier's (x = 8.85-9.35 m). The containment height is unchanged.

### Files Likely Affected

- `scenes/main.tscn` (`IntroCam`, and the `CarFollowCam` tween at 1.8 s
  cubic)
- `scripts/main.gd`, `scripts/autoload/game_config.gd`
- `tools/build_tuning_circuit.gd`, `scenes/arenas/tuning_circuit.tscn`
- tests

### Verification

- **Camera path** (windowed, on both maps):
  - frames 2-50: the camera holds at the vantage: (7, 10.6, 2) on the
    sandbox and (7, 10.6, 92) on the circuit, 22 m behind the car
  - it then eases in, and by frame 200 it is at the chase position, for
    example (0.1, 2.8, 74.7) on the circuit
- **Screenshots** reviewed (not committed):
  - the circuit's opening shot shows the car on the start straight, the
    start line, and the corners beyond
  - the sandbox's opening shot shows the car centred, with the ramp and
    barriers around it
- **Jump-wall screenshot** from the back straight: the white barrier runs
  under the orange wall with a clean seam and no flicker.
- **Tests:**
  - `intro_vantage` is behind, above, right and looking at the car
  - a real load flies from more than 20 m away to under 6 m from the car
  - the jump wall is taller than apex + 2.5 m, its bottom sits just
    inside the barrier top, and its inner face is at least 1 cm from the
    barrier's
- `task ci`: `Overall Summary: 118 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-035

### Assumptions (owner to validate)

- **Assumption:** 22 m back, 10 m up and 7 m right, with a 0.4 s hold and
  a 1.8 s cubic fly-in, makes a "nice vantage".
  **Evidence:** The screenshots above.
  **Owner check:** Start each map (and press F4). Tune `INTRO_BACK`,
  `INTRO_UP`, `INTRO_SIDE` and `INTRO_HOLD` in `scripts/main.gd`, or the
  tween on `CarFollowCam`.
- **Assumption:** Solid 6.5 m walls are acceptable now that they no
  longer flicker.
  **Evidence:** Rule 4 needs them, because a car can take off from the
  kicker at an angle.
  **Owner check:** If they still feel heavy, ask for a see-through catch
  fence above the barriers instead.
