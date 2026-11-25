extends GdUnitTestSuite

## T-008 coverage for the impact shake wiring in main.tscn: the car's local
## `impacted` signal reaches the ImpactShake emitter, the emitter's noise
## layer reaches CarFollowCam, and only hits above the minimum speed shake.

const MAIN_SCENE := "res://scenes/main.tscn"

## Just inside the east boundary wall, whose inner face is at x = 49.
const NEAR_EAST_WALL := Vector3(47.5, 0.5, 0.0)


func _follow_cam(main: Node) -> PhantomCamera3D:
	return main.find_child("CarFollowCam", true, false) as PhantomCamera3D


## Places the car facing the east wall, lets it settle, then sends it at
## the wall at `speed` with no input. Returns as soon as the car reports
## its first hit, with every `impacted` speed so far.
##
## The settle outlasts the camera's 1 s tween-on-load, so afterwards the
## camera sits exactly on CarFollowCam's output unless noise moves it.
func _drive_into_east_wall(runner: GdUnitSceneRunner, speed: float) -> Array[float]:
	var car: VehicleController = runner.scene().get_node("TophatCar")
	var impacts: Array[float] = []
	car.impacted.connect(
		func(impact_speed: float) -> void:
			impacts.append(impact_speed),
	)
	car.global_position = NEAR_EAST_WALL
	car.global_rotation = Vector3(0, deg_to_rad(-90.0), 0)
	car.velocity = Vector3.ZERO
	for i: int in 80:
		await get_tree().physics_frame
	assert_float(await _max_shake_degrees(runner, 3)).is_less(0.001)
	car.velocity = -car.global_basis.z * speed
	for i: int in 40:
		await get_tree().physics_frame
		if not impacts.is_empty():
			break
	return impacts


## Largest camera rotation away from CarFollowCam's own (pre-noise) output
## over the next `frames` rendered frames, in degrees.
func _max_shake_degrees(runner: GdUnitSceneRunner, frames: int) -> float:
	var main: Node = runner.scene()
	var camera: Camera3D = main.get_node("GameCamera")
	var pcam := _follow_cam(main)
	var max_degrees: float = 0.0
	for i: int in frames:
		await runner.simulate_frames(1)
		var offset: Basis = pcam.get_transform_output().basis.inverse() * camera.global_basis
		max_degrees = maxf(max_degrees, rad_to_deg(offset.get_rotation_quaternion().get_angle()))
	return max_degrees


func test_emitter_layer_reaches_the_follow_cam() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var emitter: PhantomCameraNoiseEmitter3D = runner.scene().get_node("ImpactShake")
	var cam_layer: int = _follow_cam(runner.scene()).noise_emitter_layer

	assert_int(emitter.noise_emitter_layer & cam_layer).is_not_zero()
	assert_bool(emitter.noise.rotational_noise).is_true()
	assert_bool(emitter.noise.positional_noise).is_false()


func test_full_speed_wall_hit_shakes_the_camera() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var emitter: PhantomCameraNoiseEmitter3D = runner.scene().get_node("ImpactShake")

	var impacts := await _drive_into_east_wall(runner, 24.0)

	assert_int(impacts.size()).is_equal(1)
	assert_bool(emitter.is_emitting()).is_true()
	assert_float(await _max_shake_degrees(runner, 10)).is_greater(0.1)


func test_gentle_bump_does_not_shake_the_camera() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var emitter: PhantomCameraNoiseEmitter3D = runner.scene().get_node("ImpactShake")

	var impacts := await _drive_into_east_wall(runner, 2.0)

	assert_int(impacts.size()).is_equal(1)
	assert_float(impacts[0]).is_less(3.0)
	assert_bool(emitter.is_emitting()).is_false()
	assert_float(await _max_shake_degrees(runner, 10)).is_less(0.001)
