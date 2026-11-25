# T-017: Kart-Racer Handling Genre Research

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 3h (research and writing; no code)
**Phase:** Handling rework, step 0 (see [STATE.md](../../STATE.md))

### Goal

Write a reference document of **genre conventions** for arcade kart
handling, with concrete target numbers. The handling rework can then be
planned and judged against targets instead of the current values. The
owner's 2026-11-24 feel-test found the current values unusable as a
baseline.

### Acceptance Criteria

- [x] `docs/design/handling-reference.md` covers each area the feel-test
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
- [x] Each area gives a **target range** with units (for example "drift
      boost: 0.5–1.5 s at +15–30% top speed") and the source of the
      number.
- [x] A short "implementation techniques" section on how arcade karts are
      commonly built in engines:
  - `CharacterBody3D` vs. sphere-collider rigs
  - visual body tilt separated from the physics body
  - aligning the car to the ground normal
- [x] An "Our deviations" section. It ties choices to the game pillars:
  - hat-car identity (tall hats, tassel physics)
  - couch readability in splitscreen
  - Guardrail 3 ("1-Car Fun")
- [x] Sources are listed. Prefer developer talks, postmortems, frame-data
      or speedrun community measurements, and open-source implementations.
      *Met mostly by open-source code and fan frame-data. The one GDC talk
      found could not be read, so no talk numbers are used.*

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
check. *Pending owner: see Assumptions below.*

### Dependencies

None. Can run in parallel with Phase 1 tooling.

### Assumptions (owner to validate)

- **Assumption:** The targets in `handling-reference.md` match the intended
  feel. Steering, drift, air and camera numbers come from genre data,
  scaled to our 24 m/s top speed.
  **Evidence:** SuperTuxKart config and source, Mario Kart Wii community
  frame data and the sources listed in the doc's section 8.
  **Owner check:** Read the doc, then do the FC-1 drive and adjust any
  target that feels wrong.
- **Assumption:** Two drift tiers (about 0.9 s and 1.9 s) are enough, not
  three.
  **Evidence:** Wii-era frame data and SuperTuxKart both use two tiers.
  Splitscreen readability favours fewer tiers.
  **Owner check:** Say if you want a third tier in the rework.
- **Assumption:** The starting camera values (4.5 to 6 m back, 2.2 to
  2.5 m up, FOV 75 plus 8 on boost) are good enough for T-005 to start.
  Most are our estimates, anchored on SuperTuxKart's camera code.
  **Evidence:** Doc section 4. No primary source gives speed-linked FOV.
  **Owner check:** Judge the camera in the first T-005 drive.
- **Assumption:** Fan-wiki numbers (Mario Kart Wii, fan frame counts) are
  accurate enough as secondary evidence.
  **Evidence:** They are cross-checked against SuperTuxKart where possible.
  **Owner check:** None needed unless a target feels off.
