# ADR-017: Track Tooling — Road Generator and Scatter

**Status:** Accepted (adoption deferred until the "1-Car Fun" gate passes)

**Date:** 2026-11-24

---

### Context

[race-modes.md](../design/race-modes.md) needs these track and world
features:

- Circuit tracks and an open city.
- Ambient AI traffic following lanes.
- AI bot drivers.
- Props: barriers, cones, clutter.

The current `test_track.tscn` is hand-placed `StaticBody3D` boxes. That is
fine for one sandbox, but it does not scale to many tracks or to a lane
network that AI can follow.

Two parts of this are generic tooling: building road meshes and collision
along splines, and scattering props. Track *design* (shortcut placement,
hazard spots, route gates) stays ours per
[ADR-012](ADR-012-self-implementation-boundary.md).

---

### Decision

Adopt two editor addons when track building starts (after Iteration 01's
"1-Car Fun" gate):

**1. Road Generator** (`TheDuckCow/godot-road-generator`, MIT)
- Pin **0.9.5** (released 2026-10-13; `main` supports Godot 4.4+). Verified
  via `gh api` on 2026-11-24.
- Provides spline-based roads, lane-count changes, intersections and
  generated collision.
- Provides `RoadLane` paths that AI agents can follow. This is the planned
  lane network for ambient traffic and the bot-driver path source under
  [ADR-011](ADR-011-ai-state-machine-addon-limboai.md) LimboAI.
- Pure GDScript, so ADR-015 does not apply.
- Spike first ([T-012](../tasks/T-012-spike-road-generator.md)) and a
  lane-follow probe second
  ([T-013](../tasks/T-013-roadlane-follower-probe.md)). Keep or drop based
  on the spike results recorded here.

**2. ProtonScatter** (`HungryProton/scatter`, MIT)
- **Pin by commit `main@7198cc00078e` (2026-09-27), not by release tag.**
  The last tag (`4.0`, 2023-10-23) predates the 4.7 compatibility fix,
  which landed on `main` on 2026-07-26 as "fix compatibility issue with
  4.7".
- Places props along curves and areas. Use MultiMesh mode for
  non-colliding clutter. Use instance mode for props that need collision.
- [T-014](../tasks/T-014-vendor-scatter.md).

Both addons are editor-time tools. Generated geometry is saved into track
scenes, so runtime cost is ordinary meshes and collision.

---

### Consequences

**Positive:**
- New tracks become a spline-editing task instead of placing boxes.
- AI lanes come with the road, so traffic and bots share one path source.
- Prop dressing is fast, with consistent MultiMesh performance.

**Negative / Tradeoffs:**
- Road Generator is 0.x and its API may change between releases. Pin and
  bump deliberately.
- Upstream history shows `RoadLaneAgent` performance problems (#273,
  closed) and editor redraw cost (#361, open). The spike must measure FPS
  with a full track loaded.
- Scatter is pinned to an untagged commit. Re-check upstream when bumping
  Godot.
- Road Generator focuses on roads. Ramps, loops and stunt geometry still
  need CSG or modelled meshes.

---

### Alternatives Considered

1. **Built-in `Path3D` + `CSGPolygon3D` roads:** Viable for a single
   circuit, but there are no intersections, no lane data and CSG is costly
   at runtime unless baked. Remains the fallback if the Road Generator
   spike fails.
2. **Model all tracks in Blender:** Best for bespoke hero tracks, but it
   provides no lane or AI path data and iteration is slow. Can complement
   Road Generator for set-pieces.
3. **Terrain3D** (`TokisanGames/Terrain3D`): Not needed. The city and
   circuit tracks are mostly roads. Reconsider for outdoor terrain tracks.
