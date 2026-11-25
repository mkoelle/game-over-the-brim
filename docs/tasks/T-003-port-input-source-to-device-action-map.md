# T-003: Port `InputSource` onto `DeviceActionMap`

**Assignee:** Unassigned
**Date:** 2026-11-24
**Priority:** P1
**Status:** Done
**Estimate:** 3h
**Phase:** 1 — Feel-test support ([plan](../plans/addon-adoption-plan.md))
**ADR:** [ADR-014](../adr/ADR-014-per-device-input-action-map.md)

### Goal

Make `InputSource` read device-scoped actions for **both** keyboard and
joypad slots. Delete the hardcoded `JOY_*` polling path. This also fixes
the keyboard slot responding to joypad 0.

### Acceptance Criteria

- [x] `InputSource.get_input()` keeps its current return shape
      (`throttle`, `steer`, `drift`) and public API.
- [x] `KEYBOARD_DEVICE` equals `InputEvent.DEVICE_ID_KEYBOARD` (16). The
      constructor default stays "keyboard".
- [x] No `JOY_AXIS_*`, `JOY_BUTTON_*` or `AXIS_DEADZONE` constants remain.
      Deadzones come from the Input Map.
- [x] When a device's actions are missing (empty `StringName`, for example
      during a disconnect), the read returns neutral input
      (`0.0, 0.0, false`) without errors.
- [x] `test_vehicle_controller.gd` is updated to press device-scoped
      keyboard actions and passes. *`test_debug_overlay.gd` pressed the
      core `throttle` too, so it got the same one-line change.*
- [x] A new isolation test proves joypad input on device N does not drive
      the keyboard slot or device M.

### Context

- Current defect: `project.godot` joypad events are bound with
  `"device": 0`, and the keyboard slot reads the *global* action, so
  joypad 0 drives the keyboard player's car too. This is invisible with
  one car and breaks splitscreen.
- `test_vehicle_controller.gd` drives input with
  `runner.simulate_action_press("throttle")`, which calls
  `Input.action_press` on the **core** action. After this port, the
  keyboard slot reads `throttle@kb`, so the test must press
  `DeviceActionMap.action_name(InputSource.KEYBOARD_DEVICE, &"throttle")`
  instead.

### Files Likely Affected

- `scripts/vehicles/input_source.gd`
- `test/unit/test_vehicle_controller.gd`
- `test/unit/test_input_source.gd` (new)

### Implementation Plan

1. Branch `feature/input-source-device-actions` from the T-002 branch, or
   from `main` after T-002 merges.
2. Rewrite the `input_source.gd` internals:
   ```gdscript
   const KEYBOARD_DEVICE: int = InputEvent.DEVICE_ID_KEYBOARD

   func get_input() -> Dictionary[String, Variant]:
       var throttle_action: StringName = DeviceActionMap.action_name(device, &"throttle")
       if throttle_action.is_empty():
           return {"throttle": 0.0, "steer": 0.0, "drift": false}
       var brake: float = Input.get_action_strength(DeviceActionMap.action_name(device, &"brake"))
       ...
       var steer: float = Input.get_axis(
           DeviceActionMap.action_name(device, &"steer_left"),
           DeviceActionMap.action_name(device, &"steer_right"))
   ```
   Cache the five action names in `_init()` (and refresh them on a cache
   miss), so `get_input()` does no string formatting per physics tick
   (AGENTS.md "avoid allocations in `_process()`"). The returned
   Dictionary is an existing per-tick allocation; leave it, and note it
   for a later pass.
3. Rewrite the class doc comment. Remove the "two read paths" explanation
   and point to ADR-014.
4. Update `test_vehicle_controller.gd`: replace the
   `simulate_action_press("throttle")` and release calls with the
   keyboard device-scoped name, and update the header comment that
   describes the old path.
5. New `test/unit/test_input_source.gd`:
   - `DeviceActionMap.build_device(1)`, then `InputSource.new(1)` and
     `InputSource.new()` (keyboard).
   - Parse `InputEventJoypadMotion` with `device = 1` and the left stick X
     at `-1.0`. Assert source 1 `steer < -0.9` and keyboard source
     `steer == 0.0`.
   - Parse `InputEventJoypadMotion` with `device = 0` and the right
     trigger at `1.0`. Assert the keyboard source `throttle == 0.0` (the
     regression for the joypad-0 leak).
   - `InputSource.new(7)` on an unbuilt device returns neutral input.
   - `DeviceActionMap.clear()` in `after_test`.
6. Manual check (required; the owner has 2+ gamepads): temporarily set
   `_car.input_source = InputSource.new(1)` in `main.gd`. Only pad 1
   drives the car, and pad 0 and the keyboard do nothing. Revert before
   committing.
7. `task ci`.

### Verification

`task test` passes, including `test_input_source.gd` and the updated
`test_vehicle_controller.gd`.

### Dependencies

- T-002

### Verification results

- `task ci`: Overall Summary 36 test cases, 0 errors, 0 failures,
  0 orphans. Exit code 0. `fmt:check` and `lint` clean.
- `test_input_source.gd` has 11 cases: joypad 0 and 1 do not move the
  keyboard slot, keyboard does not move a joypad, two joypads are isolated
  both ways, deadzone noise (0.04) is ignored, throttle/brake/steer combine
  on pad and keyboard, unbuilt device is neutral, disconnect then rebuild
  recovers, and a source created before its device was built picks it up.
- `main.gd` did not change. `VehicleController` already holds
  `InputSource.new()` (keyboard), and the public API is unchanged.

### Assumptions (owner to validate)

- **Pending owner (step 6):** manual 2+ gamepad isolation check. Needs
  hardware the builder does not have. Steps:
  1. Temporarily add `_car.input_source = InputSource.new(1)` in
     `scripts/main.gd` after the car is spawned. Do not commit it.
  2. Run `task run` and press F3 for the overlay.
  3. Move pad 1's right trigger and left stick. The overlay `Throttle`
     and `Steer` lines must follow and the car must drive.
  4. Move pad 0 and press W, A, S, D. The overlay must stay at
     `Throttle: +0.00`, `Steer: +0.00`.
  5. Change it to `InputSource.new(0)` and repeat with the roles swapped.
  6. Revert the temporary line.
- **Assumption:** A joypad unplugged and replugged mid-run recovers
  without errors. (From T-002.)
  **Evidence:** `test_disconnect_returns_neutral_and_reconnect_recovers`
  covers erase then rebuild. No real hotplug was exercised.
  **Owner check:** In the temporary setup above, unplug pad 1. The car
  must coast with neutral input and the Output panel must show no errors.
  Replug it and it must drive again. Pad 0 and the keyboard stay inert
  throughout.
- **Assumption:** A deadzone of 0.08 leaves no stick drift at rest. (From
  T-002.)
  **Evidence:** The unit test shows 0.04 noise is ignored and 0.3 passes.
  Real hardware noise is not measured.
  **Owner check:** With the temporary setup, leave each pad untouched for
  10 seconds. The overlay must stay at `Steer: +0.00` and
  `Throttle: +0.00`. If it twitches, raise the deadzone in `project.godot`
  for that action.
