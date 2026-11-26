# T-032: Visual Body — Roll, Ground Alignment, Drift Hop, Tier Cues

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Done
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §5,
§6

### Goal

The car's visuals sell the handling while the physics body stays
upright.

### Acceptance Criteria

- [x] A `VisualBody` node holds the mesh.
- [x] It rolls into turns, capped at about 10 degrees, with a time
      constant of about 0.2 s.
- [x] It aligns to the floor normal with a time constant of about 0.1 s,
      and eases toward the velocity pitch in the air.
- [x] A visual-only hop of about 0.35 s plays on drift entry.
- [x] Each drift tier shows a clear cue: sparks and body tint in a
      different colour per tier, readable in a small viewport.
- [x] Collision and physics are unchanged. Tests and a screenshot cover
      this. `task ci` is green.

### Verification

**Model.**
- `scripts/vehicles/vehicle_visual_body.gd` (`VehicleVisualBody`) is the
  `VisualBody` node in `tophat_car.tscn`. The `MeshInstance3D` moved
  under it, and the `CollisionShape3D` stays on the physics body,
  unchanged.
- It reads only the car's public state. It updates in `_physics_process`,
  after the car, so physics interpolation (T-020) smooths it.
- **Roll:** into the turn, `steer x speed share x 10 degrees`, with
  tau 0.2 s.
- **Tilt:** to the floor normal from the T-030 ground ray, tau 0.1 s. In
  the air it eases toward the velocity pitch, capped at 25 degrees,
  tau 0.25 s.
- **Drift hop:** visual only, a 0.3 m parabola over 0.35 s.
- **Tier cues:**
  - an emission tint on a per-car copy of the material: cyan, then
    amber, then magenta, at energy 0.3, or 0.6 while boosting
  - two GPU particle spark emitters at the rear wheels, in the tier
    colour
- **Tint strength:** the first try used energy 0.6, which turned the red
  body light blue and orange and lost the car's identity. At 0.3 the red
  stays and the sparks carry the tier.

**Probe:**
- On the Kenney ramp (15 degrees), the visual body tilts 14.6 degrees.
- In a held drift: roll at the 10-degree cap, a 0.30 m hop, tint
  `4fd6ff` at tier 1 and `ffb02e` at tier 2, and sparks emitting.
- Screenshots (windowed, not committed):
  - `t032-tier1.png`: cyan sparks and a cyan glow on the red body,
    rolled into the turn
  - `t032-tier2.png`: amber

**Tests** (6 new):
- roll cap and sign
- hop parabola
- tilt to a 15-degree normal
- the mesh moved under `VisualBody`, with collision unchanged
- a per-car material
- a drift shows the tier-1 colour, sparks and a 0.3 m hop

`task ci`: `Overall Summary: 102 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`.

### Dependencies

- T-028, T-030, T-031

### Assumptions (owner to validate)

- **Assumption:** Rolling *into* the turn (up to 10 degrees) reads better
  than rolling outward.
  **Evidence:** §5's recipe uses `-steer x speed / divisor`, which is
  into the turn, and §6 caps roll at about 10 degrees.
  **Owner check:** Corner hard. If the lean looks wrong, ask for it the
  other way (one sign).
- **Assumption:** Cyan, amber and magenta sparks, with a soft glow, make
  the three tiers readable.
  **Evidence:** §6 says tiers should read by sparks and body colour. These
  hues are far apart from each other and from the red body.
  **Owner check:** Drift to tier 3 while watching the sparks. Each tier
  change should be obvious. Say if you want a stronger glow
  (`TIER_TINT_ENERGY`).
- **Assumption:** The hop and the tilt make the car feel alive, not
  floaty.
  **Evidence:** §2 (0.3-0.4 s visual hop) and §5 (tau 0.1 s alignment).
  **Owner check:** Start drifts and drive up the ramps. If the hop feels
  silly, ask for a lower `HOP_HEIGHT`.
