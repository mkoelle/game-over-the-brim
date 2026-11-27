# T-012: Spike Road Generator 0.9.5 (Loop Track)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P2
**Status:** Todo (the 1-Car Fun gate passed at FC-2, 2026-11-26)
**Estimate:** 4h
**Phase:** 3 — Track building ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-017](../adr/ADR-017-track-tooling-road-generator-and-scatter.md)

### Goal

Prove or disprove that Road Generator builds a drivable, performant
circuit for our `CharacterBody3D` car on Godot 4.7.2. Record a keep or
drop decision in ADR-017.

### Acceptance Criteria

- [ ] `addons/road-generator/` (the folder name as shipped) is vendored at
      0.9.5 and enabled.
- [ ] `scenes/arenas/road_loop_track.tscn` contains a closed loop of about
      400 m:
  - two lanes
  - one elevation change
  - one tight hairpin
  - generated collision on layer 1 (Track)
- [ ] The car drives three laps with no fall-through, no seam snagging and
      no `is_on_floor()` flicker at RoadPoint joins (check with T-007
      vectors if available).
- [ ] FPS with one car is at least 60 on the dev machine. Editor
      responsiveness while editing RoadPoints is noted (upstream #361).
- [ ] ADR-017 is updated with the results and a keep or drop decision.

### Context

- 0.9.5 was released 2026-10-13; `main` supports Godot 4.4+. Pure GDScript.
- This is a gate: it blocks T-013 and any further Road Generator use.
- Fallback if dropped: `Path3D` + `CSGPolygon3D` baked to a mesh (ADR-017
  alternative 1).

### Files Likely Affected

- `addons/road-generator/` (vendored)
- `project.godot`
- `scenes/arenas/road_loop_track.tscn` (new)

### Implementation Plan

1. Owner approval to vendor (AGENTS.md Boundaries). Branch
   `spike/road-generator`.
2. Re-verify the latest tag with `gh api` and read the release notes since
   0.9.5, if any. Vendor from the release archive.
3. Enable the plugin, then `task import && task ci`.
4. Build the scene: `RoadManager` → `RoadContainer` → RoadPoints placed
   as a loop. Set the lane count, enable collision generation, and set
   the generated body's layer to 1. Add a `TophatCar` instance, a camera
   (from T-005 if merged, otherwise the old `ChaseCamera`) and the
   `DebugOverlay`, so the scene runs standalone with **Run Current Scene**.
5. Drive three laps, watching the floor state at every RoadPoint join.
   Measure FPS in F3.
6. Inspect the generated `RoadLane` nodes: are they continuous across
   segments, and do they have next/prior links? This feeds T-013.
7. Write the results into ADR-017.

### Verification

Run Current Scene on `road_loop_track.tscn`: three clean laps at 60+ FPS,
with the results recorded in ADR-017.

### Dependencies

- Iteration 01 "1-Car Fun" gate passed (STATE.md).
