# Handling Rework Plan

**Date:** 2026-11-25
**Goal:** Pass the "1-Car Fun" gate (Guardrail 3,
[game-pillars.md](../design/game-pillars.md)). One hat-car on one track
must feel good to drive: steering, drift, walls and jumps.
**Spec:** [handling-reference.md](../design/handling-reference.md)
(T-017). The target numbers and their sources live there. The tickets
below cite its sections.
**Method:** [ADR-022](../adr/ADR-022-dev-workflow-lean-trunk-and-model-tiering.md).
This is gameplay-feel tuning and an ADR-012 self-implemented system, so
Opus builds each ticket directly. Rules:
- One branch and one PR per ticket, merged with auto-merge after
  `task ci`.
- Every ticket brings scripted probe numbers as evidence. A probe cannot
  judge feel, so each owner-only judgement goes into the ticket's
  Assumptions section and into the FC-2 checklist.
- Owner input stays a researched assumption until FC-2 (the owner said
  to continue under researched assumptions, 2026-11-25).

## Model change

The current controller rebuilds velocity every tick as
`forward * current_speed`, where `current_speed` is the projection of
the velocity onto the facing direction. That one line is behind several
FC-1 findings:
- drifts bleed speed
- walls grind the car to a stop
- the slide is invisible
- ramps cannot launch the car

The rework keeps two pieces of state instead:
- a signed scalar **speed**
- a **travel heading**, which turns toward the body heading with a time
  constant

Walls, ramps and landings then change those two values on purpose. T-027
and T-028 introduce the model. Later tickets build on it.

## Tickets (in order)

| Ticket | Title | §7 item | Depends on | Status |
|---|---|---|---|---|
| [T-027](../tasks/T-027-steering-curve-and-smoothing.md) | Steering curve, standstill fade, steer ramp | 1 | — | Done |
| [T-028](../tasks/T-028-grip-and-drift-slide.md) | Speed and heading model, grip and drift slide | 2 | T-027 | Done |
| [T-029](../tasks/T-029-wall-contact-response.md) | Wall contact response (owner request) | 8 | T-028 | Done |
| [T-030](../tasks/T-030-ramp-launch-air-landing.md) | Ramp launch, air control, landing | 4 | T-028 | Todo |
| [T-031](../tasks/T-031-drift-charge-tiers-boost.md) | Drift charge, three tiers, boost | 3 | T-028 | Todo |
| [T-032](../tasks/T-032-visual-body-ground-alignment.md) | Visual body: roll, ground alignment, drift hop, tier cues | 5 | T-028, T-030, T-031 | Todo |
| [T-033](../tasks/T-033-trick-boost.md) | Trick boost off ramps | 6 | T-030, T-031 | Todo |
| [T-034](../tasks/T-034-chase-camera-tuning-pass.md) | Chase camera tuning pass: boost FOV, drift heading, speed FOV | 7 | T-031 | Todo |

Wall response (T-029) comes right after the slide model, ahead of its
§7 position, because the owner named it at FC-1.

## Feel checkpoint FC-2

After T-034, the owner works through the
[FC-2 owner checklist](fc-2-owner-checklist.md). It collects every
ticket's owner checks in one session, plus the items deferred from FC-1.

**The gate:**
- FC-2 passes when the owner judges the "1-Car Fun" rule met.
- If it does not pass, the failures become tickets for a second tuning
  round.
- Phases 3-4 of the [addon adoption plan](addon-adoption-plan.md) stay
  blocked until the gate passes.

## Out of scope

- items
- AI drivers
- other archetypes' stats (only the Stovepipe Speedster is tuned)
- split-screen camera FOV by player count (T-034 records the values;
  split screen does not exist yet)
- network determinism tests (the model stays tick-based and
  deterministic, per §6)
