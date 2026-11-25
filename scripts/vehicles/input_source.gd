class_name InputSource
extends RefCounted
## Wraps a single physical input device (keyboard or one gamepad) and exposes
## a normalized, per-vehicle input read.
##
## `extends RefCounted` (not Node): this class holds no scene-tree state and
## needs no per-frame engine callback of its own. The vehicle controller
## pulls a fresh reading from it once per physics tick via get_input().
##
## Per Architecture Decision 01 (docs/architecture/overview.md), vehicles
## never poll Input.* globally. They own an InputSource keyed to a device
## instead, so splitscreen, bots and network input can plug in later without
## touching vehicle code.
##
## Device scoping comes from DeviceActionMap (ADR-014). It derives copies of
## the core actions such as "throttle@kb" and "throttle@j1", each holding only
## that device's events. This class reads only its own device's copies, so no
## other device can move it. Deadzones come from the Input Map.

## Keyboard device id, the same value keyboard events carry.
const KEYBOARD_DEVICE: int = InputEvent.DEVICE_ID_KEYBOARD

const _ACTION_THROTTLE: StringName = &"throttle"
const _ACTION_BRAKE: StringName = &"brake"
const _ACTION_STEER_LEFT: StringName = &"steer_left"
const _ACTION_STEER_RIGHT: StringName = &"steer_right"
const _ACTION_DRIFT: StringName = &"drift"

## The device this source reads from: KEYBOARD_DEVICE for keyboard, or a
## joypad id (0..15) as reported by Input.get_connected_joypads().
var device: int = KEYBOARD_DEVICE

# Cached device-scoped action names. Empty means the device has no such action.
var _throttle: StringName = &""
var _brake: StringName = &""
var _steer_left: StringName = &""
var _steer_right: StringName = &""
var _drift: StringName = &""


func _init(p_device: int = KEYBOARD_DEVICE) -> void:
	device = p_device
	_refresh_names()


## Returns a snapshot of this device's current input, normalized as:
##   "throttle": float, -1.0..1.0 (positive = accelerate, negative = brake/reverse)
##   "steer":    float, -1.0..1.0 (negative = left, positive = right)
##   "drift":    bool
## Returns neutral input (0.0, 0.0, false) when the device has no actions, for
## example while it is disconnected.
func get_input() -> Dictionary[String, Variant]:
	if not InputMap.has_action(_throttle):
		# The device may have been (re)built or erased since we cached names.
		_refresh_names()
		if not InputMap.has_action(_throttle):
			return { "throttle": 0.0, "steer": 0.0, "drift": false }
	var throttle_strength: float = Input.get_action_strength(_throttle)
	var brake_strength: float = _strength(_brake)
	var steer_strength: float = _strength(_steer_right) - _strength(_steer_left)
	var drift_pressed: bool = _drift != &"" and Input.is_action_pressed(_drift)
	return {
		"throttle": clampf(throttle_strength - brake_strength, -1.0, 1.0),
		"steer": clampf(steer_strength, -1.0, 1.0),
		"drift": drift_pressed,
	}


func _strength(action: StringName) -> float:
	if action == &"":
		return 0.0
	return Input.get_action_strength(action)


func _refresh_names() -> void:
	_throttle = DeviceActionMap.action_name(device, _ACTION_THROTTLE)
	_brake = DeviceActionMap.action_name(device, _ACTION_BRAKE)
	_steer_left = DeviceActionMap.action_name(device, _ACTION_STEER_LEFT)
	_steer_right = DeviceActionMap.action_name(device, _ACTION_STEER_RIGHT)
	_drift = DeviceActionMap.action_name(device, _ACTION_DRIFT)
