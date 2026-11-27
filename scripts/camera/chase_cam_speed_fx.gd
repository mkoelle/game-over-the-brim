class_name ChaseCamSpeedFx
extends Node
## Sells speed and boost through the chase camera (T-034,
## handling-reference.md section 4):
## - FOV widens with speed (0 to SPEED_FOV degrees across 0 to top speed)
## - a boost widens it further, by tier, with a quick attack and a slow decay
## - a boost pulls the camera back a little
##
## It must be a child of the Camera3D. CarFollowCam has no Camera3DResource,
## so PhantomCameraHost never writes the FOV and this node owns it. main.gd
## assigns `target` and `follow_cam`. In split screen each player's camera gets
## its own node, so one car's boost never widens another player's view.

## Base vertical FOV, in degrees, for one player (section 4: 75).
@export var base_fov: float = 75.0

## Extra FOV at top speed, in degrees (section 4: +0 to +4).
@export var speed_fov: float = 4.0

## Extra FOV while boosting, in degrees, by boost tier: index 0 is a trick
## boost (T-033), 1-3 the drift tiers (section 4: +8, up to +12), and 4 a
## gauge boost (T-039).
@export var boost_fov_by_tier: PackedFloat32Array = PackedFloat32Array([10.0, 8.0, 10.0, 12.0, 9.0])

## FOV time constants, in seconds: widening (attack) and narrowing (decay).
## Section 4: 0.15 s in, 0.5 s out.
@export var fov_attack_time: float = 0.15
@export var fov_decay_time: float = 0.5

## Extra spring length, in metres, while boosting (section 4: 0.3-0.6).
@export var boost_pull_back: float = 0.45

## Time constant, in seconds, for the pull-back.
@export var pull_back_time: float = 0.25

var target: VehicleController

var follow_cam: PhantomCamera3D:
	set(value):
		follow_cam = value
		if follow_cam != null:
			_base_spring_length = follow_cam.spring_length

var _camera: Camera3D
var _base_spring_length: float = 0.0
var _pull: float = 0.0


func _ready() -> void:
	_camera = get_parent() as Camera3D
	if _camera == null:
		push_error("ChaseCamSpeedFx must be a child of a Camera3D")
		set_process(false)
		return
	_camera.fov = base_fov


## FOV target, in degrees, from a speed share (0-1) and a boost FOV.
static func fov_for(
	base: float,
	speed_extra: float,
	speed_share: float,
	boost_extra: float,
) -> float:
	return base + speed_extra * clampf(speed_share, 0.0, 1.0) + boost_extra


## Moves `current` toward `goal` with time constant `rise` when going up and
## `fall` when going down. Frame-rate independent.
static func approach(current: float, goal: float, delta: float, rise: float, fall: float) -> float:
	var tau: float = rise if goal > current else fall
	return lerpf(current, goal, 1.0 - exp(-delta / maxf(tau, 0.001)))


func _process(delta: float) -> void:
	if target == null:
		return
	var share: float = absf(target.speed) / maxf(target.stats.max_speed, 0.01)
	var boosting: bool = target.boost_time_left > 0.0
	var boost_extra: float = 0.0
	if boosting and target.boost_tier >= 0 and target.boost_tier < boost_fov_by_tier.size():
		boost_extra = boost_fov_by_tier[target.boost_tier]
	var goal: float = fov_for(base_fov, speed_fov, share, boost_extra)
	_camera.fov = approach(_camera.fov, goal, delta, fov_attack_time, fov_decay_time)
	if follow_cam != null:
		_pull = approach(
			_pull,
			boost_pull_back if boosting else 0.0,
			delta,
			pull_back_time,
			pull_back_time,
		)
		follow_cam.spring_length = _base_spring_length + _pull
