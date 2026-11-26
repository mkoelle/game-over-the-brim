extends GdUnitTestSuite

## T-034: speed and boost FOV, boost pull-back, and the drift camera heading.

const MAIN_SCENE: String = "res://scenes/main.tscn"


## The start-of-race fly-in (T-036) would move the camera for the first 2 s.
## These tests check the chase camera itself, so they turn it off.
var _saved_intro: bool = true


func before_test() -> void:
	_saved_intro = GameConfig.play_intro
	GameConfig.play_intro = false


func after_test() -> void:
	GameConfig.play_intro = _saved_intro


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_fov_target_adds_speed_and_boost() -> void:
	assert_float(ChaseCamSpeedFx.fov_for(75.0, 4.0, 0.0, 0.0)).is_equal(75.0)
	assert_float(ChaseCamSpeedFx.fov_for(75.0, 4.0, 1.0, 0.0)).is_equal(79.0)
	assert_float(ChaseCamSpeedFx.fov_for(75.0, 4.0, 2.0, 12.0)).is_equal(91.0)


func test_approach_rises_faster_than_it_falls() -> void:
	var dt: float = 1.0 / 60.0
	var up: float = ChaseCamSpeedFx.approach(75.0, 85.0, dt, 0.15, 0.5) - 75.0
	var down: float = 85.0 - ChaseCamSpeedFx.approach(85.0, 75.0, dt, 0.15, 0.5)
	assert_float(up).is_greater(down * 2.0)


func test_boost_widens_fov_and_pulls_back() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	var camera: Camera3D = main.get_node("GameCamera")
	var follow: PhantomCamera3D = main.find_child("CarFollowCam", true, false)
	await runner.simulate_frames(2)
	var base_spring: float = follow.spring_length
	assert_float(camera.fov).is_equal_approx(75.0, 0.5)
	# A long clear run north to south, coasting at top speed.
	car.global_position = Vector3(20.0, 0.6, 45.0)
	car.rotation = Vector3.ZERO
	car.velocity = -car.global_basis.z * car.stats.max_speed
	car.reset_physics_interpolation()
	await _ticks(60)
	# Top speed alone: 75 + 4.
	assert_float(camera.fov).is_equal_approx(79.0, 0.6)
	# Tier 2 boost for 0.5 s, still on the clear run: +10 (96% of it after
	# three 0.15 s attack time constants), and the camera moves toward 0.45 m
	# further back (86% after two 0.25 s time constants).
	car.boost_tier = 2
	car.boost_time_left = 3.0
	await _ticks(30)
	assert_float(camera.fov).is_equal_approx(89.0, 0.7)
	assert_float(follow.spring_length - base_spring).is_between(0.33, 0.46)


func test_drift_camera_looks_along_the_travel_direction() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	var camera: Camera3D = main.get_node("GameCamera")
	await runner.simulate_frames(2)
	car.global_position = Vector3(30.0, 0.6, 40.0)
	car.rotation = Vector3.ZERO
	car.velocity = Vector3(0, 0, -22.0)
	car.reset_physics_interpolation()
	runner.simulate_action_press("throttle@kb")
	await _ticks(10)
	runner.simulate_action_press("steer_left@kb")
	runner.simulate_action_press("drift@kb")
	await _ticks(70)
	assert_bool(car.is_drifting).is_true()
	var car_back: Vector3 = car.global_basis.z
	var cam_back: Vector3 = camera.global_basis.z
	var offset: float = rad_to_deg(
		angle_difference(atan2(car_back.x, car_back.z), atan2(cam_back.x, cam_back.z))
	)
	# The camera sits close to the travel direction, which is the slide angle
	# off the body.
	assert_float(absf(offset - car.slide_angle_deg)).is_less(10.0)
	runner.simulate_action_release("drift@kb")
	runner.simulate_action_release("steer_left@kb")
	runner.simulate_action_release("throttle@kb")
