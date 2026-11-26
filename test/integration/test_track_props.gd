extends GdUnitTestSuite

## T-011: the Kenney greybox props in the test track follow the physics rules
## (collision on layer 1 only, mask 0, uniform scale, no trimesh) and the
## replaced ramp keeps the old ramp's angle and height.

const TRACK: String = "res://scenes/arenas/test_track.tscn"
const OLD_RAMP_SLOPE: float = 0.2679 # tan(15 deg), measured on the CSG ramp (T-011).
const OLD_RAMP_HEIGHT_AT_Z13: float = 3.688 # measured on the CSG ramp (T-011).

var _track: Node3D


func before_test() -> void:
	_track = auto_free((load(TRACK) as PackedScene).instantiate()) as Node3D
	add_child(_track)


func _collect_bodies(node: Node, out: Array[StaticBody3D]) -> void:
	if node is StaticBody3D:
		out.append(node as StaticBody3D)
	for child: Node in node.get_children():
		_collect_bodies(child, out)


func test_props_collide_on_layer_one_only() -> void:
	var bodies: Array[StaticBody3D] = []
	_collect_bodies(_track.get_node("Props"), bodies)
	_collect_bodies(_track.get_node("Ramp"), bodies)
	assert_int(bodies.size()).is_greater(10)
	for body: StaticBody3D in bodies:
		assert_int(body.collision_layer).is_equal(1)
		assert_int(body.collision_mask).is_equal(0)


func test_props_use_box_or_convex_shapes_and_uniform_scale() -> void:
	var bodies: Array[StaticBody3D] = []
	_collect_bodies(_track.get_node("Props"), bodies)
	_collect_bodies(_track.get_node("Ramp"), bodies)
	for body: StaticBody3D in bodies:
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				var shape: Shape3D = (child as CollisionShape3D).shape
				assert_bool(shape is BoxShape3D or shape is ConvexPolygonShape3D).is_true()
				assert_vector((child as CollisionShape3D).scale).is_equal(Vector3.ONE)
		assert_vector(body.scale).is_equal(Vector3.ONE)
		assert_vector((body.get_node("Model") as Node3D).scale).is_equal(Vector3.ONE)


func _ground_height(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = _track.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -5.0, z), 1)
	var hit: Dictionary = space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN


func test_ramp_matches_old_csg_ramp_within_ten_percent() -> void:
	# Physics bodies register on the next physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var low: float = _ground_height(-25.0, -25.0)
	var high: float = _ground_height(-25.0, -13.0)
	assert_bool(is_finite(low) and is_finite(high)).is_true()
	var slope: float = (high - low) / 12.0
	assert_float(slope).is_equal_approx(OLD_RAMP_SLOPE, OLD_RAMP_SLOPE * 0.1)
	assert_float(high).is_equal_approx(OLD_RAMP_HEIGHT_AT_Z13, OLD_RAMP_HEIGHT_AT_Z13 * 0.1)


## T-023: the Kenney ramp model is only a one-sided road deck, but its
## collision is a solid wedge. A visible "Body" fills the wedge, so the car
## never meets an invisible wall under the deck.
func test_ramp_has_a_visible_body_covering_its_collision() -> void:
	var ramp: StaticBody3D = _track.get_node("Ramp") as StaticBody3D
	var body: MeshInstance3D = ramp.get_node("Body") as MeshInstance3D
	assert_object(body).is_not_null()
	assert_bool(body.visible).is_true()
	var prism: PrismMesh = body.mesh as PrismMesh
	assert_object(prism).is_not_null()
	# A right-angle wedge: vertical face at the high end, like the collision.
	assert_float(prism.left_to_right).is_equal(1.0)
	var mesh_box: AABB = body.transform * prism.get_aabb()
	var shape: ConvexPolygonShape3D = (
		(ramp.get_node("CollisionShape3D") as CollisionShape3D).shape as ConvexPolygonShape3D
	)
	var shape_box: AABB = AABB(shape.points[0], Vector3.ZERO)
	for p: Vector3 in shape.points:
		shape_box = shape_box.expand(p)
	# Same footprint, and the top stays just under the deck (within 0.2 m).
	assert_vector(mesh_box.position * Vector3(1, 0, 1)).is_equal_approx(
		shape_box.position * Vector3(1, 0, 1),
		Vector3.ONE * 0.01,
	)
	assert_vector(mesh_box.size * Vector3(1, 0, 1)).is_equal_approx(
		shape_box.size * Vector3(1, 0, 1),
		Vector3.ONE * 0.01,
	)
	assert_float(mesh_box.end.y).is_less(shape_box.end.y)
	assert_float(shape_box.end.y - mesh_box.end.y).is_less(0.2)
	assert_float(mesh_box.position.y).is_less_equal(0.0)
	# The high end (+Z) is the vertical face of both.
	assert_float(mesh_box.end.z).is_equal_approx(shape_box.end.z, 0.01)
