extends GdUnitTestSuite

## T-021: Ramp2 is a solid wedge. Its top surface matches the old tilted
## slab (30 degrees, 8 m high), and nothing can drive under its high end.
## Under the old slab the car wedged in the gap, the camera's collision
## start point ended up inside the slab, and the camera popped through it.

const TRACK: String = "res://scenes/arenas/test_track.tscn"
const MAIN_SCENE: String = "res://scenes/main.tscn"
const RAMP_X: float = -27.688313
const LOW_Z: float = 1.5521212 # where the top surface meets the floor
const HIGH_Z: float = 15.408530 # the top edge and the vertical back face
const RAMP_DEG: float = 30.0

var _track: Node3D


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func _add_track() -> PhysicsDirectSpaceState3D:
	_track = auto_free((load(TRACK) as PackedScene).instantiate()) as Node3D
	add_child(_track)
	# CSG collision registers on a later physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	return _track.get_world_3d().direct_space_state


func test_top_surface_is_thirty_degrees_and_eight_metres_high() -> void:
	var space: PhysicsDirectSpaceState3D = await _add_track()
	var mid_z: float = (LOW_Z + HIGH_Z) * 0.5
	var hit: Dictionary = _ray(space, Vector3(RAMP_X, 20.0, mid_z), Vector3(RAMP_X, -1.0, mid_z))
	assert_bool(hit.is_empty()).is_false()
	assert_float(float(hit.position.y)).is_equal_approx(4.0, 0.05)
	var normal: Vector3 = hit.normal
	assert_float(rad_to_deg(normal.angle_to(Vector3.UP))).is_equal_approx(RAMP_DEG, 0.1)
	var top: Dictionary = _ray(
		space,
		Vector3(RAMP_X, 20.0, HIGH_Z - 0.05),
		Vector3(RAMP_X, -1.0, HIGH_Z - 0.05),
	)
	assert_float(float(top.position.y)).is_equal_approx(8.0, 0.05)


func test_no_gap_under_the_high_end() -> void:
	var space: PhysicsDirectSpaceState3D = await _add_track()
	# A car-height ray from behind the ramp must stop at the back face, not
	# travel under the ramp. The old slab let it reach z of about 4.
	for height: float in [0.5, 1.0, 1.5, 2.5]:
		var hit: Dictionary = _ray(
			space,
			Vector3(RAMP_X, height, 30.0),
			Vector3(RAMP_X, height, LOW_Z),
		)
		assert_bool(hit.is_empty()).is_false()
		assert_float(float(hit.position.z)).is_equal_approx(HIGH_Z, 0.05)


func test_reversing_into_the_back_face_keeps_the_car_in_view() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	var camera: Camera3D = main.get_node("GameCamera")
	await runner.simulate_frames(2)
	# Face +Z, 13 m behind the back face, then hold brake to reverse into it.
	car.global_position = Vector3(RAMP_X, 0.6, 28.0)
	car.rotation = Vector3(0.0, PI, 0.0)
	car.reset_physics_interpolation()
	await runner.simulate_frames(30)
	runner.simulate_action_press("brake@kb")
	var space: PhysicsDirectSpaceState3D = car.get_world_3d().direct_space_state
	var blocked_frames: int = 0
	var max_step: float = 0.0
	var prev: Vector3 = camera.global_position
	for i: int in 180:
		await runner.simulate_frames(1)
		var query := PhysicsRayQueryParameters3D.create(
			car.global_position + Vector3.UP,
			camera.global_position,
			1,
			[car.get_rid()],
		)
		if not space.intersect_ray(query).is_empty():
			blocked_frames += 1
		max_step = maxf(max_step, camera.global_position.distance_to(prev))
		prev = camera.global_position
	runner.simulate_action_release("brake@kb")
	assert_int(blocked_frames).is_equal(0)
	assert_float(max_step).is_less(1.0)
	# Stopped by the back face, never under the ramp.
	assert_float(car.global_position.z).is_greater(HIGH_Z)
