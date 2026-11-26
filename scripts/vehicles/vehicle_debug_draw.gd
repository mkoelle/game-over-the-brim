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


func _process(_delta: float) -> void:
	if target == null or not GameConfig.debug_mode:
		return
	var origin: Vector3 = target.global_position + Vector3.UP * DRAW_HEIGHT
	var forward: Vector3 = -target.global_transform.basis.z
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
