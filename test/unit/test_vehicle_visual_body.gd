extends GdUnitTestSuite

## T-032: the visual body rolls, tilts, hops and shows the drift tier, while
## the physics body and its collision stay as they were.

const TOPHAT_CAR_SCENE := "res://scenes/vehicles/tophat_car.tscn"


class DriftInput:
	extends InputSource

	var steer: float = 0.0
	var drift: bool = false


	func get_input() -> Dictionary[String, Variant]:
		return { "throttle": 1.0, "steer": steer, "drift": drift }


func _add_floor_under(car: Node3D) -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(400, 1, 400)
	floor_body.add_child(shape)
	floor_body.position = car.global_position + Vector3(0, -1.0, 0)
	car.get_parent().add_child(floor_body)


func test_roll_is_into_the_turn_and_capped() -> void:
	var cap: float = deg_to_rad(VehicleVisualBody.MAX_ROLL_DEG)
	assert_float(VehicleVisualBody.target_roll(1.0, 1.0)).is_equal_approx(-cap, 0.0001)
	assert_float(VehicleVisualBody.target_roll(-1.0, 2.0)).is_equal_approx(cap, 0.0001)
	assert_float(VehicleVisualBody.target_roll(1.0, 0.0)).is_equal(0.0)


func test_hop_is_a_parabola_peaking_mid_hop() -> void:
	var half: float = VehicleVisualBody.HOP_TIME * 0.5
	assert_float(VehicleVisualBody.hop_offset(half)).is_equal_approx(
		VehicleVisualBody.HOP_HEIGHT,
		0.0001,
	)
	assert_float(VehicleVisualBody.hop_offset(0.0)).is_equal(0.0)
	assert_float(VehicleVisualBody.hop_offset(VehicleVisualBody.HOP_TIME)).is_equal(0.0)


func test_tilt_to_matches_the_surface_angle() -> void:
	assert_bool(VehicleVisualBody.tilt_to(Vector3.UP).is_equal_approx(Basis.IDENTITY)).is_true()
	var slope: Vector3 = Vector3(0, cos(deg_to_rad(15.0)), -sin(deg_to_rad(15.0)))
	var up: Vector3 = VehicleVisualBody.tilt_to(slope) * Vector3.UP
	assert_vector(up).is_equal_approx(slope, Vector3.ONE * 0.0001)


func test_mesh_moved_under_visual_body_and_collision_unchanged() -> void:
	var car: Node = auto_free((load(TOPHAT_CAR_SCENE) as PackedScene).instantiate())
	assert_object(car.get_node_or_null("VisualBody/MeshInstance3D")).is_not_null()
	assert_object(car.get_node_or_null("MeshInstance3D")).is_null()
	var shape: CollisionShape3D = car.get_node("CollisionShape3D")
	assert_vector((shape.shape as BoxShape3D).size).is_equal(Vector3(1, 1, 2))


func test_each_car_gets_its_own_tint_material() -> void:
	var runner_a := scene_runner(TOPHAT_CAR_SCENE)
	var runner_b := scene_runner(TOPHAT_CAR_SCENE)
	var mesh_a: MeshInstance3D = runner_a.scene().get_node("VisualBody/MeshInstance3D")
	var mesh_b: MeshInstance3D = runner_b.scene().get_node("VisualBody/MeshInstance3D")
	await runner_a.simulate_frames(1)
	assert_object(mesh_a.material_override).is_not_same(mesh_b.material_override)


func test_drift_tier_shows_its_colour_and_sparks() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var input := DriftInput.new()
	car.input_source = input
	car.velocity = Vector3(0, 0, -22.0)
	var body: VehicleVisualBody = car.get_node("VisualBody")
	for i: int in 3:
		await get_tree().physics_frame
	input.steer = 1.0
	input.drift = true
	var max_hop: float = 0.0
	for i: int in 70:
		await get_tree().physics_frame
		max_hop = maxf(max_hop, body.position.y)
	assert_int(car.drift_tier).is_equal(1)
	assert_bool(body.tint().is_equal_approx(VehicleVisualBody.TIER_COLORS[0])).is_true()
	assert_bool(body.sparks_emitting()).is_true()
	assert_float(max_hop).is_equal_approx(VehicleVisualBody.HOP_HEIGHT, 0.02)


func test_trick_spin_is_one_full_turn() -> void:
	var spin_time: float = VehicleVisualBody.TRICK_SPIN_TIME
	assert_float(VehicleVisualBody.trick_spin(spin_time)).is_equal(0.0)
	assert_float(VehicleVisualBody.trick_spin(spin_time * 0.5)).is_equal_approx(PI, 0.001)
	assert_float(VehicleVisualBody.trick_spin(0.0)).is_equal(0.0)


func test_gauge_pips_fill_by_segment() -> void:
	assert_float(VehicleVisualBody.pip_fill(0, 1.5, 0.0)).is_equal(1.0)
	assert_float(VehicleVisualBody.pip_fill(1, 1.5, 0.0)).is_equal(0.5)
	assert_float(VehicleVisualBody.pip_fill(2, 1.5, 0.0)).is_equal(0.0)
	assert_float(VehicleVisualBody.pip_fill(3, 3.0, 0.4)).is_equal(0.4)
	var car: Node = auto_free((load(TOPHAT_CAR_SCENE) as PackedScene).instantiate())
	add_child(car)
	for i: int in 4:
		assert_object(car.get_node_or_null("VisualBody/GaugePip%d" % i)).is_not_null()
