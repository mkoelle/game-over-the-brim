# ADR-011: AI / State Machine Addon — LimboAI

**Status:** Accepted (adoption deferred to first manager state machine or AI bot)

**Date:** 2026-09-14

---

### Context

[overview.md §1](file:///docs/architecture/overview.md) defines
`RaceManager` (countdown/racing/paused/finished/sudden-death) and
`TournamentManager` (heats/brackets) as explicit state machines, and
STATE.md's next milestone will eventually need AI bot drivers and ambient
traffic (per
[race-modes.md](file:///docs/design/race-modes.md)). Both are the
"generic infrastructure" half of the problem — state transition bookkeeping
and behavior-tree evaluation are solved problems; the *content* of each
state (what `RaceManager` actually does in "racing," what a bot decides at
a fork) is game-specific and stays self-implemented regardless.

---

### Decision

Adopt **LimboAI** (behavior trees + state machines for Godot 4) as the
backing framework for:
1. `RaceManager` / `TournamentManager` phase state machines, when either is
   first implemented.
2. AI bot driver decision-making and ambient traffic behavior, when that
   work starts.

Both are explicitly out of scope for the current Phase A milestone per
STATE.md ("no `RaceManager` state machine... Add these only once one car on
one track is confirmed fun"). Do not vendor before then.

---

### Consequences

**Positive:**
- Transition/tree bookkeeping (state history, guard conditions, tree
  ticking) arrives tested and editor-integrated instead of hand-rolled.
- Godot-editor visual debugging of trees/states helps tune AI bot behavior
  without custom tooling.

**Negative / Tradeoffs:**
- Couples two of the most central systems (`RaceManager`,
  `TournamentManager`) to a third-party framework's control flow — a poor
  fit discovered late would be expensive to unwind. Prototype the
  `RaceManager` state machine with it early in that milestone to validate
  fit before `TournamentManager` and AI bots also depend on it.

---

### Alternatives Considered

1. **Hand-roll a simple enum + match state machine**: Viable fallback if
   LimboAI's behavior-tree model proves awkward for `RaceManager`'s
   comparatively simple linear phases — reconsider per-manager rather than
   forcing LimboAI everywhere it isn't a clean fit.
2. **Hand-roll AI bot decision logic**: Rejected as the default — behavior
   trees are the standard tool for exactly this problem, and LimboAI's
   editor integration outweighs a bespoke bot decision system.
3. **Beehave** (`bitbrain/beehave`, MIT, v2.9.3, pure GDScript): the
   fallback for bot behavior trees if LimboAI fails the
   [ADR-015](ADR-015-native-gdextension-addon-policy.md) native-addon
   checks (for example, a missing Android binary). It has no state-machine
   half. `RaceManager` would then use alternative 1 (enum + match).

---

### Amendment — 2026-11-24

- **LimboAI is native code.** It ships either as a C++ engine module
  (custom engine build) or as a GDExtension. Use the **GDExtension**
  build. A custom engine build would break the stock-Godot CI and export
  pipeline (ADR-007). The GDExtension build is "somewhat limited in
  features" per upstream, so check that the features we need exist before
  committing.
- Adoption is gated by
  [ADR-015](ADR-015-native-gdextension-addon-policy.md): four-platform
  binaries, `task ci` on 4.7.2, and an export smoke test.
- Version compatibility (upstream table, verified 2026-11-24): LimboAI
  **1.8.x** GDExtension supports Godot **4.6+**, and the latest is
  **v1.8.1** (2026-08-20). Re-verify at adoption.
- Bot path source: AI bots and traffic follow Road Generator `RoadLane`
  paths ([ADR-017](ADR-017-track-tooling-road-generator-and-scatter.md)).
  LimboAI decides *what* to do (overtake, block, take a shortcut).
  `RoadLane` supplies *where* to drive.
