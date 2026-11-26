extends GdUnitTestSuite

## T-005 coverage for the Phantom Camera chase rig in main.tscn. CarFollowCam
## follows the car (assigned in main.gd), collides with the Track layer only,
## and turns with the car's heading through ChaseCamYawDriver.

const MAIN_SCENE := "res://scenes/main.tscn"
const TRACK_LAYER_MASK: int = 1


## Third Person mode reparents the PhantomCamera3D under its own ShapeCast3D
## at runtime, so look it up by name rather than by a fixed path.

## The start-of-race fly-in (T-036) would move the camera for the first 2 s.
## These tests check the chase camera itself, so they turn it off.
var _saved_intro: bool = true


func before_test() -> void:
	_saved_intro = GameConfig.play_intro
	GameConfig.play_intro = false


func after_test() -> void:
	GameConfig.play_intro = _saved_intro


func _follow_cam(main: Node) -> PhantomCamera3D:
	return main.find_child("CarFollowCam", true, false) as PhantomCamera3D


func test_follow_cam_follows_car_in_third_person() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	await runner.simulate_frames(2)

	var cam: PhantomCamera3D = _follow_cam(main)
	assert_object(cam).is_not_null()
	assert_object(cam.follow_target).is_same(main.get_node("TophatCar"))
	assert_int(cam.follow_mode).is_equal(PhantomCamera3D.FollowMode.THIRD_PERSON)
	assert_int(cam.priority).is_equal(10)


func test_follow_cam_collides_with_track_layer_only() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var cam: PhantomCamera3D = _follow_cam(runner.scene())

	assert_int(cam.collision_mask).is_equal(TRACK_LAYER_MASK)


func test_camera_turns_with_car_heading_and_stays_behind() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	var camera: Camera3D = main.get_node("GameCamera")

	car.rotation.y = PI / 2.0
	await runner.simulate_frames(60, 20)

	var car_back: Vector3 = car.global_basis.z
	var cam_back: Vector3 = camera.global_basis.z
	var yaw_error: float = angle_difference(
		atan2(car_back.x, car_back.z),
		atan2(cam_back.x, cam_back.z),
	)
	assert_float(absf(rad_to_deg(yaw_error))).is_less(3.0)
	assert_float((camera.global_position - car.global_position).dot(car_back)).is_greater(3.0)


## T-020: the car moves at 60 Hz physics, but displays such as 120 Hz ProMotion
## render more often. Interpolation must be on, so the car is drawn between
## ticks. The camera is moved in _process, so it must not be interpolated.
func test_physics_interpolation_on_and_camera_not_interpolated() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	await runner.simulate_frames(2)

	assert_bool(ProjectSettings.get_setting("physics/common/physics_interpolation")).is_true()
	assert_bool(main.get_tree().physics_interpolation).is_true()
	var camera: Camera3D = main.get_node("GameCamera")
	assert_int(camera.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	assert_bool(camera.is_physics_interpolated()).is_false()
	assert_bool(main.get_node("TophatCar").is_physics_interpolated()).is_true()


## T-036: the intro vantage is behind, above and right of the car, looking at
## it.
func test_intro_vantage_is_behind_above_and_looking_at_the_car() -> void:
	var car := Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -20))
	var vantage: Transform3D = Main.intro_vantage(car)
	var offset: Vector3 = vantage.origin - car.origin
	assert_float(offset.dot(car.basis.z)).is_equal_approx(Main.INTRO_BACK, 0.01)
	assert_float(offset.y).is_equal_approx(Main.INTRO_UP, 0.01)
	assert_float(offset.dot(car.basis.x)).is_equal_approx(Main.INTRO_SIDE, 0.01)
	var view: Vector3 = -vantage.basis.z
	var to_car: Vector3 = (car.origin + Vector3.UP - vantage.origin).normalized()
	assert_float(view.angle_to(to_car)).is_less(0.01)


func test_intro_flies_from_the_vantage_to_the_chase_camera() -> void:
	GameConfig.play_intro = true
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	var camera: Camera3D = main.get_node("GameCamera")
	await runner.simulate_frames(3)
	var start: float = camera.global_position.distance_to(car.global_position)
	# Hold 0.4 s, then a 1.8 s fly to the chase camera.
	await runner.simulate_frames(160, 20)
	var end: float = camera.global_position.distance_to(car.global_position)
	assert_float(start).is_greater(20.0)
	assert_float(end).is_less(6.0)
