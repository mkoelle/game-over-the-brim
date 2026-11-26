extends GdUnitTestSuite

## T-035: the tuning circuit, the second and larger test map, and map
## selection in main.tscn.

const CIRCUIT: String = "res://scenes/arenas/tuning_circuit.tscn"
const MAIN_SCENE: String = "res://scenes/main.tscn"
## Highest car origin off the kicker, measured by the T-035 autopilot probe.
const KICKER_APEX: float = 3.70

var _saved_track: int = 0


func before_test() -> void:
	_saved_track = GameConfig.track_index


func after_test() -> void:
	GameConfig.track_index = _saved_track


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_circuit_has_its_parts() -> void:
	var track: Node = auto_free((load(CIRCUIT) as PackedScene).instantiate())
	for node_name: String in [
		"Centerline",
		"Road",
		"CurbLeft",
		"CurbRight",
		"BarrierLeft",
		"BarrierRight",
		"Kicker",
		"JumpWallWest",
		"JumpWallEast",
		"Spawn",
		"Ground",
		"PerimeterNorth",
		"PerimeterSouth",
		"PerimeterEast",
		"PerimeterWest",
		"DirectionalLight3D",
		"WorldEnvironment",
	]:
		assert_object(track.get_node_or_null(node_name)).is_not_null()
	for node_name: String in ["Road", "BarrierLeft", "BarrierRight", "Kicker"]:
		assert_bool((track.get_node(node_name) as CSGShape3D).use_collision).is_true()


func test_centerline_is_a_clean_closed_loop() -> void:
	var track: Node = auto_free((load(CIRCUIT) as PackedScene).instantiate())
	var curve: Curve3D = (track.get_node("Centerline") as Path3D).curve
	var total: float = 0.0
	var shortest: float = INF
	var longest: float = 0.0
	for i: int in curve.point_count:
		var d: float = curve.get_point_position(i).distance_to(
			curve.get_point_position((i + 1) % curve.point_count)
		)
		total += d
		shortest = minf(shortest, d)
		longest = maxf(longest, d)
	assert_float(total).is_between(565.0, 577.0)
	# No repeated points (a zero direction breaks the extrusion), no big gaps.
	assert_float(shortest).is_greater(0.01)
	assert_float(longest).is_less(2.6)


func test_jump_walls_are_taller_than_the_jump() -> void:
	var track: Node = auto_free((load(CIRCUIT) as PackedScene).instantiate())
	var barrier_top: float = 1.2
	var barrier_inner: float = 8.8
	for node_name: String in ["JumpWallWest", "JumpWallEast"]:
		var wall: CSGBox3D = track.get_node(node_name)
		var top: float = wall.position.y + wall.size.y * 0.5
		var bottom: float = wall.position.y - wall.size.y * 0.5
		# Track-geometry rule 4: apex + half the car + 2 m.
		assert_float(top).is_greater_equal(KICKER_APEX + 0.5 + 2.0)
		# It sits on the barrier with no gap, and none of its faces coincide
		# with the barrier's, so nothing z-fights (T-036).
		assert_float(bottom).is_less(barrier_top)
		assert_float(bottom).is_greater(barrier_top - 0.05)
		var inner: float = absf(wall.position.x - 70.0) - wall.size.x * 0.5
		assert_float(inner - barrier_inner).is_greater_equal(0.01)


func test_main_swaps_to_the_circuit_and_spawns_on_the_road() -> void:
	GameConfig.track_index = GameConfig.TRACK_NAMES.find("circuit")
	var runner := scene_runner(MAIN_SCENE)
	var main: Node = runner.scene()
	var car: VehicleController = main.get_node("TophatCar")
	assert_object(main.get_node_or_null("TestTrack")).is_null()
	assert_object(main.get_node_or_null("TuningCircuit")).is_not_null()
	var spawn: Marker3D = main.get_node("TuningCircuit/Spawn")
	assert_float(car.global_position.distance_to(spawn.global_position)).is_less(0.2)
	await _ticks(30)
	assert_bool(car.is_on_floor()).is_true()
	# Full throttle up the start straight for 3 s: the road holds the car the
	# whole way, with no wall contact.
	var impacts: Array[int] = [0]
	car.impacted.connect(
		func(_s: float) -> void:
			impacts[0] += 1,
	)
	var start_z: float = car.global_position.z
	runner.simulate_action_press("throttle@kb")
	var off_floor: int = 0
	for i: int in 180:
		await get_tree().physics_frame
		if not car.is_on_floor():
			off_floor += 1
	runner.simulate_action_release("throttle@kb")
	assert_int(off_floor).is_less(3)
	assert_int(impacts[0]).is_equal(0)
	assert_float(start_z - car.global_position.z).is_greater(50.0)


func test_sandbox_stays_the_default() -> void:
	GameConfig.track_index = 0
	var runner := scene_runner(MAIN_SCENE)
	assert_object(runner.scene().get_node_or_null("TestTrack")).is_not_null()
