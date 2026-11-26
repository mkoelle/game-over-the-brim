extends SceneTree
## Builds scenes/arenas/tuning_circuit.tscn, the second, larger test map
## (T-035, docs/design/test-tracks.md). Run with `task track:circuit`.
##
## The lap is a polygon of corner points, and each corner is rounded with an
## arc of its own radius, so the loop always closes. The centreline is a
## Path3D. The road, curbs and barriers are CSGPolygon3D cross-sections
## extruded along it, so the layout stays editable in the editor by moving
## Path3D points. Re-running this tool overwrites those edits: change CORNERS
## here instead.

const OUT: String = "res://scenes/arenas/tuning_circuit.tscn"

## Corner points (x, z) in metres, in driving order, with the fillet radius.
## Driving starts north (-Z) up the start straight at x = 0.
##   hairpin: two R10 corners 40 m apart (a U-turn). The car's full-lock
##   radius at top speed is 17 m (T-027), so this one needs a brake or a drift.
##   An R18 hairpin was flat-out in the autopilot probe.
##   chicane: two R30 corners at 45 degrees
##   back straight with the kicker jump
##   sweeper: two R35 corners 70 m apart (a semicircle)
const CORNERS: Array[Array] = [
	[Vector2(0.0, -110.0), 10.0],
	[Vector2(40.0, -110.0), 10.0],
	[Vector2(40.0, -50.0), 30.0],
	[Vector2(70.0, -20.0), 30.0],
	[Vector2(70.0, 135.0), 35.0],
	[Vector2(0.0, 135.0), 35.0],
]

## Sample spacing along the centreline, in metres.
const STEP: float = 2.0

## Slice spacing of the extrusions, in metres. At 2 m the outer barrier of
## the R10 hairpin showed 3.9 m facets; at 1 m they are under 2 m.
const CSG_INTERVAL: float = 1.0

## Cross-sections (lateral x, height y) in metres. The road top sits 2 cm
## above the ground, so it never z-fights it.
const ROAD_HALF_WIDTH: float = 7.0
const CURB_WIDTH: float = 0.8
const BARRIER_INNER: float = 8.8
const BARRIER_THICKNESS: float = 0.5
const BARRIER_HEIGHT: float = 1.2
const ROAD_TOP: float = 0.02
const CURB_TOP: float = 0.04
const BASE: float = -0.3

## Kicker jump on the back straight (x = 70, heading +Z): 15 degrees, 2 m,
## 8 m wide, so drivers can jump it or go round. Walls beside the landing are
## taller than the jump apex plus 2 m (track-geometry rule 4).
const KICKER_LOW_Z: float = 20.0
const KICKER_HEIGHT: float = 2.0
const KICKER_DEG: float = 15.0
const KICKER_WIDTH: float = 8.0
const JUMP_WALL_HEIGHT: float = 6.5
const JUMP_WALL_SETBACK: float = 0.05
const JUMP_WALL_OVERLAP: float = 0.01
const JUMP_WALL_FROM_Z: float = 12.0
const JUMP_WALL_TO_Z: float = 78.0

## Start line, and the spawn just behind it.
const START_Z: float = 60.0
const SPAWN: Vector3 = Vector3(0.0, 0.6, 70.0)

## Ground and perimeter.
const GROUND_CENTER: Vector2 = Vector2(35.0, 12.5)
const GROUND_SIZE: Vector2 = Vector2(320.0, 420.0)
const PERIMETER_HEIGHT: float = 12.0

var _root: Node3D


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "TuningCircuit"
	var points: PackedVector2Array = centerline(CORNERS, STEP)
	var path := Path3D.new()
	path.name = "Centerline"
	var curve := Curve3D.new()
	for p: Vector2 in points:
		curve.add_point(Vector3(p.x, 0.0, p.y))
	path.curve = curve
	_add(path)
	print(
		"build_tuning_circuit: centreline %.1f m, %d points" % [loop_length(points), points.size()]
	)

	var asphalt: StandardMaterial3D = _mat(Color(0.22, 0.22, 0.24))
	var curb: StandardMaterial3D = _mat(Color(0.85, 0.15, 0.15))
	var barrier: StandardMaterial3D = _mat(Color(0.93, 0.93, 0.9))
	_extrude("Road", [-ROAD_HALF_WIDTH, BASE, ROAD_HALF_WIDTH, ROAD_TOP], asphalt)
	var curb_out: float = ROAD_HALF_WIDTH + CURB_WIDTH
	_extrude("CurbLeft", [-curb_out, BASE, -ROAD_HALF_WIDTH, CURB_TOP], curb)
	_extrude("CurbRight", [ROAD_HALF_WIDTH, BASE, curb_out, CURB_TOP], curb)
	var outer: float = BARRIER_INNER + BARRIER_THICKNESS
	_extrude("BarrierLeft", [-outer, BASE, -BARRIER_INNER, BARRIER_HEIGHT], barrier)
	_extrude("BarrierRight", [BARRIER_INNER, BASE, outer, BARRIER_HEIGHT], barrier)

	_add_lighting()
	_add_ground()
	_add_kicker()
	_add_jump_walls()
	_add_start_line()
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = SPAWN
	_add(spawn)

	# Keep the scene's UID across regenerations, so references stay valid and
	# a regeneration does not churn it.
	var uid: int = _existing_uid(OUT)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	var packed := PackedScene.new()
	var err: Error = packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	if err == OK:
		err = ResourceSaver.set_uid(OUT, uid)
	print("build_tuning_circuit: ", "wrote " + OUT if err == OK else "FAILED (%d)" % err)
	_root.free()
	quit(0 if err == OK else 1)


## Centreline samples for a closed polygon of [point, radius] corners: a
## straight between corners and an arc at each corner. Pure, so it is tested.
static func centerline(corners: Array[Array], step: float) -> PackedVector2Array:
	var count: int = corners.size()
	var out := PackedVector2Array()
	for i: int in count:
		var prev: Vector2 = corners[(i - 1 + count) % count][0]
		var here: Vector2 = corners[i][0]
		var next: Vector2 = corners[(i + 1) % count][0]
		var radius: float = corners[i][1]
		var d_in: Vector2 = (here - prev).normalized()
		var d_out: Vector2 = (next - here).normalized()
		var turn: float = d_in.angle_to(d_out)
		var tangent: float = radius * tan(absf(turn) * 0.5)
		var arc_start: Vector2 = here - d_in * tangent
		var arc_end: Vector2 = here + d_out * tangent
		# Straight from the previous corner's arc end to this arc start.
		var prev_here: Vector2 = prev
		var prev_prev: Vector2 = corners[(i - 2 + count) % count][0]
		var prev_radius: float = corners[(i - 1 + count) % count][1]
		var prev_turn: float = (prev - prev_prev).normalized().angle_to(d_in)
		var straight_start: Vector2 = prev_here + d_in * prev_radius * tan(absf(prev_turn) * 0.5)
		var straight_len: float = straight_start.distance_to(arc_start)
		# A zero-length straight (the R35 sweeper's two corners are exactly 2R
		# apart) would repeat the arc's first point. Two equal points give
		# CSGPolygon3D a zero direction ("The target vector can't be zero").
		if straight_len > step * 0.5:
			var n: int = maxi(1, int(straight_len / step))
			for k: int in n:
				out.append(straight_start.lerp(arc_start, float(k) / n))
		# Arc around the centre, on the inside of the turn.
		var side: float = signf(turn)
		var center: Vector2 = arc_start + Vector2(-d_in.y, d_in.x) * radius * side
		var a0: float = (arc_start - center).angle()
		var arc_len: float = radius * absf(turn)
		var m: int = maxi(2, int(arc_len / step))
		for k: int in m:
			var a: float = a0 + turn * float(k) / m
			out.append(center + Vector2(cos(a), sin(a)) * radius)
	return _without_repeats(out)


## Drops any point within 1 cm of the one before it, including at the loop
## join.
static func _without_repeats(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.01:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.01:
		out.remove_at(out.size() - 1)
	return out


## The UID in an existing scene file's header. The editor's UID cache is not
## updated in a script run, so this reads the header text.
static func _existing_uid(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var header: String = FileAccess.get_file_as_string(path).get_slice("\n", 0)
	var found: RegExMatch = RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(header)
	return ResourceUID.text_to_id(found.get_string(1)) if found != null else ResourceUID.INVALID_ID


static func loop_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in points.size():
		total += points[i].distance_to(points[(i + 1) % points.size()])
	return total


func _add(node: Node) -> void:
	_root.add_child(node)
	node.owner = _root


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


## A cross-section rectangle [x0, y0, x1, y1] extruded along the centreline.
func _extrude(node_name: String, rect: Array, material: Material) -> void:
	var csg := CSGPolygon3D.new()
	csg.name = node_name
	csg.polygon = PackedVector2Array(
		[
			Vector2(rect[0], rect[1]),
			Vector2(rect[2], rect[1]),
			Vector2(rect[2], rect[3]),
			Vector2(rect[0], rect[3]),
		]
	)
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = NodePath("../Centerline")
	csg.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	csg.path_interval = CSG_INTERVAL
	csg.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH
	csg.path_joined = true
	csg.use_collision = true
	csg.collision_layer = 1
	csg.collision_mask = 0
	csg.material = material
	_add(csg)


func _box(
	node_name: String,
	center: Vector3,
	size: Vector3,
	material: Material,
	collide: bool,
) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.position = center
	box.size = size
	box.material = material
	box.use_collision = collide
	box.collision_layer = 1
	box.collision_mask = 0
	_add(box)


## The same sun and sky as the sandbox, because each map brings its own
## (main.gd swaps the whole map scene).
func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.transform = Transform3D(
		Basis(
			Vector3(0.8660254, 0.0, 0.5),
			Vector3(0.35355338, 0.70710677, -0.6123724),
			Vector3(-0.35355338, 0.70710677, 0.6123724),
		),
		Vector3(0.0, 20.0, 0.0),
	)
	sun.shadow_enabled = true
	# The circuit is larger than the sandbox: keep shadows out to 200 m.
	sun.directional_shadow_max_distance = 200.0
	_add(sun)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.75, 0.9)
	world.environment = env
	_add(world)


func _add_ground() -> void:
	var grass: StandardMaterial3D = _mat(Color(0.35, 0.6, 0.32))
	_box(
		"Ground",
		Vector3(GROUND_CENTER.x, -0.5, GROUND_CENTER.y),
		Vector3(GROUND_SIZE.x, 1.0, GROUND_SIZE.y),
		grass,
		true,
	)
	var wall: StandardMaterial3D = _mat(Color(0.5, 0.3, 0.15))
	var half: Vector2 = GROUND_SIZE * 0.5
	var y: float = PERIMETER_HEIGHT * 0.5
	_box(
		"PerimeterNorth",
		Vector3(GROUND_CENTER.x, y, GROUND_CENTER.y - half.y),
		Vector3(GROUND_SIZE.x, PERIMETER_HEIGHT, 1.0),
		wall,
		true,
	)
	_box(
		"PerimeterSouth",
		Vector3(GROUND_CENTER.x, y, GROUND_CENTER.y + half.y),
		Vector3(GROUND_SIZE.x, PERIMETER_HEIGHT, 1.0),
		wall,
		true,
	)
	_box(
		"PerimeterWest",
		Vector3(GROUND_CENTER.x - half.x, y, GROUND_CENTER.y),
		Vector3(1.0, PERIMETER_HEIGHT, GROUND_SIZE.y),
		wall,
		true,
	)
	_box(
		"PerimeterEast",
		Vector3(GROUND_CENTER.x + half.x, y, GROUND_CENTER.y),
		Vector3(1.0, PERIMETER_HEIGHT, GROUND_SIZE.y),
		wall,
		true,
	)


func _add_kicker() -> void:
	var run: float = KICKER_HEIGHT / tan(deg_to_rad(KICKER_DEG))
	var wedge := CSGPolygon3D.new()
	wedge.name = "Kicker"
	wedge.polygon = PackedVector2Array(
		[Vector2(0, 0), Vector2(run, KICKER_HEIGHT), Vector2(run, 0)]
	)
	wedge.depth = KICKER_WIDTH
	# Local +X runs up the ramp (world +Z); the extrusion (local -Z) runs along
	# world +X, so the origin sits at the wedge's west edge (as Ramp2, T-021).
	wedge.transform = Transform3D(
		Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)),
		Vector3(70.0 - KICKER_WIDTH * 0.5, ROAD_TOP, KICKER_LOW_Z),
	)
	wedge.use_collision = true
	wedge.collision_layer = 1
	wedge.collision_mask = 0
	wedge.material = _mat(Color(0.2, 0.5, 0.85))
	_add(wedge)


## The jump walls sit on top of the barriers, set back JUMP_WALL_SETBACK on
## both faces. Built as full-height boxes in the same place as the barriers,
## they shared the barrier faces exactly and z-fought (FC-2: "clip over the
## barriers and cause visual noise", T-036). Now no faces coincide: the wall
## starts 1 cm inside the barrier top, so there is no gap, and its faces are
## 5 cm out from the barrier's.
func _add_jump_walls() -> void:
	var wall: StandardMaterial3D = _mat(Color(0.85, 0.4, 0.15))
	var length: float = JUMP_WALL_TO_Z - JUMP_WALL_FROM_Z
	var z: float = (JUMP_WALL_FROM_Z + JUMP_WALL_TO_Z) * 0.5
	var bottom: float = BARRIER_HEIGHT - JUMP_WALL_OVERLAP
	var height: float = JUMP_WALL_HEIGHT - bottom
	var x_off: float = BARRIER_INNER + JUMP_WALL_SETBACK + BARRIER_THICKNESS * 0.5
	for side: float in [-1.0, 1.0]:
		_box(
			"JumpWall" + ("West" if side < 0.0 else "East"),
			Vector3(70.0 + side * x_off, bottom + height * 0.5, z),
			Vector3(BARRIER_THICKNESS, height, length),
			wall,
			true,
		)


func _add_start_line() -> void:
	_box(
		"StartLine",
		Vector3(0.0, CURB_TOP, START_Z),
		Vector3(ROAD_HALF_WIDTH * 2.0, 0.01, 1.0),
		_mat(Color(0.95, 0.95, 0.95)),
		false,
	)
