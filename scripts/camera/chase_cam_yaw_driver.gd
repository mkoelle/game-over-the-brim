class_name ChaseCamYawDriver
extends Node
## Turns a Third Person PhantomCamera3D with the car it follows (T-005).
##
## Phantom Camera does the follow, the position damping and the wall
## collision. Its Third Person mode does not turn with the target
## (ADR-013), so this node writes the rig's pitch and yaw every frame. It
## must be a child of the PhantomCamera3D, and it reads that camera's
## `follow_target`, so the car is assigned in one place only (main.gd).
##
## Pitch is the camera's own `vertical_rotation_offset` (positive looks
## down), so the framing values live in the CarFollowCam inspector.
## Distance grows with speed on its own: the X/Z follow damping lags the
## rig by about speed x damping time.
##
## Default process_priority (0) runs before PhantomCameraHost (300), so the
## camera uses this frame's yaw, not last frame's.
##
## The car moves in `_physics_process` (60 Hz) but this runs every rendered
## frame, so it reads the car's interpolated transform, like Phantom Camera
## does. With physics interpolation on (T-020) that is where the car is drawn.

## Yaw smoothing time constant, in seconds. Steady-cornering lag is about
## yaw rate x this value (21 degrees at full lock and top speed).
@export_range(0.01, 1.0, 0.01, "suffix:s") var yaw_smooth_time: float = 0.15

## Share of the velocity heading in the yaw target (0 = body heading only).
## Keeps the road in view in a slide. Off by default: velocity flips on a
## wall hit, which swings the camera into the wall (T-005 drive probe).
@export_range(0.0, 1.0, 0.05) var velocity_heading_weight: float = 0.0

## Below this flat speed, in m/s, only the body heading is used.
@export var min_heading_speed: float = 2.0

## While airborne, do not follow the car above its takeoff height, so the
## view does not bob up on a jump. It still follows the car down.
@export var hold_height_in_air: bool = true

## Time constant, in seconds, for handing height back after landing.
@export_range(0.01, 1.0, 0.01, "suffix:s") var air_release_time: float = 0.4

var _pcam: PhantomCamera3D
var _base_offset_y: float = 0.0
var _yaw: float = NAN
var _takeoff_y: float = NAN
var _air_lift: float = 0.0


func _ready() -> void:
	_pcam = get_parent() as PhantomCamera3D
	_base_offset_y = _pcam.follow_offset.y


func _process(delta: float) -> void:
	var target: Node3D = _pcam.follow_target
	if target == null:
		return
	var heading: float = _heading(target)
	if is_nan(_yaw):
		_yaw = heading
	_yaw = lerp_angle(_yaw, heading, 1.0 - exp(-delta / yaw_smooth_time))
	_pcam.set_third_person_rotation(Vector3(-_pcam.vertical_rotation_offset, _yaw, 0.0))
	var body: CharacterBody3D = target as CharacterBody3D
	if hold_height_in_air and body != null:
		_update_air_lift(body, delta)
		_pcam.follow_offset.y = _base_offset_y - _air_lift


func _heading(target: Node3D) -> float:
	var back: Vector3 = target.get_global_transform_interpolated().basis.z
	var body_yaw: float = atan2(back.x, back.z)
	var body: CharacterBody3D = target as CharacterBody3D
	if body == null or velocity_heading_weight <= 0.0:
		return body_yaw
	var flat: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	# Ignore velocity when slow or reversing, so the camera stays behind.
	if flat.length() < min_heading_speed or flat.dot(back) > 0.0:
		return body_yaw
	return lerp_angle(body_yaw, atan2(-flat.x, -flat.z), velocity_heading_weight)


func _update_air_lift(body: CharacterBody3D, delta: float) -> void:
	var y: float = body.get_global_transform_interpolated().origin.y
	if body.is_on_floor():
		_takeoff_y = NAN
		_air_lift *= exp(-delta / air_release_time)
		return
	if is_nan(_takeoff_y):
		_takeoff_y = y - _air_lift
	_air_lift = maxf(0.0, y - _takeoff_y)
