class_name DeviceActionMap
extends RefCounted
## Derives device-scoped copies of gameplay InputMap actions (ADR-014).
##
## Godot 4.7 has no device parameter on Input.is_action_*, so "throttle on
## joypad 2" is answered by a second action, "throttle@j2", that holds only
## joypad 2's events. Keyboards use "throttle@kb". The core actions in
## project.godot stay untouched and remain the single editable blueprint.
##
## Technique adapted from matjlars/godot-multiplayer-input (MIT). This is a
## typed, non-autoload rewrite. It does NOT copy that addon's "move core
## joypad events to device 8" trick (8 is a valid joypad ID on 4.7) or its
## prefix-match erase. Copies are erased by their exact stored names.
##
## Engine facts this design depends on (verified against tag 4.7.2-stable):
## - Joypad IDs are 0..15: Input::JOYPADS_MAX = 16 (core/input/input.h:104).
##   The SDL driver assigns the lowest free ID via Input::get_unused_joy_id()
##   (drivers/sdl/joypad_sdl.cpp:128, core/input/input.cpp:2303-2310).
## - InputEvent.DEVICE_ID_KEYBOARD = 16, DEVICE_ID_MOUSE = 32,
##   DEVICE_ID_EMULATION = -1 (core/input/input_event.h:64-67).
## - Keyboard events carry device 16, not 0 or -1: the InputEventKey
##   constructor calls set_device(DEVICE_ID_KEYBOARD)
##   (core/input/input_event.cpp:669-671). Keyboard copies therefore use 16.
##   test_keyboard_event_drives_only_keyboard_copy confirms it.
## - A binding matches an event when the binding's device is
##   InputMap::ALL_DEVICES (-1) or equals the event's device
##   (core/input/input_map.cpp:152-153; ALL_DEVICES in input_map.h:47).
##   project.godot keys are bound to -1 and joypad events to 0, which is why
##   the core actions leak joypad 0 into every reader.
## - InputMap.action_add_event() rewrites a key event with device 0 to 16
##   (core/input/input_map.cpp:209-216).

const KEYBOARD: int = InputEvent.DEVICE_ID_KEYBOARD
const MAX_JOYPAD_ID: int = 15
const _KEYBOARD_SUFFIX: String = "@kb"
const _JOYPAD_SUFFIX: String = "@j"

static var _built: bool = false
## device id -> { core action -> device action name }
static var _names: Dictionary[int, Dictionary] = { }


## Returns the device-scoped action name for `action`, or an empty StringName
## if the device has no copy (disconnected, never built, or invalid).
static func action_name(device: int, action: StringName) -> StringName:
	ensure_built()
	if not _names.has(device):
		return &""
	var device_actions: Dictionary = _names[device]
	return device_actions.get(action, &"")


## Builds the keyboard copy and a copy for every connected joypad, once.
static func ensure_built() -> void:
	if _built:
		return
	_built = true
	var callable: Callable = on_joy_connection_changed
	if not Input.joy_connection_changed.is_connected(callable):
		Input.joy_connection_changed.connect(callable)
	build_device(KEYBOARD)
	for joypad_id: int in Input.get_connected_joypads():
		build_device(joypad_id)


## Derives (or re-derives) the copies for one device. Invalid IDs are ignored.
static func build_device(device: int) -> void:
	if not _is_valid_device(device):
		return
	erase_device(device)
	var names: Dictionary[StringName, StringName] = { }
	for core: StringName in _core_actions():
		var events: Array[InputEvent] = _events_for_device(core, device)
		if events.is_empty():
			continue
		var copy_name: StringName = _copy_name(core, device)
		InputMap.add_action(copy_name, InputMap.action_get_deadzone(core))
		for event: InputEvent in events:
			InputMap.action_add_event(copy_name, event)
		names[core] = copy_name
	_names[device] = names


## Erases one device's copies by their exact stored names, never by prefix.
static func erase_device(device: int) -> void:
	if not _names.has(device):
		return
	var device_actions: Dictionary = _names[device]
	for copy_name: StringName in device_actions.values():
		if InputMap.has_action(copy_name):
			InputMap.erase_action(copy_name)
	_names.erase(device)


## Erases every copy and re-derives them. Call after the core map is remapped.
static func rebuild() -> void:
	clear()
	ensure_built()


## Erases every copy. Used by tests and by rebuild().
static func clear() -> void:
	for device: int in _names.keys():
		erase_device(device)
	_names.clear()
	_built = false


static func on_joy_connection_changed(device: int, connected: bool) -> void:
	if not _built:
		return
	if connected:
		build_device(device)
	else:
		erase_device(device)


static func _is_valid_device(device: int) -> bool:
	return device == KEYBOARD or (device >= 0 and device <= MAX_JOYPAD_ID)


static func _copy_name(core: StringName, device: int) -> StringName:
	if device == KEYBOARD:
		return StringName(String(core) + _KEYBOARD_SUFFIX)
	return StringName("%s%s%d" % [core, _JOYPAD_SUFFIX, device])


## Gameplay actions only. Copies (contain "@") and ui_* are skipped.
static func _core_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		var text: String = String(action)
		if text.begins_with("ui_") or text.contains("@"):
			continue
		result.append(action)
	return result


## Duplicated core events that belong to `device`, re-targeted to it.
static func _events_for_device(core: StringName, device: int) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(core):
		var copy: InputEvent = null
		if device == KEYBOARD:
			if event is InputEventKey:
				copy = event.duplicate()
				copy.device = KEYBOARD
			elif event is InputEventMouseButton:
				copy = event.duplicate()
				copy.device = InputEvent.DEVICE_ID_MOUSE
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			copy = event.duplicate()
			copy.device = device
		if copy != null:
			result.append(copy)
	return result
