# T-002: `DeviceActionMap` — Per-Device Action Copies

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Todo
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-014](../adr/ADR-014-per-device-input-action-map.md)

### Goal

Create a small typed class that derives device-scoped copies of every
gameplay action from the `project.godot` Input Map. After this, code can
ask "is `throttle` pressed **on joypad 2**" through the normal action API,
with one binding source for every device.

### Acceptance Criteria

- [ ] `DeviceActionMap.action_name(device, &"throttle")` returns a
      device-scoped action name for the keyboard
      (`InputEvent.DEVICE_ID_KEYBOARD`) and for every connected joypad
      (0–15).
- [ ] The keyboard copy contains only keyboard events. Each joypad copy
      contains only joypad events, re-targeted to that device ID. Core
      actions are unchanged.
- [ ] A disconnected or unknown device returns an empty `StringName`. It
      never asserts or crashes.
- [ ] `rebuild()` erases and re-derives all copies. `clear()` erases them
      (used by tests).
- [ ] Analog action deadzones in `project.godot` are lowered from `0.5` to
      `0.08` (`throttle`, `brake`, `steer_left`, `steer_right`). `drift`
      may stay at `0.5`.
- [ ] A new GdUnit4 suite covers isolation, and `task ci` is green.

### Context

- Godot 4.7 has **no** device parameter on `Input.is_action_*`,
  `get_action_strength` or `get_axis` (verified on 4.7.2 via `ClassDB`).
- 4.7 device IDs: joypads are `0..15`, `InputEvent.DEVICE_ID_KEYBOARD = 16`,
  `DEVICE_ID_MOUSE = 32`, `DEVICE_ID_EMULATION = -1`.
- The technique comes from `matjlars/godot-multiplayer-input` (MIT). Credit
  it in the file header. Do **not** copy its device-8 disable trick or its
  prefix-match erase, both of which are wrong on 4.7 (see ADR-014).
- AGENTS.md Autoload Policy: this is **not** an autoload. Use static
  methods with lazy initialization.

### Files Likely Affected

- `scripts/input/device_action_map.gd` (new; create `scripts/input/`)
- `test/unit/test_device_action_map.gd` (new)
- `project.godot` (deadzones only, edited through the editor's Input Map)

### Implementation Plan

1. Branch `feature/device-action-map`.
2. Write `scripts/input/device_action_map.gd`:
   ```gdscript
   class_name DeviceActionMap
   extends RefCounted
   ## Derives device-scoped copies of gameplay InputMap actions (ADR-014).
   ## Technique adapted from matjlars/godot-multiplayer-input (MIT).

   const KEYBOARD: int = InputEvent.DEVICE_ID_KEYBOARD
   const MAX_JOYPAD_ID: int = 15

   static var _built: bool = false
   ## device id -> { core action -> device action name }
   static var _names: Dictionary[int, Dictionary] = {}

   static func action_name(device: int, action: StringName) -> StringName: ...
   static func ensure_built() -> void: ...
   static func build_device(device: int) -> void: ...
   static func erase_device(device: int) -> void: ...
   static func rebuild() -> void: ...
   static func clear() -> void: ...
   static func _on_joy_connection_changed(device: int, connected: bool) -> void: ...
   ```
3. `ensure_built()`:
   - Return if `_built`.
   - Connect `Input.joy_connection_changed` to the static handler, guarded
     with `is_connected`.
   - Call `build_device(KEYBOARD)`, then call `build_device(id)` for each
     ID in `Input.get_connected_joypads()`.
   - Set `_built = true`.
4. Core actions: `InputMap.get_actions()`, skipping names that start with
   `ui_` or contain `@`, because those are already generated copies.
5. `build_device(device)`: for each core action, filter
   `InputMap.action_get_events()`:
   - for `KEYBOARD`: keep `InputEventKey` (and mouse button events if any
     are ever bound)
   - for joypads: keep `InputEventJoypadButton` and `InputEventJoypadMotion`

   Skip the action if the filtered list is empty. Name the copy
   `"%s@kb"` or `"%s@j%d"`. Then call
   `InputMap.add_action(copy_name, InputMap.action_get_deadzone(core))`.
   For each event: `duplicate()`, set `device` (joypad ID, or
   `DEVICE_ID_KEYBOARD` for keys), then `InputMap.action_add_event()`.
   Store the name in `_names[device][core]`.
6. Keyboard device check: parse an `InputEventKey` with
   `device = DEVICE_ID_KEYBOARD` and confirm it triggers the copy. If
   4.7's key events do not carry ID 16 on some platform, set keyboard
   copies to `device = -1` (all) instead, since only keyboards emit key
   events. Record which one worked in the file's doc comment.
7. `erase_device(device)`: erase the **exact** names stored in
   `_names[device]` with `InputMap.has_action` guards, then erase the entry.
   Never match by prefix.
8. `action_name()`: call `ensure_built()`, then return
   `_names.get(device, {}).get(action, &"")`.
9. Lower the deadzones in the editor Input Map (step 4 of the Acceptance
   Criteria).
10. Tests (`test/unit/test_device_action_map.gd`), with `clear()` in
    `after_test`:
    - `build_device(3)` and `build_device(2)`. Parse
      `InputEventJoypadMotion` with `device = 3`,
      `axis = JOY_AXIS_TRIGGER_RIGHT`, `axis_value = 1.0`, then
      `Input.flush_buffered_events()`. Assert
      `Input.get_action_strength(action_name(3, &"throttle")) > 0.9`, and
      the same read for device 2 and `KEYBOARD` returns `0.0`.
    - The keyboard copy of `throttle` contains no joypad events.
    - `action_name(9, &"throttle")` returns `&""` when device 9 was never
      built.
    - Core action `throttle` still has its original event count after
      building.
11. `task fmt && task lint && task test`.

### Verification

`task test` passes, including the new suite.

### Dependencies

None.

### Risks / Notes

- Static `Callable` for the signal: Godot 4.x supports connecting a static
  function. If 4.7 rejects it, fall back to a tiny inner `RefCounted`
  listener held in a static var.
- Tests mutate global `InputMap`, so `clear()` in `after_test` is mandatory
  to avoid leaking actions into other suites.
