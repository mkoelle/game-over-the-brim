# ADR-014: Per-Device Input Action Map (Self-Implemented)

**Status:** Accepted (adopt now, Phase A)

**Date:** 2026-11-24

---

### Context

Architecture Decision 01 ([overview.md](../architecture/overview.md)) and
[ADR-004](ADR-004-network-peer-and-car-decoupling.md) require each vehicle
to read input from one device only. Godot 4.7's `InputMap` actions are
global: `Input.is_action_pressed("throttle")` fires for *any* device bound
to that action. 4.7 has no device parameter on `Input.is_action_*` /
`get_action_strength` / `get_axis`. This was verified on 4.7.2 with
`ClassDB.class_get_method_list("Input")` on 2026-11-24.

`scripts/vehicles/input_source.gd` works around this in two ways:

- **Keyboard slot:** reads the global action map.
- **Joypad slot:** bypasses the action map and polls hardcoded
  `JOY_AXIS_*` / `JOY_BUTTON_*` constants.

This has three defects:

1. **Two sources of truth for bindings.** Joypad bindings exist in
   `project.godot` *and* as constants. Changing one silently diverges from
   the other.
2. **No joypad remapping possible.** Any future options or remap menu edits
   the `InputMap`, which the joypad path never reads.
3. **The keyboard slot leaks joypad 0.** The `project.godot` joypad events
   are bound to `"device": 0`. The keyboard slot reads the global action
   map, so joypad 0 also drives the keyboard player's car. With one car
   this is invisible. In splitscreen (keyboard P1 + joypad P2), joypad 0
   drives both cars.

**Godot 4.7 device-ID change.** Joypads now use IDs 0–15,
`InputEvent.DEVICE_ID_KEYBOARD` is `16` and `DEVICE_ID_MOUSE` is `32`.
`InputEvent.DEVICE_ID_EMULATION` is `-1`. All values were verified on
4.7.2. Our `InputSource.KEYBOARD_DEVICE = -1` sentinel is internal and
still works, but it now collides in meaning with the engine's emulation ID.

**The addon we evaluated.** `matjlars/godot-multiplayer-input` (MIT) solves
exactly this problem. On connect, it duplicates every action per device and
re-targets each copied joypad event's `device`. We rejected vendoring it on
4.7 for these reasons:

- Upstream has been inactive since 2025-07 (`main@23dd44b63bd5`).
- The Godot 4.7 device-ID fix is an unmerged PR (#25, opened 2026-10-28).
- It disables joypad events on the core actions by moving them to
  `device = 8`, which is a *valid* joypad ID on 4.7.
- Open crash and assertion issues on joypad disconnect (#8, #20, #21, #23).
- It registers an extra autoload, against the AGENTS.md Autoload Policy.
- It is untyped GDScript, so it cannot be held to our static-typing rule.

---

### Decision

Self-implement the per-device action map with the same proven technique,
as a small typed class we own. Credit MultiplayerInput's MIT design in the
file header.

- New `scripts/input/device_action_map.gd` (`class_name DeviceActionMap`):
  - Static and lazily initialized. **Not an autoload.**
  - On first use, and on `Input.joy_connection_changed`, for each joypad
    (ID 0–15) it creates a device-scoped copy of every gameplay action (for
    example `"throttle@j2"`). Each copy contains only that action's joypad
    events, re-targeted to that device. The copy keeps the core action's
    deadzone.
  - It creates a keyboard-only copy per action (`"throttle@kb"`) holding
    only the keyboard events. The core actions in `project.godot` stay
    untouched as the single editable blueprint, so the editor Input Map
    stays clean.
  - API: `DeviceActionMap.action_name(device: int, action: StringName) -> StringName`.
    It returns an empty `StringName` for a disconnected device instead of
    asserting.
  - `ui_*` actions are skipped.
  - `rebuild()` re-derives all copies after a remap. A future remap menu
    calls it.
- `InputSource` keeps its public API and slot model. It reads
  `Input.get_action_strength(DeviceActionMap.action_name(device, "throttle"))`
  and so on, for both keyboard and joypad slots. The hardcoded `JOY_*`
  constants and the private deadzone are deleted. Deadzones move to the
  per-action values in `project.godot`.
- The keyboard slot sentinel becomes `InputEvent.DEVICE_ID_KEYBOARD` (16),
  replacing `-1`.

Tickets: [T-002](../tasks/T-002-device-action-map.md) (the class) and
[T-003](../tasks/T-003-port-input-source-to-device-action-map.md)
(port `InputSource`).

---

### Consequences

**Positive:**
- One binding source (`project.godot` Input Map) for every device.
  Remapping becomes possible.
- The keyboard slot no longer responds to joypad 0. Splitscreen input
  isolation is actually correct.
- No new autoload and no vendor dependency to track. Native 4.7 device IDs
  from day one.
- Easy to test headless: `Input.parse_input_event()` with a
  `device`-tagged `InputEventJoypadMotion` drives one slot and must not
  drive another.

**Negative / Tradeoffs:**
- We own about 80 lines of input plumbing, including the disconnect edge
  cases MultiplayerInput's issue tracker documents (reads during the same
  frame as a disconnect).
- `project.godot` action deadzones (currently `0.5` on every action) now
  apply to analog steering and triggers. They must drop to about `0.08`
  for analog actions, or steering loses all fine control. T-003 owns this.
- Mutating `InputMap` at runtime is global state. `DeviceActionMap` is the
  only code allowed to add or erase actions.

---

### Alternatives Considered

1. **Vendor MultiplayerInput as-is:** Rejected (see Context: 4.7
   incompatibility, stale upstream, autoload, crash issues).
2. **Vendor a fork with PR #25 applied:** Rejected. We would own a fork of
   untyped code with known disconnect crashes, which is more maintenance
   than owning 80 typed lines.
3. **G.U.I.D.E** (`godotneers/G.U.I.D.E`, MIT, v0.15.1, active): Rejected
   for driving input. It supports a joypad index per `GUIDEInputJoy*`, but
   its actions and mapping contexts are global resources. Four local
   players would need four duplicated action and context sets. Reconsider
   G.U.I.D.E only as a combined remap-UI and input-prompt layer, against
   [ADR-010](ADR-010-input-glyph-addon-controller-icons.md), when the
   first remap menu is built.
4. **Keep raw joypad polling:** Rejected. All three defects in Context
   remain, and defect 3 breaks splitscreen.
