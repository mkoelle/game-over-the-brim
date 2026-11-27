extends GdUnitTestSuite

## T-024: the car cannot leave the test track, and if it ever does, it is put
## back at its spawn pose. FC-1 found that a right turn off Ramp2 carried the
## car over the 3 m west wall at about 6 m high, into an endless fall.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const TRACK: String = "res://scenes/arenas/test_track.tscn"
## Highest car origin measured off the current ramps: 5.89 m off the Kenney
## ramp (T-037; 5.77 m in T-030). It was 8.64 m off the old Ramp2 (T-024).
const MAX_JUMP_APEX: float = 5.89
const BOUND: float = 49.0


func _await_physics_ticks(runner: GdUnitSceneRunner, ticks: int) -> void:
	var start: int = Engine.get_physics_frames()
	while Engine.get_physics_frames() - start < ticks:
		await runner.simulate_frames(1)


func test_boundary_walls_are_taller_than_any_jump() -> void:
	var track: Node3D = auto_free((load(TRACK) as PackedScene).instantiate()) as Node3D
	var walls: Array[Node] = track.get_node("Walls").get_children()
	assert_int(walls.size()).is_equal(4)
	for wall: Node in walls:
		var box: CSGBox3D = wall as CSGBox3D
		var top: float = box.position.y + box.size.y * 0.5
		# Car origin apex + half the car + 2 m of margin.
		assert_float(top).is_greater_equal(MAX_JUMP_APEX + 0.5 + 2.0)
		assert_float(box.position.y - box.size.y * 0.5).is_less_equal(0.0)


func test_airborne_car_heading_for_the_west_wall_stays_inside() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var car: VehicleController = runner.scene().get_node("TophatCar")
	await runner.simulate_frames(2)
	var resets: Array[int] = [0]
	var reset: OutOfBoundsReset = runner.scene().get_node("OutOfBoundsReset")
	reset.car_reset.connect(
		func(_c: VehicleController) -> void:
			resets[0] += 1,
	)
	# Just past Ramp2's top edge, 9 m up, flying west at top speed: the state
	# a right turn off the ramp produces.
	var heading: Vector3 = Vector3(-24.0, 0.0, 8.0).normalized()
	car.global_position = Vector3(-27.69, 9.2, 16.0)
	car.look_at(car.global_position + heading, Vector3.UP)
	car.velocity = heading * car.stats.max_speed
	car.reset_physics_interpolation()
	var start: int = Engine.get_physics_frames()
	var max_out: float = 0.0
	while Engine.get_physics_frames() - start < 150:
		await runner.simulate_frames(1)
		var p: Vector3 = car.global_position
		max_out = maxf(max_out, maxf(absf(p.x), absf(p.z)))
	# It never crossed a boundary wall, and never needed the reset.
	assert_float(max_out).is_less(BOUND)
	assert_int(resets[0]).is_equal(0)
	assert_float(car.global_position.y).is_greater(-1.0)


func test_car_below_the_level_is_reset_to_spawn() -> void:
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	await runner.simulate_frames(2)
	var reset: OutOfBoundsReset = main.get_node("OutOfBoundsReset")
	assert_object(reset).is_not_null()
	var spawn: Vector3 = car.global_position
	var resets: Array[VehicleController] = []
	reset.car_reset.connect(
		func(c: VehicleController) -> void:
			resets.append(c),
	)
	car.global_position = Vector3(-60.0, reset.kill_height - 5.0, 20.0)
	car.velocity = Vector3(0.0, -40.0, 0.0)
	await _await_physics_ticks(runner, 3)
	assert_int(resets.size()).is_equal(1)
	assert_object(resets[0]).is_same(car)
	assert_float(car.global_position.distance_to(spawn)).is_less(0.5)
	assert_float(car.velocity.length()).is_less(1.0)
