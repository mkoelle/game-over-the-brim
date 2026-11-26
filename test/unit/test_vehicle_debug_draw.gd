extends GdUnitTestSuite

## T-007: VehicleDebugDraw math, F3 gating, and the ADR-016 isolation rules.

var _saved_debug_mode: bool = false


func before_test() -> void:
	_saved_debug_mode = GameConfig.debug_mode


func after_test() -> void:
	GameConfig.debug_mode = _saved_debug_mode


func test_slip_angle_zero_for_straight_motion() -> void:
	var angle: float = VehicleDebugDraw.slip_angle_deg(Vector3.FORWARD, Vector3.FORWARD * 10.0)
	assert_float(angle).is_equal_approx(0.0, 0.001)


func test_slip_angle_sign_and_size_for_sideways_velocity() -> void:
	# Facing -Z. Velocity rotated 30 degrees to the left (counter-clockwise
	# seen from above) gives a positive angle around +Y.
	var left: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(30.0)) * 10.0
	var right: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(-30.0)) * 10.0
	assert_float(VehicleDebugDraw.slip_angle_deg(Vector3.FORWARD, left)).is_equal_approx(30.0, 0.01)
	assert_float(VehicleDebugDraw.slip_angle_deg(Vector3.FORWARD, right)).is_equal_approx(
		-30.0,
		0.01,
	)


func test_slip_angle_zero_below_speed_threshold() -> void:
	var slow: Vector3 = Vector3.RIGHT * 0.4
	assert_float(VehicleDebugDraw.slip_angle_deg(Vector3.FORWARD, slow)).is_equal(0.0)
	assert_float(VehicleDebugDraw.slip_angle_deg(Vector3.FORWARD, Vector3.ZERO)).is_equal(0.0)


func test_velocity_arrow_length_scales_and_caps() -> void:
	assert_float(VehicleDebugDraw.velocity_arrow_length(10.0, 20.0)).is_equal_approx(1.5, 0.001)
	assert_float(VehicleDebugDraw.velocity_arrow_length(40.0, 20.0)).is_equal_approx(3.0, 0.001)
	assert_float(VehicleDebugDraw.velocity_arrow_length(5.0, 0.0)).is_equal(0.0)


func test_process_with_null_target_does_nothing() -> void:
	GameConfig.debug_mode = true
	var node: VehicleDebugDraw = auto_free(VehicleDebugDraw.new())
	node.call(&"_process", 0.016)
	assert_object(node.target).is_null()


func test_process_with_debug_mode_off_does_nothing() -> void:
	GameConfig.debug_mode = false
	var node: VehicleDebugDraw = auto_free(VehicleDebugDraw.new())
	node.target = auto_free(VehicleController.new())
	# The target has no stats and is not in the tree. Reaching past the
	# bool check would error, so a clean return proves the early exit.
	node.call(&"_process", 0.016)
	assert_bool(GameConfig.debug_mode).is_false()


func test_vehicle_controller_source_has_no_debug_draw_reference() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/vehicles/vehicle_controller.gd"
	)
	assert_bool(source.is_empty()).is_false()
	assert_bool(source.contains("DebugDraw3D")).is_false()


func test_scenes_do_not_reference_the_debug_draw_script() -> void:
	for path: String in ["res://scenes/main.tscn", "res://scenes/vehicles/tophat_car.tscn"]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(text.is_empty()).is_false()
		assert_bool(text.contains("vehicle_debug_draw")).is_false()
