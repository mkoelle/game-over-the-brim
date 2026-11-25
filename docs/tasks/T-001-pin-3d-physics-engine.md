# T-001: Pin the 3D Physics Engine

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 2h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))

### Goal

Set `physics/3d/physics_engine` explicitly in `project.godot` to either
Jolt Physics or Godot Physics. Today it resolves to `DEFAULT`, so an engine
upgrade could change which physics server runs and silently change how
`move_and_slide()` feels. Do this before more handling tuning, because
switching engines later invalidates that tuning.

### Acceptance Criteria

- [x] `project.godot` contains an explicit `physics/3d/physics_engine` value.
- [x] Both engines were driven on `test_track.tscn` using the
      [manual-testing.md](../standards/manual-testing.md) route, and the
      differences are written down. *A scripted headless probe replaced the
      hand-driven passes (the builder cannot drive the car). The owner's
      hand-drive is at FC-1; see ADR-021.*
- [x] `docs/adr/ADR-021-3d-physics-engine.md` records the choice and why,
      and the reserved line in `DECISIONS.md` is filled in.
- [x] `task ci` is green with the pinned engine.

### Context

- Godot 4.7.2 reports `ProjectSettings.get_setting("physics/3d/physics_engine") == "DEFAULT"`
  (checked 2026-11-24).
- Jolt has been built into Godot since 4.4. It is generally more stable at
  contacts, but it handles non-uniformly scaled collision shapes
  differently. ProtonScatter's 2026-09-27 commit removed "the uniform
  scaling requirement when using Jolt" for this reason.
- `VehicleController` is a `CharacterBody3D`, so the main surfaces to
  compare are `move_and_slide()` wall sliding, `is_on_floor()` stability on
  ramp seams, and step-up behavior.

### Files Likely Affected

- `project.godot`
- `docs/adr/ADR-021-3d-physics-engine.md` (new)
- `docs/adr/DECISIONS.md`

### Implementation Plan

1. Branch `chore/pin-physics-engine`.
2. Open **Project Settings → Physics → 3D → Physics Engine**. Note which
   engine `DEFAULT` currently resolves to; the editor dropdown shows it.
3. Pass A, **Godot Physics:** set the engine explicitly and run F5 with F3
   telemetry. Drive the full manual-testing route:
   - full-speed wall slides on both sides
   - ramp launch and landing
   - drift through every corner
   - stop on the ramp incline

   Note any `is_on_floor()` flicker (the grounded state in the overlay),
   snagging on seams, jitter against walls and FPS.
4. Pass B, **Jolt Physics:** same route, same notes.
5. Check `scenes/arenas/test_track.tscn` for any collision shape on a
   non-uniformly scaled node. Under Jolt, fix it by resizing the shape
   instead of scaling the node.
6. Run `task test` under both engines. Any test that passes on only one
   engine is a finding to record.
7. Pick the engine with better feel. Ties go to Jolt, for contact
   stability at 4-car pileups later. Leave the chosen value set in the
   editor; edit `project.godot` through the editor, not by hand.
8. Write ADR-021 (Context, both passes' notes, Decision, Consequences) and
   update `DECISIONS.md`.

### Verification

`task ci` is green, and `grep physics_engine project.godot` shows the
explicit value.

### Dependencies

None. Do this first in Phase 1.
