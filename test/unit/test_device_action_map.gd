extends GdUnitTestSuite

## DeviceActionMap isolation (ADR-014, T-002). Events are synthesized with
## explicit `device` values, so no hardware is needed.

const THROTTLE: StringName = &"throttle"


func before_test() -> void:
	DeviceActionMap.clear()


func after_test() -> void:
	_release_all()
	DeviceActionMap.clear()


func test_every_connected_device_gets_a_scoped_name() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	DeviceActionMap.build_device(0)
	DeviceActionMap.build_device(15)
	for device: int in [DeviceActionMap.KEYBOARD, 0, 15]:
		var scoped: StringName = DeviceActionMap.action_name(device, THROTTLE)
		assert_bool(scoped != &"").is_true()
		assert_bool(InputMap.has_action(scoped)).is_true()
	assert_str(DeviceActionMap.action_name(DeviceActionMap.KEYBOARD, THROTTLE)).is_equal(
		"throttle@kb"
	)
	assert_str(DeviceActionMap.action_name(15, THROTTLE)).is_equal("throttle@j15")
	assert_str(DeviceActionMap.action_name(2, THROTTLE)).is_equal("")


func test_joypad_axis_drives_only_its_own_device() -> void:
	DeviceActionMap.build_device(2)
	DeviceActionMap.build_device(3)
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	_send_trigger(3, 1.0)
	assert_float(_strength(3)).is_greater(0.9)
	assert_float(_strength(2)).is_equal(0.0)
	assert_float(_strength(DeviceActionMap.KEYBOARD)).is_equal(0.0)
	assert_float(Input.get_action_strength(THROTTLE)).is_equal(0.0)


func test_keyboard_event_drives_only_keyboard_copy() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	DeviceActionMap.build_device(0)
	var key := InputEventKey.new()
	assert_int(key.device).is_equal(InputEvent.DEVICE_ID_KEYBOARD)
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	assert_float(_strength(DeviceActionMap.KEYBOARD)).is_equal(1.0)
	assert_float(_strength(0)).is_equal(0.0)


func test_joypad_zero_does_not_drive_keyboard_copy() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	DeviceActionMap.build_device(0)
	_send_trigger(0, 1.0)
	assert_float(_strength(0)).is_greater(0.9)
	assert_float(_strength(DeviceActionMap.KEYBOARD)).is_equal(0.0)


func test_keyboard_copy_has_only_keyboard_events() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	var events: Array[InputEvent] = InputMap.action_get_events(
		DeviceActionMap.action_name(DeviceActionMap.KEYBOARD, THROTTLE)
	)
	assert_int(events.size()).is_greater(0)
	for event: InputEvent in events:
		assert_bool(event is InputEventKey).is_true()
		assert_int(event.device).is_equal(DeviceActionMap.KEYBOARD)


func test_joypad_copy_has_only_retargeted_joypad_events() -> void:
	DeviceActionMap.build_device(5)
	var events: Array[InputEvent] = InputMap.action_get_events(
		DeviceActionMap.action_name(5, THROTTLE)
	)
	assert_int(events.size()).is_greater(0)
	for event: InputEvent in events:
		assert_bool(event is InputEventJoypadMotion or event is InputEventJoypadButton).is_true()
		assert_int(event.device).is_equal(5)


func test_unknown_and_invalid_devices_return_empty_name() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	assert_str(DeviceActionMap.action_name(9, THROTTLE)).is_equal("")
	assert_str(DeviceActionMap.action_name(99, THROTTLE)).is_equal("")
	assert_str(DeviceActionMap.action_name(-1, THROTTLE)).is_equal("")
	assert_str(DeviceActionMap.action_name(DeviceActionMap.KEYBOARD, &"no_such")).is_equal("")
	DeviceActionMap.build_device(99)
	assert_str(DeviceActionMap.action_name(99, THROTTLE)).is_equal("")


func test_core_action_is_unchanged_by_building() -> void:
	var before: Array[InputEvent] = InputMap.action_get_events(THROTTLE)
	var deadzone: float = InputMap.action_get_deadzone(THROTTLE)
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	DeviceActionMap.build_device(1)
	var after: Array[InputEvent] = InputMap.action_get_events(THROTTLE)
	assert_int(after.size()).is_equal(before.size())
	assert_float(InputMap.action_get_deadzone(THROTTLE)).is_equal(deadzone)


func test_copy_keeps_core_deadzone_and_ignores_stick_noise() -> void:
	DeviceActionMap.build_device(1)
	var scoped: StringName = DeviceActionMap.action_name(1, THROTTLE)
	assert_float(InputMap.action_get_deadzone(scoped)).is_equal(
		InputMap.action_get_deadzone(THROTTLE)
	)
	assert_float(InputMap.action_get_deadzone(THROTTLE)).is_less_equal(0.1)
	_send_trigger(1, 0.04)
	assert_float(_strength(1)).is_equal(0.0)
	_send_trigger(1, 0.3)
	assert_float(_strength(1)).is_greater(0.2)


func test_erase_device_removes_only_that_device() -> void:
	DeviceActionMap.build_device(1)
	DeviceActionMap.build_device(2)
	var gone: StringName = DeviceActionMap.action_name(1, THROTTLE)
	DeviceActionMap.erase_device(1)
	assert_bool(InputMap.has_action(gone)).is_false()
	assert_str(DeviceActionMap.action_name(1, THROTTLE)).is_equal("")
	assert_bool(InputMap.has_action(DeviceActionMap.action_name(2, THROTTLE))).is_true()
	assert_bool(InputMap.has_action(THROTTLE)).is_true()


func test_erase_does_not_match_by_prefix() -> void:
	# "throttle@j1" must not take "throttle@j10" with it.
	DeviceActionMap.build_device(1)
	DeviceActionMap.build_device(10)
	DeviceActionMap.erase_device(1)
	assert_bool(InputMap.has_action(DeviceActionMap.action_name(10, THROTTLE))).is_true()


func test_disconnect_signal_erases_and_connect_rebuilds() -> void:
	DeviceActionMap.ensure_built()
	DeviceActionMap.on_joy_connection_changed(4, true)
	var scoped: StringName = DeviceActionMap.action_name(4, THROTTLE)
	assert_bool(InputMap.has_action(scoped)).is_true()
	DeviceActionMap.on_joy_connection_changed(4, false)
	assert_bool(InputMap.has_action(scoped)).is_false()
	assert_str(DeviceActionMap.action_name(4, THROTTLE)).is_equal("")


func test_rebuild_rederives_after_core_remap() -> void:
	DeviceActionMap.ensure_built()
	var core_count: int = InputMap.action_get_events(THROTTLE).size()
	var extra := InputEventKey.new()
	extra.physical_keycode = KEY_UP
	InputMap.action_add_event(THROTTLE, extra)
	var kb_name: StringName = DeviceActionMap.action_name(DeviceActionMap.KEYBOARD, THROTTLE)
	var kb_count: int = InputMap.action_get_events(kb_name).size()
	DeviceActionMap.rebuild()
	kb_name = DeviceActionMap.action_name(DeviceActionMap.KEYBOARD, THROTTLE)
	assert_int(InputMap.action_get_events(kb_name).size()).is_equal(kb_count + 1)
	InputMap.action_erase_event(THROTTLE, extra)
	assert_int(InputMap.action_get_events(THROTTLE).size()).is_equal(core_count)


func test_clear_erases_all_copies() -> void:
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)
	DeviceActionMap.build_device(0)
	DeviceActionMap.clear()
	for action: StringName in InputMap.get_actions():
		assert_bool(String(action).contains("@")).is_false()


func _strength(device: int) -> float:
	return Input.get_action_strength(DeviceActionMap.action_name(device, THROTTLE))


func _send_trigger(device: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = JOY_AXIS_TRIGGER_RIGHT
	motion.axis_value = value
	Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _release_all() -> void:
	for device: int in range(0, 16):
		_send_trigger(device, 0.0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
