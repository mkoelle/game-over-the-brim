extends GdUnitTestSuite

## InputSource reads only its own device's actions (ADR-014, T-003). Events are
## synthesized with explicit `device` values, so no hardware is needed.

const RIGHT_SHOULDER_BUTTON: int = JOY_BUTTON_RIGHT_SHOULDER


func before_test() -> void:
	DeviceActionMap.clear()
	DeviceActionMap.build_device(DeviceActionMap.KEYBOARD)


func after_test() -> void:
	_release_all()
	DeviceActionMap.clear()


func test_default_source_is_keyboard() -> void:
	assert_int(InputSource.KEYBOARD_DEVICE).is_equal(InputEvent.DEVICE_ID_KEYBOARD)
	assert_int(InputSource.new().device).is_equal(InputEvent.DEVICE_ID_KEYBOARD)


func test_joypad_input_does_not_move_keyboard_source() -> void:
	DeviceActionMap.build_device(0)
	DeviceActionMap.build_device(1)
	var keyboard := InputSource.new()
	var pad1 := InputSource.new(1)
	_send_axis(1, JOY_AXIS_LEFT_X, -1.0)
	assert_float(pad1.get_input()["steer"]).is_less(-0.9)
	assert_float(keyboard.get_input()["steer"]).is_equal(0.0)


func test_joypad_zero_throttle_does_not_leak_into_keyboard_source() -> void:
	DeviceActionMap.build_device(0)
	var keyboard := InputSource.new()
	var pad0 := InputSource.new(0)
	_send_axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert_float(pad0.get_input()["throttle"]).is_greater(0.9)
	assert_float(keyboard.get_input()["throttle"]).is_equal(0.0)


func test_keyboard_input_does_not_move_joypad_source() -> void:
	DeviceActionMap.build_device(0)
	var keyboard := InputSource.new()
	var pad0 := InputSource.new(0)
	_send_key(KEY_W, true)
	_send_key(KEY_D, true)
	_send_key(KEY_SPACE, true)
	var kb_input: Dictionary[String, Variant] = keyboard.get_input()
	assert_float(kb_input["throttle"]).is_equal(1.0)
	assert_float(kb_input["steer"]).is_equal(1.0)
	assert_bool(kb_input["drift"]).is_true()
	var pad_input: Dictionary[String, Variant] = pad0.get_input()
	assert_float(pad_input["throttle"]).is_equal(0.0)
	assert_float(pad_input["steer"]).is_equal(0.0)
	assert_bool(pad_input["drift"]).is_false()


func test_two_joypad_sources_are_isolated() -> void:
	DeviceActionMap.build_device(1)
	DeviceActionMap.build_device(2)
	var pad1 := InputSource.new(1)
	var pad2 := InputSource.new(2)
	_send_axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_send_axis(1, JOY_AXIS_LEFT_X, 1.0)
	_send_button(1, RIGHT_SHOULDER_BUTTON, true)
	var input1: Dictionary[String, Variant] = pad1.get_input()
	assert_float(input1["throttle"]).is_greater(0.9)
	assert_float(input1["steer"]).is_greater(0.9)
	assert_bool(input1["drift"]).is_true()
	var input2: Dictionary[String, Variant] = pad2.get_input()
	assert_float(input2["throttle"]).is_equal(0.0)
	assert_float(input2["steer"]).is_equal(0.0)
	assert_bool(input2["drift"]).is_false()
	# And the other way round.
	_send_axis(2, JOY_AXIS_LEFT_X, -1.0)
	assert_float(pad2.get_input()["steer"]).is_less(-0.9)
	assert_float(pad1.get_input()["steer"]).is_greater(0.9)


func test_stick_noise_below_deadzone_is_ignored() -> void:
	DeviceActionMap.build_device(1)
	var pad1 := InputSource.new(1)
	_send_axis(1, JOY_AXIS_LEFT_X, 0.04)
	_send_axis(1, JOY_AXIS_TRIGGER_RIGHT, 0.04)
	assert_float(pad1.get_input()["steer"]).is_equal(0.0)
	assert_float(pad1.get_input()["throttle"]).is_equal(0.0)
	_send_axis(1, JOY_AXIS_LEFT_X, 0.3)
	assert_float(pad1.get_input()["steer"]).is_greater(0.2)


func test_throttle_brake_and_steer_combine() -> void:
	DeviceActionMap.build_device(1)
	var pad1 := InputSource.new(1)
	_send_axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_send_axis(1, JOY_AXIS_TRIGGER_LEFT, 0.4)
	_send_axis(1, JOY_AXIS_LEFT_X, -1.0)
	var input: Dictionary[String, Variant] = pad1.get_input()
	assert_float(input["throttle"]).is_between(0.5, 0.7)
	assert_float(input["steer"]).is_less(-0.9)
	# Brake alone goes negative, and both full cancels out.
	_send_axis(1, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	assert_float(pad1.get_input()["throttle"]).is_between(-0.5, -0.3)
	_send_axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_send_axis(1, JOY_AXIS_TRIGGER_LEFT, 1.0)
	assert_float(pad1.get_input()["throttle"]).is_equal(0.0)


func test_keyboard_throttle_brake_steer_combine() -> void:
	var keyboard := InputSource.new()
	_send_key(KEY_W, true)
	_send_key(KEY_S, true)
	_send_key(KEY_A, true)
	_send_key(KEY_D, true)
	var input: Dictionary[String, Variant] = keyboard.get_input()
	assert_float(input["throttle"]).is_equal(0.0)
	assert_float(input["steer"]).is_equal(0.0)
	_send_key(KEY_S, false)
	_send_key(KEY_D, false)
	input = keyboard.get_input()
	assert_float(input["throttle"]).is_equal(1.0)
	assert_float(input["steer"]).is_equal(-1.0)


func test_unbuilt_device_returns_neutral_input() -> void:
	var ghost := InputSource.new(7)
	var input: Dictionary[String, Variant] = ghost.get_input()
	assert_float(input["throttle"]).is_equal(0.0)
	assert_float(input["steer"]).is_equal(0.0)
	assert_bool(input["drift"]).is_false()


func test_disconnect_returns_neutral_and_reconnect_recovers() -> void:
	DeviceActionMap.build_device(3)
	var pad3 := InputSource.new(3)
	_send_axis(3, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert_float(pad3.get_input()["throttle"]).is_greater(0.9)
	DeviceActionMap.erase_device(3)
	assert_float(pad3.get_input()["throttle"]).is_equal(0.0)
	DeviceActionMap.build_device(3)
	assert_float(pad3.get_input()["throttle"]).is_greater(0.9)


func test_source_created_before_device_is_built_picks_it_up() -> void:
	var late := InputSource.new(5)
	assert_float(late.get_input()["throttle"]).is_equal(0.0)
	DeviceActionMap.build_device(5)
	_send_axis(5, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	assert_float(late.get_input()["throttle"]).is_greater(0.9)


func _send_axis(device: int, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _send_button(device: int, button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button as JoyButton
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_key(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = pressed
	Input.parse_input_event(key)
	Input.flush_buffered_events()


func _release_all() -> void:
	for device: int in range(0, 16):
		for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			_send_axis(device, axis as JoyAxis, 0.0)
		_send_button(device, RIGHT_SHOULDER_BUTTON, false)
	for keycode: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		_send_key(keycode, false)
