# T-017: Kart-Racer Handling Genre Research

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Todo
**Estimate:** 3h (research and writing; no code)
**Phase:** Handling rework, step 0 (see [STATE.md](../../STATE.md))

### Goal

Write a reference document of **genre conventions** for arcade kart
handling, with concrete target numbers. The handling rework can then be
planned and judged against targets instead of the current values. The
owner's 2026-11-24 feel-test found the current values unusable as a
baseline.

### Acceptance Criteria

- [ ] `docs/design/handling-reference.md` covers each area the feel-test
      flagged, describing how the genre generally solves it:
  - **Steering:** response curve vs. speed, turn-in delay, counter-steer,
    analog vs. digital input
  - **Drift:** entry (hop or button), direction lock, slide angle, how
    steering changes the line during a drift, charge tiers and timing,
    boost strength and duration, cancel rules
  - **Ramps / air / landing:** air control, trick input, landing boost,
    landing alignment, slope alignment on the ground
  - **Camera:** follow distance and height, lag, FOV change with speed or
    boost, behavior during drift, airborne framing
- [ ] Each area gives a **target range** with units (for example "drift
      boost: 0.5–1.5 s at +15–30% top speed") and the source of the
      number.
- [ ] A short "implementation techniques" section on how arcade karts are
      commonly built in engines:
  - `CharacterBody3D` vs. sphere-collider rigs
  - visual body tilt separated from the physics body
  - aligning the car to the ground normal
- [ ] An "Our deviations" section. It ties choices to the game pillars:
  - hat-car identity (tall hats, tassel physics)
  - couch readability in splitscreen
  - Guardrail 3 ("1-Car Fun")
- [ ] Sources are listed. Prefer developer talks, postmortems, frame-data
      or speedrun community measurements, and open-source implementations.

### Context

- This documents **genre conventions** to build an original game. It must
  not recreate any specific game's handling, names or presentation.
- STATE.md already holds partial notes: the mini-turbo charge tiers, jump
  boosts and air control. Fold them in and correct them where research
  disagrees.
- Not covered by ADR-012 addons: handling stays self-implemented. This doc
  feeds the rework tickets, which will be written after it.

### Files Likely Affected

- `docs/design/handling-reference.md` (new)

### Implementation Plan

1. Search developer talks, postmortems and community frame-data for each
   area. Prefer measured numbers over opinion.
2. Read 2–3 open-source arcade kart implementations, Godot ones first,
   for technique only. Note their license before citing any snippet.
3. Draft the doc, one section per area: convention, target range, source,
   and notes for our implementation.
4. Add the "Our deviations" section.
5. End with a proposed list of rework tickets, sized per
   [task-sizing.md](../standards/task-sizing.md). Write only the titles
   and scope; the tickets themselves get written after the owner reviews
   the doc.

### Verification

The owner reads `handling-reference.md` and confirms the targets match the
intended feel, or adjusts them. This is a decision checkpoint, not a code
check.

### Dependencies

None. Can run in parallel with Phase 1 tooling.
