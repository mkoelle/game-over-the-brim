# T-013: `RoadLane` Follower Probe (AI Path Check)

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P3
**Status:** Todo (the 1-Car Fun gate passed at FC-2, 2026-11-26)
**Estimate:** 2h
**Phase:** 3 — Track building ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-017](../adr/ADR-017-track-tooling-road-generator-and-scatter.md), [ADR-011](../adr/ADR-011-ai-state-machine-addon-limboai.md)

### Goal

Check that Road Generator's generated lanes can drive an agent around the
loop continuously. This is the path source for future ambient traffic and
AI bots, which LimboAI will make decisions for.

### Acceptance Criteria

- [ ] A probe agent (a plain box `Node3D`) follows a lane at 20 m/s for
      three laps without stopping, teleporting or reversing.
- [ ] Findings are recorded in ADR-017:
  - lane continuity across segments
  - how the next lane is found
  - whether lane changes are exposed
  - `RoadLaneAgent` cost (upstream #273)
- [ ] The probe lives under `test/play/` and is not referenced by the game.

### Context

- The probe is throwaway validation, not the bot driver. Bot driving
  later goes through `InputSource` (an AI input source) per Architecture
  Decision 01. It must not move a car directly.

### Files Likely Affected

- `test/play/lane_follower_probe.tscn` (new)
- `test/play/lane_follower_probe.gd` (new)

### Implementation Plan

1. Branch `spike/roadlane-probe`.
2. Instance `road_loop_track.tscn` in the probe scene. Add a `MeshInstance3D`
   box with the probe script.
3. First try the addon's `RoadLaneAgent` API, if present in 0.9.5. If it
   is not suitable, fall back to sampling the lane's `Curve3D` by distance
   and hopping to the next lane at the end of each curve.
4. Run for three laps and log any lane-hop discontinuity (a position jump
   of more than 0.5 m).
5. Write the findings into ADR-017.

### Verification

Run Current Scene on `lane_follower_probe.tscn`: the box completes three
laps smoothly, and the Output log shows no discontinuities.

### Dependencies

- T-012 (kept, not dropped)
