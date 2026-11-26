# T-032: Visual Body — Roll, Ground Alignment, Drift Hop, Tier Cues

**Assignee:** Claude (Opus, ADR-022 feel work)
**Date:** 2026-11-25
**Priority:** P2
**Status:** Todo
**Estimate:** 3h
**Phase:** Handling rework ([plan](../plans/handling-rework-plan.md))
**Spec:** [handling-reference.md](../design/handling-reference.md) §5,
§6

### Goal

The car's visuals sell the handling while the physics body stays
upright.

### Acceptance Criteria

- [ ] A `VisualBody` node holds the mesh.
- [ ] It rolls into turns, capped at about 10 degrees, with a time
      constant of about 0.2 s.
- [ ] It aligns to the floor normal with a time constant of about 0.1 s,
      and eases toward the velocity pitch in the air.
- [ ] A visual-only hop of about 0.35 s plays on drift entry.
- [ ] Each drift tier shows a clear cue: sparks and body tint in a
      different colour per tier, readable in a small viewport.
- [ ] Collision and physics are unchanged. Tests and a screenshot cover
      this. `task ci` is green.

### Dependencies

- T-028, T-030, T-031
