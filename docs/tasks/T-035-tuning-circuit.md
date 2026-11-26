# T-035: Second, Larger Test Map (Tuning Circuit)

**Assignee:** Claude (Opus)
**Date:** 2026-11-26
**Priority:** P2
**Status:** Done
**Estimate:** 4h
**Phase:** Handling rework support (FC-2)

### Goal

The owner asked: "create a second larger test map, suggest possible
layouts". The layouts are in [test-tracks.md](../design/test-tracks.md),
and this ticket builds option A, the Tuning Circuit.

### Acceptance Criteria

- [x] Five layout options with their pros and cons, and a
      recommendation.
- [x] A closed circuit, much larger than the 100 x 100 m sandbox, with
      a section for each handling system: top speed, hairpin, chicane,
      ramp jump and long sweeper.
- [x] The map follows track-geometry rules 1-4. The jump walls are taller
      than the measured apex plus 2.5 m.
- [x] It is selectable: F4 in game, or `--track=circuit` /
      `task run:circuit`. The sandbox stays the default, so tests and
      `task run` are unchanged.
- [x] It is reproducible: `task track:circuit` regenerates it from a
      corner list.
- [x] It is drivable end to end: an autopilot laps it cleanly. Tests
      cover it. `task ci` is green.

### Context

- **Generator:** `tools/build_tuning_circuit.gd`.
  - A closed polygon of corners, each rounded with an arc of its own
    radius, so the loop always closes.
  - It samples the centreline every 2 m into a `Path3D`.
  - It extrudes `CSGPolygon3D` cross-sections along the path every 1 m:
    a 14 m road, 0.8 m curbs and 1.2 m barriers.
  - It adds the ground, 12 m perimeter walls, the kicker wedge (like
    Ramp2), two 6.5 m jump walls beside the landing, a start line, a
    `Spawn` marker, and its own sun and sky.
- **Map selection:** `GameConfig.TRACKS` and `track_index`, read from
  `--track=` and cycled by F4, which reloads the scene.
  `main.gd._use_selected_track()` swaps the `TestTrack` node for the
  selected map and puts the car at its `Spawn`.
- **Camera:** `CarFollowCam.tween_on_load = false`. Phantom Camera's
  load tween otherwise flew the camera in from the origin, which took
  over 1.5 s for the 70 m spawn. The swap also teleports the follow
  camera one frame later, once Phantom Camera has built its rig.
- **Three fixes found while building:**
  - A zero-length straight (the R35 sweeper's corners are exactly 2R
    apart) repeated a point, and CSG raised "The target vector can't be
    zero". Repeated points are now dropped.
  - An R18 hairpin was flat-out, because it is wider than the 17 m
    full-lock radius at top speed. It is now R10.
  - The map needed its own light and environment, because the sandbox's
    live inside its scene.

### Files Likely Affected

- `tools/build_tuning_circuit.gd` (new)
- `scenes/arenas/tuning_circuit.tscn` (new, generated)
- `scripts/autoload/game_config.gd`
- `scripts/main.gd`
- `scenes/main.tscn` (`tween_on_load`)
- `Taskfile.yml`
- `test/integration/test_tuning_circuit.gd` (new)
- `docs/design/test-tracks.md` (new)

### Verification

**Autopilot probe:** pure pursuit on the centreline. It sets its speed
from the corner speed ahead plus the braking distance, with no drifting.

| Run | Laps | Wall hits | Max off-centre | Min speed | Jump apex |
|---|---|---|---|---|---|
| R18 hairpin | 23.95 / 23.87 / 23.87 s | 0 | — | — | 3.70 m |
| R10 hairpin, simple speed rule | 24.40 / 24.33 / 24.35 s | 3 (6.9 m/s, hairpin exit) | 6.3 m | 21.8 m/s | 3.70 m |
| **R10 hairpin, braking planned (final)** | **24.52 / 24.43 / 24.43 s** | **0** | **6.0 m** (road half-width 7) | **19.6 m/s** | **3.70 m** |

- **Other checks:**
  - The centreline is 571.1 m, 279 points, with no repeats.
  - No errors in a windowed run.
  - Top-down render: `docs/design/track-maps/tuning-circuit-top.png`.
  - In-game screenshot reviewed: the start straight with the start line,
    curbs, barriers, jump walls and perimeter in view.
  - The camera sits behind the car from frame 2.
- **Tests** (5 new):
  - the parts exist, with collision on the road, barriers and kicker
  - the centreline is a clean closed loop of 565-577 m
  - the jump walls are taller than apex + 2.5 m
  - `main.tscn` swaps to the circuit, the car spawns on the road, and 3 s
    of full throttle stays grounded with no wall hit
  - the sandbox is still the default
- `task ci`: `Overall Summary: 116 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-027 to T-034 (the handling the sizes come from).

### Assumptions (owner to validate)

- **Assumption:** A 14 m road suits the hat-cars.
  **Evidence:** [E] Four cars abreast is about 9 m with gaps. A 35-degree
  slide on a 2 m car sweeps about 2.2 m. The rest is margin for
  bumping. No primary source was found for genre track widths.
  **Owner check:** Drive side by side in your head: does it feel wide or
  cramped? Change `ROAD_HALF_WIDTH` and run `task track:circuit`.
- **Assumption:** A 571 m lap (about 24 s for the autopilot, and likely
  25-30 s by hand) is long enough for tuning.
  **Evidence:** It is short next to party-racer laps of 30-40 s [E]. It
  is fine for repeated tuning laps.
  **Owner check:** Say if you want it longer. Add corners to `CORNERS`.
- **Assumption:** The R10 hairpin is the right challenge: it needs a
  brake or a drift.
  **Evidence:** The full-lock radius at top speed is 17 m (T-027). The
  autopilot slows to 19.6 m/s there.
  **Owner check:** Drift it. If it is too tight to enjoy, try R12-R14.
- **Assumption:** A flat map is fine for now.
  **Evidence:** It keeps v1 small. Banking and elevation are options B
  and E in `test-tracks.md`.
  **Owner check:** Say which option to build next.
