# Track Geometry Rules

Rules for any track geometry the car can reach. They come from camera and
collision failures found while testing the test track. Check new track
pieces against them.

## 1. No low gaps under geometry

A car must never fit into a space with a ceiling lower than **2.5 m**
above the floor. Either close the underside to the floor (a solid wedge
or block), or leave at least 2.5 m of clearance.

**Why:**
- The chase camera's collision cast starts at its pivot, which is 1.5 m
  above the floor: the car origin is 0.5 m and `follow_offset.y` adds
  1.0 m. The cast is a 0.25 m sphere with a 0.2 m margin, so the pivot
  needs about 1.95 m of clearance.
- If the pivot is inside geometry, the cast does not see that geometry.
  The camera then jumps to the far side of it. T-021 found this under the
  old Ramp2 slab: the camera jumped 4.7 m in one frame and ended up on the
  ramp's top side.
- Lowering the pivot near a ceiling does not help. It is damped (0.2 s
  on Y), so at speed it lags by about 2 m.
- A low gap also traps the car. It wedges and stops dead.

The extra 0.55 m above 1.95 m covers bumps and ramp landings.

## 2. Ramps and jumps are solid

Build ramps as wedges that are closed to the floor, like Kenney's
`roadRampLong` (convex collision) or `Ramp2` (a `CSGPolygon3D` wedge).
Do not build them as a tilted slab with an open underside. The high end
of a jump is then a vertical face, which the car and the camera treat as
a wall.

## 3. What you see is what you hit

Every collision volume a car can touch must be visible. Kenney's
`roadRampLong` model is only a one-sided road deck: from the side or
the high end it is almost invisible, and the space under it looks open.
Its collider is a solid wedge (rule 2), so the "open" space was an
invisible wall (FC-1, T-023). The wrapper scene now adds a visible
`Body` (a `PrismMesh` wedge) just under the deck. Check every new
imported prop from the side, from behind and from below.

## 4. Bounds are taller than any jump

The outer walls must be taller than the highest point a car can reach
off any ramp, plus 2 m. On the test track the highest car origin
measured is 8.64 m off Ramp2. With half the car (0.5 m) and the margin,
the walls are now 12 m (T-024). At 3 m, a right turn off Ramp2 cleared
the west wall in 13 of 40 scripted runs.

When the handling rework makes ramps launch upward, re-measure the apex
and raise the walls, or add a see-through fence above them. As a safety
net, `OutOfBoundsReset` puts a car that falls below y = -20 back at its
spawn pose.

## 5. Collision shapes

Use box or convex collision on layer 1 with mask 0, at uniform scale.
Do not use trimesh collision for props (T-011, tested in
`test/integration/test_track_props.gd`).
