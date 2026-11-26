# T-022: F3 Debug Text Shakes and Pops in Turns

**Assignee:** Claude (Opus, ADR-022 FC-1 feedback)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Done
**Estimate:** 1h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md)), FC-1 feedback
**ADR:** [ADR-016](../adr/ADR-016-debug-visualization-addon-debug-draw-3d.md)

### Goal

Keep the F3 slip and grounded label steady on the car. This was FC-1
owner feedback ([checklist](../plans/fc-1-owner-checklist.md) §5): "Turns
cause the debug text to vibrate and turn fuzzy. Sometimes the text jumps
or pops, large and off center".

### Acceptance Criteria

- [x] The cause is reproduced and measured.
- [x] The label stays on its anchor above the car in straight driving and
      in turns, at 120 Hz.
- [x] Debug Draw 3D stays unmodified (ADR-015). The fix lives in
      `VehicleDebugDraw`, which is debug-only.
- [x] `task ci` is green, with tests for the opt-out.

### Context

- **Cause: a side effect of T-020.** `DebugDraw3D.draw_text` uses pooled
  `Label3D` nodes under the addon's root node
  `@_DD3D_WorldWatcher@N/@Node@M/`. It moves them every rendered frame and
  uses a different pooled label each frame: the probe saw 300 switches in
  300 frames. With `physics/common/physics_interpolation` on, those labels
  inherit interpolation (`is_physics_interpolated()` was `true`). Each one
  blends from where it was last drawn, so in a turn the text shook and
  sometimes popped far across the screen.
- **Not affected:** Debug Draw 3D draws its arrows straight into
  `RenderingServer` instances, not into nodes, so they were already steady.
- **Fix:** `VehicleDebugDraw` sets `physics_interpolation_mode = OFF` on
  every node whose name contains `_DD3D_`. It does this once in `_ready()`
  for the nodes that already exist, and on `SceneTree.node_added` for
  later ones (for example a second world in split screen). The pooled
  labels inherit the setting. Only debug builds attach this component
  (T-007).
- **Fragility:** the fix depends on the addon's internal node name. A
  Debug Draw 3D update must re-run the probe below.

### Files Likely Affected

- `scripts/vehicles/vehicle_debug_draw.gd`
- `test/unit/test_vehicle_debug_draw.gd`

### Verification

A windowed probe at 120 Hz turns F3 on and drives `main.tscn` at full
throttle. Each frame, at `frame_pre_draw`, it compares the visible
label's screen position with its anchor (car + 2.4 m).

| Run | Label offset RMS | Max offset | Label switches |
|---|---|---|---|
| Before, straight | 0.57 px | 2.6 px | 300 / 300 frames |
| Before, steer 0.6 | **300.49 px** | **4,247.7 px** | 300 / 300 |
| After, straight | 0.0 px | 0.0 px | 300 / 300 |
| After, steer 0.6 | 0.0 px | 0.0 px | 300 / 300 |
| After, steer -1.0 | 0.0 px | 0.0 px | 300 / 300 |

After the fix, every Debug Draw 3D `Label3D` reports
`is_physics_interpolated() == false`.

The unit tests use a stand-in node, because headless runs create no
Debug Draw 3D world node. They check that a node named like the addon's
is matched, and that labels under it are not interpolated, both when the
node exists at `_ready()` and when it is added later. An unrelated
`Node3D` stays interpolated.

### Dependencies

- T-020 (interpolation on) and T-007 (the component).

### Assumptions (owner to validate)

- **Assumption:** The shaking and popping the owner saw is this
  interpolation blend, and the "fuzzy" look was the same shake.
  **Evidence:** The probe above. The offset in turns went from 300 px RMS
  to 0.
  **Owner check:** Pull `main`, `task run`, press F3 and turn hard both
  ways. The label should stay sharp, centered over the car.
