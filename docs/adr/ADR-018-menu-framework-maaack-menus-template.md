# ADR-018: Menu Framework — Maaack's Menus Template

**Status:** Accepted (adoption deferred to the first real menu work)

**Date:** 2026-11-24

---

### Context

Every shipped game needs a main menu, options (audio, video, input), a
pause menu, credits and a loading screen. None of these is part of this
game's identity. STATE.md keeps menus out of scope until one car on one
track is fun. When menus start, the risk is spending days on
undifferentiated UI plumbing.

The game-specific UI stays ours per
[ADR-012](ADR-012-self-implementation-boundary.md):

- Player join and slot assignment (`PlayerManager`).
- Hat customization.
- Tournament lobby and bracket screens.
- The Event Director console.

---

### Decision

Adopt **Maaack's Menus Template** (`Maaack/Godot-Menus-Template`, MIT) for
generic menus.

- Pin **v1.8.0** (released 2026-11-22, targets Godot 4.7 and supports
  4.4+). Verified via `gh api` on 2026-11-24.
- Use the **Menus Template**, not the larger **Game Template**
  (`Maaack/Godot-Game-Template`, same author and version). The Game
  Template adds an example game loop, level manager and win/lose flow that
  would compete with our own `RaceManager` and `TournamentManager`.
- Its installer copies editable example scenes into the project. Copy them
  under `scenes/ui/menus/` and `scripts/ui/menus/` to match
  `asset-organization.md`. Leave the addon core under `addons/`.
- Its input-remapping screen rebinds the global `InputMap`. After any
  remap, call `DeviceActionMap.rebuild()`
  ([ADR-014](ADR-014-per-device-input-action-map.md)) so per-device copies
  pick up the change. Per-player remapping, if it is ever wanted, is our
  own work.
- Its credits scene should read from the asset credits manifest defined in
  [ADR-019](ADR-019-third-party-asset-sourcing-and-licensing.md).
- Architecture rule: template menus are **UI layer only**. They may emit
  signals or call `GameConfig` settings. They must never own race or
  tournament state (AGENTS.md "UI cannot own gameplay state").

Spike ticket: [T-015](../tasks/T-015-spike-maaack-menus-template.md).

---

### Consequences

**Positive:**
- Options (with persisted settings), pause, credits and a scene loader
  arrive working and are actively maintained (released 2026-11-22).
- The copied scenes are ours to edit, so we are not locked in visually.

**Negative / Tradeoffs:**
- Copied example scenes diverge from upstream. Later template updates do
  not flow into them automatically.
- The template may add its own autoloads (for example for app config or
  the scene loader). The spike must list them and check each against the
  AGENTS.md Autoload Policy. Accept them as vendor infrastructure, as
  [ADR-013](ADR-013-camera-addon-phantom-camera.md) does, only if they
  hold no gameplay state.

---

### Alternatives Considered

1. **Hand-roll menus:** Rejected. Undifferentiated work that delays
   playtesting with friends.
2. **Maaack's Game Template:** Rejected for now. It overlaps our planned
   race and tournament flow (see Decision).
