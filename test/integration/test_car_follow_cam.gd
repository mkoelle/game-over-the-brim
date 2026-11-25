extends GdUnitTestSuite

## T-005 coverage for the Phantom Camera chase rig in main.tscn. CarFollowCam
## follows the car (assigned in main.gd), collides with the Track layer only,
## and turns with the car's heading through ChaseCamYawDriver.

const MAIN_SCENE := "res://scenes/main.tscn"
const TRACK_LAYER_MASK: int = 1


## Third Person mode reparents the PhantomCamera3D under its own ShapeCast3D
## at runtime, so look it up by name rather than by a fixed path.
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
