# T-023: Visible Solid Body for the Kenney Ramp (Invisible Wall)

**Assignee:** Claude (Opus, ADR-022 FC-1 feedback)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Done
**Estimate:** 1h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md)), FC-1 feedback
**ADR:** [ADR-019](../adr/ADR-019-third-party-asset-sourcing-and-licensing.md)

### Goal

Remove the invisible wall under the Kenney ramp (`Ramp` in
`test_track.tscn`). This was FC-1 owner feedback
([checklist](../plans/fc-1-owner-checklist.md) §5): "driving under ramp
one hits invisible wall".

### Acceptance Criteria

- [x] The cause is reproduced, with screenshots.
- [x] The ramp's collision volume is visible from the side, from the high
      end and from below.
- [x] The deck looks the same from the driving side, with its road, curbs
      and green edges, and has no z-fighting.
- [x] Collision and driving are unchanged.
- [x] The rule is written down in
      [track-geometry.md](../design/track-geometry.md) (rule 3).
- [x] `task ci` is green, with a test.

### Context

- **Cause.** `roadRampLong.gltf` is only a road deck. It is single-sided
  (`doubleSided` unset) and has no sides, back or underside. From the side
  or the high end it renders as two thin lines plus a shadow, so the space
  under the high end looks open. T-011 gave it a solid convex wedge
  collider (`road_ramp_long.tscn`, 4.16 m high at +Z), which is right per
  track-geometry rule 2. So the car hit a wall it could not see.
- **Fix.** The first-party wrapper scene `road_ramp_long.tscn` gets a
  `Body` `MeshInstance3D`: a `PrismMesh` with `left_to_right = 1`, so a
  right-angle wedge, sized 16 x 4.0 x 8 m. It is rotated so it rises
  toward +Z, with its vertical face at the high end. It is grey
  (0.55, 0.56, 0.6) and has no collision. The vendored glTF is untouched.
- **Height.** The deck's outer edge strips sit at 0.50 x 8 = 4.00 m at
  the high end. The road is 4.08 m and the curbs 4.16 m. A body at the
  full 4.16 m poked through the green edge strips, so the body is 4.0 m
  tall and set 0.03 m lower. Its top stays under every part of the deck.

### Files Likely Affected

- `assets/art/tracks/kenney_racing_kit/road_ramp_long.tscn`
- `test/integration/test_track_props.gd`
- `docs/design/track-geometry.md`

### Verification

- **Screenshots** (windowed, not committed): before, the side and
  high-end views show only thin lines and a shadow where the collider is.
  After, both show a solid grey wedge. The front view keeps the road,
  white curbs and green edges.
- **Driving is unchanged.** The full-throttle probe from z = -45 over the
  Kenney ramp onto Ramp2 gives max y 8.53, takeoff at 24.0 m/s and end
  position (-27.69, 6.79, 30.48), the same as on `main` before this
  change.
- **New test** `test_ramp_has_a_visible_body_covering_its_collision`:
  - The `Body` is a visible right-angle `PrismMesh`.
  - Its footprint matches the collision's footprint within 0.01 m.
  - Its top is under the collision top by less than 0.2 m.
  - The vertical face is at the same +Z as the collision's.
- `task ci` is green (see the PR).

### Dependencies

- T-011 (the Kenney props).

### Assumptions (owner to validate)

- **Assumption:** A plain grey wedge is an acceptable greybox look.
  **Evidence:** It matches the other greybox pieces. Kenney's kit has no
  solid variant of this ramp in what we imported.
  **Owner check:** Drive past the ramp's side and high end. It should
  read as solid. Say if you want another color.
- **Assumption:** The owner hit this ramp's high-end underside, not a
  barrier or pylon.
  **Evidence:** "ramp one" is the first ramp node, `Ramp`, and it is the
  only prop whose model and collider differ this much. The pylon's box
  collider was already recorded in T-011's assumptions.
  **Owner check:** Drive under the high end of each ramp. Both should now
  look solid and stop the car where they look solid.
