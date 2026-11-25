# ADR-021: 3D Physics Engine — Jolt Physics

**Status:** Accepted

**Date:** 2026-11-24

---

### Context

`project.godot` never set `physics/3d/physics_engine`, so it resolved to
`DEFAULT`. On Godot 4.7.2 `DEFAULT` ran **Godot Physics**, not Jolt. We
checked this by running a headless probe with no override. The Jolt server
class (`JoltPhysicsServer3D`) was not registered, and every number matched
an explicit `GodotPhysics3D` run.

That is a risk. `DEFAULT` is whatever the engine team decides it means.
A Godot upgrade could switch the server under us and silently change how
`move_and_slide()` behaves, right when we are about to tune handling.
Switching engines later invalidates that tuning, so the engine is pinned
now, before the handling rework.

`VehicleController` is a `CharacterBody3D`. The surfaces that matter are
wall contact, `is_on_floor()` stability on ramp seams, ramp launch and
landing, and standing still on an incline.

---

### Method

The ticket ([T-001](../tasks/T-001-pin-3d-physics-engine.md)) asked for two
hand-driven passes. The builder is an agent and cannot drive the car, so a
**scripted headless probe** replaced them. The owner's hand-drive is
deferred to feel checkpoint FC-1 (see Consequences).

The probe is evidence tooling and is not committed. It instances
`test_track.tscn` and `tophat_car.tscn`, replaces the car's `InputSource`
with a scripted one, and steps fixed 60 Hz physics frames. It runs with
`godot --headless --fixed-fps 60`, so it is deterministic.

The engine is switched with an `override.cfg` in the project root
(`[physics] 3d/physics_engine=...`). `project.godot` is not touched during
the comparison. Each run prints the setting it read, and whether
`JoltPhysicsServer3D` is registered. That check is what proves the switch
took effect: `true` only under Jolt.

Scenarios:

- **Wall slide**, both sides, 20 and 5 degree approach at full speed.
- **Wall slide, relaxed:** same, with `wall_min_slide_angle = 0` and
  `floor_block_on_wall = false` on the body. This isolates engine contact
  from the body's own wall-stop rules.
- **Ramp launch and landing** at full speed over both ramps.
- **Ramp crawl** at 4 and 12 m/s over the ramp seams.
- **Incline stop:** brake to an exact stop on the ramp, then idle for 5 s.
- **Drift:** a circle with drift held, and a drift run into the inner walls.

The current handling tuning is not a baseline. This ADR judges contact
quality, not how the car feels.

---

### Results

Probe numbers, 4.7.2, one car, headless:

| Metric | Godot Physics | Jolt |
|---|---|---|
| Wall slide 20 and 5 deg, both sides (displacement speed) | 0.09 / 0.00 m/s | 0.09 / 0.00 m/s |
| Wall slide, relaxed, 20 deg / 5 deg | 8.21 / 2.09 m/s | 8.21 / 2.09 m/s |
| Wall lateral jitter (x range at wall) | 0.00000 | 0.00000 |
| `is_on_floor()` flicker, all ground and wall runs | 0 | 0 |
| Ramp launch, floor/air run lengths (frames) | F75 A37 F35 A77 | F76 A37 F38 A77 |
| Ramp peak height | 8.617 m | 8.592 m |
| Short air runs (under 6 frames) at seams | 0 | 0 |
| Ramp crawl 4 and 12 m/s: floor transitions | 0 | 0 |
| Incline stop, creep over 5 s | 0.0000 m | 0.0000 m |
| NaN in any run | none | none |
| Rest height on flat ground | 0.5002 | 0.5005 |
| Step cost, wall runs (µs per tick, whole loop) | 120 to 133 | 164 to 176 |
| Step cost, ramp / drift circle | 82 / 116 | 166 / 180 |

Reading the table:

- **Contact quality is the same.** No flicker, no jitter, no seam
  snagging, no creep and no NaN under either engine. The ramp landing
  differs by three frames on the ground run and 0.025 m of peak height.
- **Wall slides are not an engine question.** The car stops dead against
  a wall under both engines. The controller rebuilds its velocity from the
  facing direction every frame, and `CharacterBody3D` blocks sliding below
  `wall_min_slide_angle` (15 degrees). That is a handling finding, not a
  physics-engine finding. With the stop rules relaxed, both engines still
  give identical speeds. The handling rework should deal with it.
- **Jolt costs more per tick.** About 1.3x to 2x here. The absolute cost is
  under 0.25 ms per tick for one car, against a 16.7 ms budget. The 4-car
  split-screen target is not at risk at this scale. Re-measure when real
  tracks and pileups exist.

Test results, `task test` (8 cases, 3 suites): **0 failures under Godot
Physics, 0 failures under Jolt.** No test passes on only one engine.

Non-uniform scale check: no collision shape in `test_track.tscn` or
`tophat_car.tscn` sits on a scaled node. The ramps are rotated, not
scaled. Nothing needed fixing.

---

### Decision

Pin **Jolt Physics**: `physics/3d/physics_engine="Jolt Physics"` in
`project.godot`.

The probe found no difference in contact quality. Per the ticket's tie
rule, ties go to Jolt, because it is the engine Godot is moving toward and
is generally steadier at contacts. That matters most for 4-car pileups
later.

---

### Consequences

**Positive:**
- The engine no longer depends on what `DEFAULT` means in a given Godot
  version.
- Jolt is the better base for pileups and `RigidBody3D` props later.
- No change to existing tests or scenes.

**Negative / Tradeoffs:**
- Jolt costs more CPU per tick than Godot Physics in this probe.
- Jolt handles non-uniformly scaled collision shapes differently. When
  adding track pieces or scatter props, do not scale collision nodes.
  Resize the shape instead.
- The comparison was scripted, not hand-driven. Contact feel at the
  fine level is unconfirmed.

**Owner confirmation:** the owner hand-drive happens at FC-1, with the new
camera and F3 vectors on. Check wall slides and ramp landing. If Jolt
feels wrong, flipping back is a one-line change in `project.godot`:
`3d/physics_engine="GodotPhysics3D"`. Handling tuning done after FC-1
should use the confirmed engine.

---

### Alternatives Considered

1. **Godot Physics (what `DEFAULT` resolved to):** Equal contact quality
   in the probe and cheaper per tick. Rejected on the tie rule, and
   because it is the legacy engine. Remains the fallback.
2. **Leave `DEFAULT`:** Rejected. It lets an engine upgrade change physics
   silently.
3. **Hand-driven comparison before pinning:** Not possible for the
   builder. Deferred to FC-1, where it is cheap to reverse.
