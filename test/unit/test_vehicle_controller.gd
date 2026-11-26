extends GdUnitTestSuite

## Real behavioral coverage for VehicleController (STATE.md's Next Recommended
## Tasks item 8), replacing reliance on the boot-only smoke test in
## test/integration/test_main.gd.
##
## Input is driven through the scene_runner's simulate_action_press()/
## simulate_action_release(), the same pattern test/integration/test_main.gd
## uses for scene_runner()/simulate_frames(). Under the hood
## GdUnitSceneRunnerImpl calls Input.action_press() / Input.action_release()
## on the named action (see simulate_action_press()/simulate_action_release()
## in addons/gdUnit4/src/core/GdUnitSceneRunnerImpl.gd).
##
## The car's default InputSource is the keyboard slot (ADR-014), which reads
## only the device-scoped copy "throttle@kb", not the core "throttle" action.
## So the tests press that copy, found via DeviceActionMap.action_name(). This
## exercises the real keyboard InputSource code path end to end with no
## fake/stub. The runner also tracks and auto-releases any action left pressed
## when it is disposed (_reset_input_to_default() in GdUnitSceneRunnerImpl.gd).
## We still explicitly release the action at the end of every test as a
## belt-and-suspenders guard against state leaking into the next test case.

const TOPHAT_CAR_SCENE := "res://scenes/vehicles/tophat_car.tscn"


## 3 seconds at the default 60 Hz physics tick — comfortably past
## stats.max_speed / stats.acceleration (~1.7s for the Stovepipe Speedster)
## so the clamp in vehicle_controller.gd is actually exercised, not just
## the ramp-up.
const THROTTLE_FRAMES := 180

## A wall 10.5 m ahead of the car's nose is reached in about 26 physics
## frames at the Stovepipe Speedster's 24 m/s top speed.
const WALL_AHEAD_Z := -12.0


## Fixed input for the impact tests, so they do not depend on Input state.
class HeldInput:
	extends InputSource

	var throttle: float = 0.0


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": throttle, "steer": 0.0, "drift": false }


## Ground control (accel/brake/drift/steer) only runs while is_on_floor()
## is true — a deliberate fix so the car falls ballistically off a ramp
## instead of having its velocity re-snapped to the current facing every
## frame while airborne. Tests that exercise ground behavior need an
## actual floor under the standalone car instance, or is_on_floor() is
## always false and throttle correctly does nothing.
##
## The runner's scene sits directly under the tree root, so a body added
## beside it would outlive the test. auto_free removes it afterwards.
func _add_floor_under(car: Node3D) -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(200, 1, 200)
	floor_body.add_child(shape)
	floor_body.position = car.global_position + Vector3(0, -1.0, 0)
	car.get_parent().add_child(floor_body)


func test_loads_without_error() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()

	assert_object(car).is_instanceof(VehicleController)
	assert_object(car.stats).is_instanceof(VehicleStats)
	assert_object(car.stats).is_not_null()


func test_accelerates_under_throttle_and_respects_max_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var start_position: Vector3 = car.global_position

	runner.simulate_action_press(_keyboard_throttle())
	await runner.simulate_frames(THROTTLE_FRAMES)

	var forward: Vector3 = -car.global_transform.basis.z
	var flat_velocity: Vector3 = Vector3(car.velocity.x, 0.0, car.velocity.z)
	var forward_speed: float = flat_velocity.dot(forward)

	# Moved forward from the start position (horizontal plane only —
	# ground control (and therefore this whole test) requires
	# is_on_floor(), so a floor is added under the car above).
	var flat_displacement: Vector3 = Vector3(
		car.global_position.x - start_position.x,
		0.0,
		car.global_position.z - start_position.z,
	)
	assert_float(flat_displacement.length()).is_greater(0.0)

	# Actually accelerated, and never exceeds the configured cap — this is
	# the clampf(...) in vehicle_controller.gd's _physics_process actually
	# doing its job.
	assert_float(forward_speed).is_greater(0.0)
	assert_float(forward_speed).is_less_equal(car.stats.max_speed)

	runner.simulate_action_release(_keyboard_throttle())


func test_no_nan_or_inf_during_sustained_throttle() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()

	runner.simulate_action_press(_keyboard_throttle())
	await runner.simulate_frames(THROTTLE_FRAMES)

	var position: Vector3 = car.global_position
	var velocity: Vector3 = car.velocity

	assert_bool(is_finite(position.x)).is_true()
	assert_bool(is_finite(position.y)).is_true()
	assert_bool(is_finite(position.z)).is_true()
	assert_bool(is_finite(velocity.x)).is_true()
	assert_bool(is_finite(velocity.y)).is_true()
	assert_bool(is_finite(velocity.z)).is_true()

	runner.simulate_action_release(_keyboard_throttle())


## Device-scoped throttle action read by the default (keyboard) InputSource.
func _keyboard_throttle() -> StringName:
	return DeviceActionMap.action_name(InputSource.KEYBOARD_DEVICE, &"throttle")

# --- impacted signal (T-008) ---


## Adds a static wall on the Track layer (1), which the car collides with.
## Freed after the test, like the floor.
func _add_wall(car: Node3D, center: Vector3, size: Vector3) -> void:
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	wall.add_child(shape)
	wall.position = center
	car.get_parent().add_child(wall)


## Car on a floor with fixed input, recording every `impacted` speed.
func _impact_car(runner: GdUnitSceneRunner, impacts: Array[float]) -> VehicleController:
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	car.input_source = HeldInput.new()
	car.impacted.connect(
		func(impact_speed: float) -> void:
			impacts.append(impact_speed),
	)
	return car


## Physics ticks, not process frames: headless runs may draw several
## process frames per physics tick.
func _physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_impacted_fires_once_for_a_head_on_hit_held_against_the_wall() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	_add_wall(car, Vector3(0, 1.0, WALL_AHEAD_Z), Vector3(20, 3, 1))
	(car.input_source as HeldInput).throttle = 1.0
	car.velocity = Vector3(0, 0, -car.stats.max_speed)

	# About 26 frames to the wall, then over a second of full throttle into it.
	await _physics_frames(100)

	assert_int(impacts.size()).is_equal(1)
	assert_float(impacts[0]).is_equal_approx(car.stats.max_speed, 0.5)


func test_impacted_reports_only_the_speed_into_the_wall() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	_add_wall(car, Vector3(0, 1.0, -6.0), Vector3(60, 3, 1))
	# 60 degrees off the wall normal: half the speed goes into the wall.
	car.rotation.y = deg_to_rad(60.0)
	car.velocity = -car.global_basis.z * 20.0

	await _physics_frames(60)

	assert_int(impacts.size()).is_equal(1)
	assert_float(impacts[0]).is_equal_approx(10.0, 0.5)


func test_shallow_scrape_fires_once_and_keeps_momentum() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	# A long wall along the car's right side, 1 m away, and a nose turned
	# 5 degrees into it, at full throttle. Since T-029 the car turns along
	# the wall and keeps going instead of grinding against it.
	_add_wall(car, Vector3(2.0, 1.0, -90.0), Vector3(1, 3, 200))
	car.rotation.y = deg_to_rad(-5.0)
	(car.input_source as HeldInput).throttle = 1.0
	car.velocity = -car.global_basis.z * car.stats.max_speed

	await _physics_frames(180)

	assert_int(impacts.size()).is_equal(1)
	assert_float(car.speed).is_greater(car.stats.max_speed * 0.95)
	# The nose ends parallel to the wall (it ran along -Z).
	var heading_into_wall: float = rad_to_deg(asin((-car.global_basis.z).x))
	assert_float(absf(heading_into_wall)).is_less(1.0)


func test_impacted_fires_again_when_a_scrape_runs_into_another_wall() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	# The scrape setup above, plus a second wall across the path: a corner.
	_add_wall(car, Vector3(2.0, 1.0, -90.0), Vector3(1, 3, 200))
	_add_wall(car, Vector3(-5.0, 1.0, -40.0), Vector3(15, 3, 1))
	car.rotation.y = deg_to_rad(-5.0)
	(car.input_source as HeldInput).throttle = 1.0
	car.velocity = -car.global_basis.z * car.stats.max_speed

	await _physics_frames(150)

	assert_int(impacts.size()).is_equal(2)
	assert_float(impacts[0]).is_less(3.0)
	assert_float(impacts[1]).is_greater(20.0)


func test_impacted_fires_again_for_a_new_hit() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	_add_wall(car, Vector3(0, 1.0, -6.0), Vector3(20, 3, 1))
	# Coast into the wall; the bounce (T-029) carries the car back off it.
	car.velocity = Vector3(0, 0, -10.0)
	await _physics_frames(60)
	assert_int(impacts.size()).is_equal(1)
	# A second, separate run at the wall is a new hit.
	car.velocity = Vector3(0, 0, -10.0)
	await _physics_frames(60)

	assert_int(impacts.size()).is_equal(2)


func test_impacted_does_not_fire_on_floor_landings() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	(car.input_source as HeldInput).throttle = 1.0
	# A hard landing while driving forward, from 3 m up.
	car.position.y = 3.0
	car.velocity = Vector3(0, -8.0, -car.stats.max_speed)

	await _physics_frames(60)

	assert_bool(car.is_on_floor()).is_true()
	assert_int(impacts.size()).is_equal(0)


## T-027: steering curve and input ramp.
class SteerInput:
	extends InputSource

	var steer: float = 0.0


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": 0.0, "steer": steer, "drift": false }


func test_steer_fade_is_zero_at_standstill_and_full_when_moving() -> void:
	assert_float(VehicleController.steer_speed_fade(0.0, 1.0, 7.0)).is_equal(0.0)
	assert_float(VehicleController.steer_speed_fade(1.0, 1.0, 7.0)).is_equal(0.0)
	assert_float(VehicleController.steer_speed_fade(4.0, 1.0, 7.0)).is_between(0.2, 0.8)
	assert_float(VehicleController.steer_speed_fade(7.0, 1.0, 7.0)).is_equal(1.0)
	assert_float(VehicleController.steer_speed_fade(24.0, 1.0, 7.0)).is_equal(1.0)


func test_steer_ramp_reaches_full_lock_in_about_ramp_time() -> void:
	var steer: float = 0.0
	var ticks: int = 0
	while steer < 1.0 and ticks < 100:
		steer = VehicleController.ramp_steer(steer, 1.0, 1.0 / 60.0, 0.17, 0.28)
		ticks += 1
	# 0.17 s at 60 Hz is 10.2 ticks, so full lock lands on tick 11.
	assert_int(ticks).is_equal(11)


func test_steer_ramp_is_slower_across_centre() -> void:
	var dt: float = 1.0 / 60.0
	var from_centre: float = VehicleController.ramp_steer(0.0, 1.0, dt, 0.17, 0.28)
	var across: float = VehicleController.ramp_steer(-1.0, 1.0, dt, 0.17, 0.28)
	assert_float(from_centre).is_equal_approx(dt / 0.17, 0.0001)
	assert_float(across - (-1.0)).is_equal_approx(dt / 0.28, 0.0001)
	assert_float(across - (-1.0)).is_less(from_centre)


func test_full_lock_turn_radius_grows_with_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var input := SteerInput.new()
	car.input_source = input
	await runner.simulate_frames(5)
	var radii: Array[float] = []
	for speed: float in [10.0, 24.0]:
		car.rotation = Vector3.ZERO
		car.velocity = Vector3(0.0, 0.0, -speed)
		car.steer_applied = 1.0
		input.steer = 1.0
		await await_physics_ticks(5)
		var yaw0: float = car.rotation.y
		await await_physics_ticks(30)
		var rate: float = absf(angle_difference(yaw0, car.rotation.y)) / 0.5
		radii.append(speed / rate)
		# Flat yaw rate once moving (handling-reference.md section 1).
		assert_float(rate).is_between(1.1, 1.6)
	assert_float(radii[0]).is_between(6.0, 9.5)
	assert_float(radii[1]).is_between(15.0, 20.0)


func await_physics_ticks(ticks: int) -> void:
	for i: int in ticks:
		await get_tree().physics_frame


## T-028: speed and travel-direction model, grip and drift.
class DriftInput:
	extends InputSource

	var steer: float = 0.0
	var drift: bool = false


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": 0.0, "steer": steer, "drift": drift }


func _drift_car(runner: GdUnitSceneRunner, start_speed: float) -> DriftInput:
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var input := DriftInput.new()
	car.input_source = input
	car.rotation = Vector3.ZERO
	car.velocity = Vector3(0.0, 0.0, -start_speed)
	return input


func test_signed_speed_and_travel_direction() -> void:
	var fwd: Vector3 = Vector3.FORWARD
	assert_float(VehicleController.signed_speed(fwd * 10.0, fwd, 0.0)).is_equal_approx(10.0, 0.001)
	assert_float(VehicleController.signed_speed(-fwd * 4.0, fwd, 0.0)).is_equal_approx(-4.0, 0.001)
	# Sideways keeps the previous sign.
	assert_float(VehicleController.signed_speed(Vector3.RIGHT * 5.0, fwd, -2.0)).is_less(0.0)
	var back: Vector3 = VehicleController.travel_direction(-fwd * 4.0, fwd, -4.0)
	assert_vector(back).is_equal_approx(fwd, Vector3.ONE * 0.001)


func test_clamp_slide_and_turn_toward() -> void:
	var body: Vector3 = Vector3.FORWARD
	var wide: Vector3 = body.rotated(Vector3.UP, deg_to_rad(60.0))
	var clamped: Vector3 = VehicleController.clamp_slide(wide, body, deg_to_rad(35.0))
	assert_float(rad_to_deg(body.angle_to(clamped))).is_equal_approx(35.0, 0.01)
	var half: Vector3 = VehicleController.turn_toward(wide, body, 0.5)
	assert_float(rad_to_deg(body.angle_to(half))).is_equal_approx(30.0, 0.01)


func test_drift_steer_share_maps_to_twenty_to_eighty_percent() -> void:
	assert_float(VehicleController.drift_steer_share(-1.0)).is_equal_approx(0.2, 0.0001)
	assert_float(VehicleController.drift_steer_share(0.0)).is_equal_approx(0.5, 0.0001)
	assert_float(VehicleController.drift_steer_share(1.0)).is_equal_approx(0.8, 0.0001)


func test_drift_needs_button_steer_speed_and_ground() -> void:
	assert_bool(VehicleController.can_start_drift(true, 1.0, 20.0, true, 11.0)).is_true()
	assert_bool(VehicleController.can_start_drift(false, 1.0, 20.0, true, 11.0)).is_false()
	assert_bool(VehicleController.can_start_drift(true, 0.1, 20.0, true, 11.0)).is_false()
	assert_bool(VehicleController.can_start_drift(true, 1.0, 9.0, true, 11.0)).is_false()
	assert_bool(VehicleController.can_start_drift(true, 1.0, 20.0, false, 11.0)).is_false()
	assert_bool(VehicleController.can_start_drift(true, 1.0, -20.0, true, 11.0)).is_false()


func test_held_drift_slides_without_losing_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: DriftInput = _drift_car(runner, 20.0)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	await await_physics_ticks(120)
	assert_bool(car.is_drifting).is_true()
	assert_int(car.drift_direction).is_equal(1)
	# In-turn drift reaches the slide cap (25-45 degree target, capped at 35).
	assert_float(absf(car.slide_angle_deg)).is_between(25.0, 35.01)
	assert_float(car.speed).is_equal_approx(20.0, 0.05)


func test_drift_direction_stays_locked_and_release_ends_it() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: DriftInput = _drift_car(runner, 20.0)
	await await_physics_ticks(3)
	var ended: Array[int] = [0]
	car.drift_ended.connect(
		func() -> void:
			ended[0] += 1,
	)
	input.steer = -1.0
	input.drift = true
	await await_physics_ticks(20)
	assert_int(car.drift_direction).is_equal(-1)
	input.steer = 1.0
	await await_physics_ticks(40)
	# Steering out widens the line but does not flip or end the drift.
	assert_int(car.drift_direction).is_equal(-1)
	assert_bool(car.is_drifting).is_true()
	input.drift = false
	await await_physics_ticks(2)
	assert_bool(car.is_drifting).is_false()
	assert_int(ended[0]).is_equal(1)


func test_no_drift_below_minimum_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: DriftInput = _drift_car(runner, 8.0)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	await await_physics_ticks(30)
	assert_bool(car.is_drifting).is_false()


func test_grip_circle_keeps_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: DriftInput = _drift_car(runner, 24.0)
	await await_physics_ticks(3)
	input.steer = 1.0
	await await_physics_ticks(120)
	# T-027 lost about 2% per circle to re-projection; the model keeps it.
	assert_float(car.speed).is_equal_approx(24.0, 0.05)
	assert_float(absf(car.slide_angle_deg)).is_less(8.0)


## T-029: wall contact response.
func test_wall_bounce_needs_a_hard_hit() -> void:
	var slid: Vector3 = Vector3(0, 0, -10.0)
	var n: Vector3 = Vector3.RIGHT
	assert_vector(VehicleController.wall_bounce(slid, 2.0, n, 0.4)).is_equal(slid)
	assert_vector(VehicleController.wall_bounce(slid, 10.0, n, 0.4)).is_equal_approx(
		Vector3(4.0, 0, -10.0),
		Vector3.ONE * 0.001,
	)
	assert_float(VehicleController.wall_approach_deg(Vector3(-1, 0, 0), n)).is_equal_approx(
		90.0,
		0.01,
	)
	var thirty: Vector3 = Vector3(-sin(deg_to_rad(30.0)), 0, -cos(deg_to_rad(30.0)))
	assert_float(VehicleController.wall_approach_deg(thirty, n)).is_equal_approx(30.0, 0.01)


func test_head_on_hit_bounces_back() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	_add_wall(car, Vector3(0, 1.0, WALL_AHEAD_Z), Vector3(20, 3, 1))
	car.velocity = Vector3(0, 0, -car.stats.max_speed)
	await _physics_frames(50)
	assert_int(impacts.size()).is_equal(1)
	# Moving backward, away from the wall, at restitution x impact speed.
	assert_float(car.speed).is_equal_approx(-car.stats.max_speed * car.stats.wall_restitution, 0.3)


func test_thirty_degree_glancing_hit_keeps_most_speed() -> void:
	var impacts: Array[float] = []
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _impact_car(runner, impacts)
	# Wall on the right (x = 10), car heading 30 degrees into it, coasting.
	_add_wall(car, Vector3(10.5, 1.0, -100.0), Vector3(1, 3, 300))
	car.global_position = Vector3(10.0 - 1.2 - 3.0, car.global_position.y, 0.0)
	car.rotation.y = deg_to_rad(-30.0)
	car.velocity = -car.global_basis.z * 24.0
	await _physics_frames(90)
	assert_int(impacts.size()).is_equal(1)
	assert_float(car.speed).is_greater(24.0 * 0.85)
	var heading_into_wall: float = rad_to_deg(asin((-car.global_basis.z).x))
	assert_float(absf(heading_into_wall)).is_less(2.0)


func test_hard_wall_hit_ends_a_drift() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: DriftInput = _drift_car(runner, 20.0)
	# Close enough to hit inside the first quarter of the drift circle.
	_add_wall(car, Vector3(0, 1.0, -9.0), Vector3(80, 3, 1))
	var ended: Array[int] = [0]
	car.drift_ended.connect(
		func() -> void:
			ended[0] += 1,
	)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	await await_physics_ticks(6)
	assert_bool(car.is_drifting).is_true()
	await await_physics_ticks(40)
	# The drift button is still held, but the hit ended the drift.
	assert_int(ended[0]).is_greater_equal(1)


## T-030: ramp launch, air control and landing.
class ThrottleSteerInput:
	extends InputSource

	var throttle: float = 0.0
	var steer: float = 0.0


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": throttle, "steer": steer, "drift": false }


func test_launch_vertical_speed_is_the_slope_climb_rate() -> void:
	var travel: Vector3 = Vector3.BACK # +Z
	var up_slope: Vector3 = Vector3(0, cos(deg_to_rad(15.0)), -sin(deg_to_rad(15.0)))
	assert_float(VehicleController.launch_vertical_speed(travel, Vector3.UP, 24.0)).is_equal(0.0)
	assert_float(VehicleController.launch_vertical_speed(travel, up_slope, 24.0)).is_equal_approx(
		24.0 * sin(deg_to_rad(15.0)),
		0.01,
	)
	# Downhill, or reversing up a slope, gives no launch.
	assert_float(VehicleController.launch_vertical_speed(-travel, up_slope, 24.0)).is_equal(0.0)
	assert_float(VehicleController.launch_vertical_speed(travel, up_slope, -24.0)).is_equal(0.0)


func test_no_throttle_and_reduced_yaw_in_the_air() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input := ThrottleSteerInput.new()
	car.input_source = input
	await runner.simulate_frames(2)
	# No floor: the car is airborne the whole time.
	car.rotation = Vector3.ZERO
	car.velocity = Vector3(0, 0, -10.0)
	input.throttle = 1.0
	input.steer = 1.0
	car.steer_applied = 1.0
	await await_physics_ticks(2)
	var yaw0: float = car.rotation.y
	await await_physics_ticks(30)
	var flat: float = Vector2(car.velocity.x, car.velocity.z).length()
	assert_float(flat).is_equal_approx(10.0, 0.01)
	var air_rate: float = absf(angle_difference(yaw0, car.rotation.y)) / 0.5
	var ground_rate: float = car.stats.steering_rate
	assert_float(air_rate / ground_rate).is_equal_approx(car.stats.air_steer_share, 0.02)


func test_kenney_ramp_launches_and_landing_keeps_speed() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	var car: VehicleController = runner.scene().get_node("TophatCar")
	var input := ThrottleSteerInput.new()
	car.input_source = input
	await runner.simulate_frames(2)
	car.global_position = Vector3(-27.69, 0.6, -45.0)
	car.rotation = Vector3(0, PI, 0)
	car.velocity = Vector3.ZERO
	car.reset_physics_interpolation()
	input.throttle = 1.0
	var apex: float = 0.0
	var air_ticks: int = 0
	var landed_speed: float = -1.0
	var was_air: bool = false
	for i: int in 260:
		await get_tree().physics_frame
		var air: bool = not car.is_on_floor() and car.global_position.y > 1.0
		if air:
			air_ticks += 1
			apex = maxf(apex, car.global_position.y)
		elif was_air and landed_speed < 0.0:
			landed_speed = Vector2(car.velocity.x, car.velocity.z).length()
		was_air = air
	# Takeoff at 4.66 m: the launch adds height (no launch tops out at 4.66).
	assert_float(apex).is_greater(5.3)
	# Hang time close to the 0.6-1.2 s target (measured 1.20 s).
	assert_float(air_ticks / 60.0).is_between(0.9, 1.4)
	assert_float(landed_speed).is_greater(23.5)


## T-031: drift charge tiers and boost.
class BoostInput:
	extends InputSource

	var throttle: float = 1.0
	var steer: float = 0.0
	var drift: bool = false


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": throttle, "steer": steer, "drift": drift }


func _boost_car(runner: GdUnitSceneRunner) -> BoostInput:
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var input := BoostInput.new()
	car.input_source = input
	car.rotation = Vector3.ZERO
	car.velocity = Vector3(0, 0, -22.0)
	return input


func test_drift_tier_thresholds() -> void:
	var times := PackedFloat32Array([0.85, 1.9, 3.0])
	# 0.85 s at 60 Hz is 51 ticks of in-turn charge (5 per tick).
	assert_int(VehicleController.drift_tier_for(254, times, 60)).is_equal(0)
	assert_int(VehicleController.drift_tier_for(255, times, 60)).is_equal(1)
	assert_int(VehicleController.drift_tier_for(570, times, 60)).is_equal(2)
	assert_int(VehicleController.drift_tier_for(900, times, 60)).is_equal(3)


func test_released_drift_pays_out_a_boost_above_top_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: BoostInput = _boost_car(runner)
	var tiers: Array[int] = []
	var boosts: Array[int] = []
	car.drift_tier_reached.connect(
		func(t: int) -> void:
			tiers.append(t),
	)
	car.boost_started.connect(
		func(t: int) -> void:
			boosts.append(t),
	)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	# Just past tier 2 (1.9 s), then release.
	await await_physics_ticks(120)
	assert_array(tiers).contains_exactly([1, 2])
	input.drift = false
	input.steer = 0.0
	await await_physics_ticks(30)
	assert_array(boosts).contains_exactly([2])
	assert_float(car.speed).is_greater(car.stats.max_speed + 2.0)
	assert_float(car.boost_time_left).is_greater(0.0)
	# After the boost, speed eases back to the normal top speed.
	await await_physics_ticks(150)
	assert_float(car.boost_time_left).is_equal(0.0)
	assert_float(car.speed).is_less_equal(car.stats.max_speed + 0.01)


func test_steering_out_charges_slower() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: BoostInput = _boost_car(runner)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	await await_physics_ticks(2)
	input.steer = -1.0
	# 1.0 s steering out reaches only about 40% of the tier 1 charge.
	await await_physics_ticks(60)
	assert_bool(car.is_drifting).is_true()
	assert_int(car.drift_tier).is_equal(0)


func test_too_slow_cancels_the_charge_with_no_boost() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	var input: BoostInput = _boost_car(runner)
	var boosts: Array[int] = []
	car.boost_started.connect(
		func(t: int) -> void:
			boosts.append(t),
	)
	await await_physics_ticks(3)
	input.steer = 1.0
	input.drift = true
	await await_physics_ticks(60)
	assert_int(car.drift_tier).is_equal(1)
	# Brake hard while still holding drift: below 80% of the minimum speed the
	# drift ends with no payout.
	input.throttle = -1.0
	await await_physics_ticks(60)
	assert_bool(car.is_drifting).is_false()
	assert_array(boosts).is_empty()


## T-033: trick boost off ramps.
class TrickInput:
	extends InputSource

	var throttle: float = 1.0
	var drift: bool = false


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": throttle, "steer": 0.0, "drift": drift }


func test_trick_window() -> void:
	# In the window, with a press just now.
	assert_bool(VehicleController.trick_window_open(0.1, 0.0)).is_true()
	# Buffered: pressed 0.15 s before takeoff, checked 0.05 s after it.
	assert_bool(VehicleController.trick_window_open(0.05, 0.2)).is_true()
	# Too early a press, too soon after takeoff, too late.
	assert_bool(VehicleController.trick_window_open(0.1, 0.5)).is_false()
	assert_bool(VehicleController.trick_window_open(0.02, 0.0)).is_false()
	assert_bool(VehicleController.trick_window_open(0.3, 0.0)).is_false()


## Drives the car over the Kenney ramp and taps the trick button `tap_ticks`
## after takeoff (negative: never). Returns [tricks, trick boosts, peak speed].
func _ramp_jump(start_speed: float, tap_ticks: int) -> Array[float]:
	var runner := scene_runner("res://scenes/main.tscn")
	var car: VehicleController = runner.scene().get_node("TophatCar")
	var input := TrickInput.new()
	car.input_source = input
	await runner.simulate_frames(2)
	var tricks: Array[int] = [0]
	var boosts: Array[int] = [0]
	car.trick_performed.connect(
		func() -> void:
			tricks[0] += 1,
	)
	car.boost_started.connect(
		func(t: int) -> void:
			if t == 0:
				boosts[0] += 1,
	)
	car.global_position = Vector3(-27.69, 0.6, -30.0)
	car.rotation = Vector3(0, PI, 0)
	car.velocity = Vector3(0, 0, start_speed)
	car.reset_physics_interpolation()
	input.throttle = 1.0 if start_speed > 15.0 else 0.0
	var takeoff: int = -1
	var peak: float = 0.0
	for i: int in 200:
		await get_tree().physics_frame
		if takeoff < 0 and not car.is_on_floor() and car.velocity.y > 1.0:
			takeoff = i
		if tap_ticks >= 0 and takeoff >= 0:
			input.drift = i >= takeoff + tap_ticks and i < takeoff + tap_ticks + 3
		peak = maxf(peak, car.speed)
	return [float(tricks[0]), float(boosts[0]), peak]


func test_trick_after_takeoff_boosts_on_landing() -> void:
	var result: Array[float] = await _ramp_jump(24.0, 5)
	assert_float(result[0]).is_equal(1.0)
	assert_float(result[1]).is_equal(1.0)
	# Peak speed is the trick boost's: 24 + 6.7 m/s.
	assert_float(result[2]).is_greater(29.0)


func test_no_tap_no_trick() -> void:
	var result: Array[float] = await _ramp_jump(24.0, -1)
	assert_float(result[0]).is_equal(0.0)
	assert_float(result[1]).is_equal(0.0)


func test_too_slow_for_a_trick() -> void:
	# 10 m/s is under half of top speed (12 m/s).
	var result: Array[float] = await _ramp_jump(10.0, 5)
	assert_float(result[0]).is_equal(0.0)
