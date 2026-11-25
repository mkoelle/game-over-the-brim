# ADR-016: Debug Visualization Addon — Debug Draw 3D

**Status:** Accepted (adopt now, Phase A; dev-only)

**Date:** 2026-11-24

---

### Context

The Iteration 01 gate is a hand feel-test. The current F3 `DebugOverlay`
shows numbers (speed, input, FPS), but drift and handling problems are
spatial:

- Is velocity lagging facing by the expected slip angle?
- Is the floor normal what we think it is on the ramp?
- Did `is_on_floor()` drop for one frame on a seam?

Seeing these as in-world vectors makes tuning `VehicleStats` much faster.
Drawing lines, arrows and text in 3D is generic tooling with no game
identity value.

---

### Decision

Adopt **Debug Draw 3D** (`DmitriySalnikov/godot_debug_draw_3d`, MIT) as a
**dev-only** in-world debug drawing tool.

- Pin **v1.7.3** (released 2026-04-04; verified via `gh api` on
  2026-11-24). The README lists Windows, Linux, macOS, Android 5.0+, iOS
  and Web.
- It is a native GDExtension, so it must pass the
  [ADR-015](ADR-015-native-gdextension-addon-policy.md) checklist
  ([T-006](../tasks/T-006-vendor-debug-draw-3d.md)).
- Usage lives only in a separate component,
  `scripts/vehicles/vehicle_debug_draw.gd`, added as a child of the car
  scene and gated on `GameConfig.debug_mode` (F3)
  ([T-007](../tasks/T-007-vehicle-debug-vectors.md)).
  `VehicleController` never references `DebugDraw3D`.
- Release behavior: T-006 confirms whether the release-template build of
  the extension is inert. If it is not inert, exclude the addon and the
  component from release exports with an export filter (ADR-015 check 6).

Known 4.7 issue: upstream #112 (`DebugDraw2D.set_text` is broken in the
4.7 *editor* for `@tool` scripts). It does not affect runtime 3D drawing,
which is all we use.

---

### Consequences

**Positive:**
- Velocity vs. facing, slip angle, floor normal and grounded state become
  visible while driving. This directly supports Guardrail 1 hand testing.
- The same tool serves checkpoint, AI lane and hazard-telegraph debugging
  later.

**Negative / Tradeoffs:**
- Native binaries in the repo (see ADR-015 check 5).
- A known editor-only text bug on 4.7 (see above).

---

### Alternatives Considered

1. **Hand-rolled `ImmediateMesh` line drawer:** Viable fallback and pure
   GDScript. Rejected as the default because Debug Draw 3D already handles
   batching, per-frame lifetimes, text and shapes. Fall back to this if
   ADR-015 checks fail.
2. **Numbers only in `DebugOverlay`:** Rejected. Spatial problems are hard
   to read as numbers.
