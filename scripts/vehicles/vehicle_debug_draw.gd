class_name VehicleDebugDraw
extends Node
## Dev-only in-world handling vectors (ADR-016). Attached at runtime by
## main.gd in debug builds only — never referenced by gameplay code.
##
## Draws, while GameConfig.debug_mode (F3) is on:
## - blue arrow: facing (-basis.z, 2 m)
## - green arrow: flat velocity (scaled by speed / max_speed, max 3 m)
## - yellow arrow: floor normal (only while grounded)
## - text: slip angle in degrees and grounded state
##
## Reads public VehicleController state only, like DebugOverlay.
##
## Debug Draw 3D draws text with pooled Label3D nodes under its own
## `_DD3D_WorldWatcher` node, and moves them every rendered frame. With
## project physics interpolation on (T-020), they would inherit it and blend
## from wherever each pooled label was last used, so the text shook and
## popped across the screen in turns. This node turns interpolation off for
## those nodes (T-022). The addon itself stays unmodified (ADR-015).

const FACING_LENGTH: float = 2.0
const VELOCITY_MAX_LENGTH: float = 3.0
const NORMAL_LENGTH: float = 1.5
## Below this flat speed (m/s) the slip angle is meaningless noise.
const MIN_SLIP_SPEED: float = 0.5
## Arrows start this far above the car origin so the floor does not hide them.
const DRAW_HEIGHT: float = 0.6
const TEXT_HEIGHT: float = 2.4
## Arrowhead size in metres (absolute, so short arrows keep small heads).
const ARROW_HEAD_SIZE: float = 0.2
const FACING_COLOR: Color = Color.BLUE
const VELOCITY_COLOR: Color = Color.GREEN
const NORMAL_COLOR: Color = Color.YELLOW
## Debug Draw 3D's per-world root node name contains this.
const DD3D_NODE_MARKER: String = "_DD3D_"

var target: VehicleController


## Signed angle in degrees from `forward` to `flat_velocity` around +Y.
## Returns 0.0 when the flat speed is at or below MIN_SLIP_SPEED.
static func slip_angle_deg(forward: Vector3, flat_velocity: Vector3) -> float:
	if flat_velocity.length() <= MIN_SLIP_SPEED:
		return 0.0
	return rad_to_deg(forward.signed_angle_to(flat_velocity, Vector3.UP))


## Length in metres of the velocity arrow: speed / max_speed, capped.
static func velocity_arrow_length(speed: float, max_speed: float) -> float:
	if max_speed <= 0.0:
		return 0.0
	return clampf(speed / max_speed, 0.0, 1.0) * VELOCITY_MAX_LENGTH


## True for Debug Draw 3D's own nodes, which move every frame and must not be
## physics-interpolated.
static func is_dd3d_node(node: Node) -> bool:
	return String(node.name).contains(DD3D_NODE_MARKER)


## Turns physics interpolation off for `node` if it is a Debug Draw 3D node.
## Its pooled Label3D children inherit the setting.
static func disable_dd3d_interpolation(node: Node) -> void:
	if is_dd3d_node(node):
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	var tree: SceneTree = get_tree()
	for child: Node in tree.root.get_children(true):
		disable_dd3d_interpolation(child)
	# Debug Draw 3D may create its world node later (for example per world
	# in split screen), so also catch it when it enters the tree.
	tree.node_added.connect(_on_node_added)


# An instance method, so the connection ends when this node is freed.
func _on_node_added(node: Node) -> void:
	disable_dd3d_interpolation(node)


func _process(_delta: float) -> void:
	if target == null or not GameConfig.debug_mode:
		return
	# Interpolated, so the arrows stay on the car as drawn between physics
	# ticks (T-020).
	var drawn: Transform3D = target.get_global_transform_interpolated()
	var origin: Vector3 = drawn.origin + Vector3.UP * DRAW_HEIGHT
	var forward: Vector3 = -drawn.basis.z
	var flat_velocity: Vector3 = Vector3(target.velocity.x, 0.0, target.velocity.z)
	var speed: float = flat_velocity.length()
	var grounded: bool = target.is_on_floor()

	DebugDraw3D.draw_arrow(
		origin,
		origin + forward * FACING_LENGTH,
		FACING_COLOR,
		ARROW_HEAD_SIZE,
		true,
	)
	var velocity_length: float = velocity_arrow_length(speed, target.stats.max_speed)
	if velocity_length > 0.01:
		DebugDraw3D.draw_arrow(
			origin,
			origin + flat_velocity / speed * velocity_length,
			VELOCITY_COLOR,
			ARROW_HEAD_SIZE,
			true,
		)
	if grounded:
		DebugDraw3D.draw_arrow(
			origin,
			origin + target.get_floor_normal() * NORMAL_LENGTH,
			NORMAL_COLOR,
			ARROW_HEAD_SIZE,
			true,
		)

	# String formatting allocates every frame. Accepted: debug-only code that
	# runs only with F3 on in debug builds (ADR-016).
	var text: String = (
		"slip %+.1f deg\n%s"
		% [slip_angle_deg(forward, flat_velocity), "grounded" if grounded else "airborne"]
	)
	DebugDraw3D.draw_text(origin + Vector3.UP * (TEXT_HEIGHT - DRAW_HEIGHT), text, 32)
