class_name VehicleVisualBody
extends Node3D
## The car's visible body (T-032). It sells the handling while the physics
## body stays upright (handling-reference.md sections 5 and 6):
## - roll into turns, capped at MAX_ROLL_DEG
## - pitch and roll to the ground normal, or to the velocity pitch in the air
## - a visual-only hop on drift entry
## - a tint and sparks per drift tier, in a different colour for each, so the
##   tier reads in a small split-screen viewport
##
## It must be a child of a VehicleController and reads only its public state.
## It updates in _physics_process, after the car (tree order), so physics
## interpolation (T-020) smooths it like the car itself.

## Largest roll into a turn, in degrees (section 6 caps it at about 10).
const MAX_ROLL_DEG: float = 10.0

## Time constants, in seconds: roll (section 5: 0.2), ground alignment
## (section 5: 0.1) and air pitch.
const ROLL_TIME: float = 0.2
const ALIGN_TIME: float = 0.1
const AIR_PITCH_TIME: float = 0.25

## Largest nose-up or nose-down pitch in the air, in degrees.
const MAX_AIR_PITCH_DEG: float = 25.0

## Drift entry hop (section 2: visual only, 0.3-0.4 s).
const HOP_TIME: float = 0.35
const HOP_HEIGHT: float = 0.3

## Tier colours: cyan, amber, magenta. Each is distinct from the others and
## from the red body, including for the common colour-vision deficiencies.
const TIER_COLORS: Array[Color] = [
	Color(0.31, 0.84, 1.0),
	Color(1.0, 0.69, 0.18),
	Color(1.0, 0.31, 0.85),
]

## Tint strength (emission energy) per tier, and while boosting.
const TIER_TINT_ENERGY: float = 0.3
const BOOST_TINT_ENERGY: float = 0.6

## Spark emitters sit at the rear wheels, in car space.
const SPARK_OFFSETS: Array[Vector3] = [Vector3(-0.45, -0.45, 0.95), Vector3(0.45, -0.45, 0.95)]

var _car: VehicleController
var _roll: float = 0.0
var _align: Basis = Basis.IDENTITY
var _hop_left: float = 0.0
var _material: StandardMaterial3D
var _sparks: Array[GPUParticles3D] = []
var _spark_material: ParticleProcessMaterial


func _ready() -> void:
	_car = get_parent() as VehicleController
	if _car == null:
		push_error("VehicleVisualBody must be a child of a VehicleController")
		set_physics_process(false)
		return
	_car.drift_started.connect(_on_drift_started)
	_take_own_material()
	_make_sparks()


## Roll angle, in radians, for a steer value and speed share (0-1): into the
## turn, scaled by speed, capped (T-032).
static func target_roll(steer: float, speed_share: float) -> float:
	return -steer * clampf(speed_share, 0.0, 1.0) * deg_to_rad(MAX_ROLL_DEG)


## Hop height for `left` seconds remaining of a HOP_TIME hop: a parabola.
static func hop_offset(left: float) -> float:
	if left <= 0.0:
		return 0.0
	var t: float = 1.0 - left / HOP_TIME
	return 4.0 * HOP_HEIGHT * t * (1.0 - t)


## Basis that tilts the car's up axis to `normal`, keeping its heading.
static func tilt_to(normal: Vector3) -> Basis:
	var up: Vector3 = normal.normalized()
	if up.dot(Vector3.UP) > 0.9999:
		return Basis.IDENTITY
	var axis: Vector3 = Vector3.UP.cross(up).normalized()
	return Basis(axis, Vector3.UP.angle_to(up))


func _physics_process(delta: float) -> void:
	var share: float = absf(_car.speed) / maxf(_car.stats.max_speed, 0.01)
	var steer: float = _car.steer_applied
	if _car.is_drifting:
		steer = float(_car.drift_direction)
	_roll = lerpf(_roll, target_roll(steer, share), 1.0 - exp(-delta / ROLL_TIME))

	var target_tilt: Basis
	var tilt_time: float = ALIGN_TIME
	if _car.is_on_floor():
		# World-space tilt to the floor, expressed in car space.
		var local_normal: Vector3 = _car.global_basis.inverse() * _car.ground_normal
		target_tilt = tilt_to(local_normal)
	else:
		var flat: float = Vector2(_car.velocity.x, _car.velocity.z).length()
		var pitch: float = clampf(
			atan2(_car.velocity.y, maxf(flat, 0.01)),
			-deg_to_rad(MAX_AIR_PITCH_DEG),
			deg_to_rad(MAX_AIR_PITCH_DEG),
		)
		target_tilt = Basis(
			Vector3.RIGHT,
			pitch * signf(_car.speed) if _car.speed != 0.0 else pitch,
		)
		tilt_time = AIR_PITCH_TIME
	_align = _align.slerp(target_tilt, 1.0 - exp(-delta / tilt_time)).orthonormalized()

	_hop_left = maxf(_hop_left - delta, 0.0)
	transform = Transform3D(_align * Basis(Vector3.BACK, _roll), Vector3.UP * hop_offset(_hop_left))
	_update_tier_cues()


func _on_drift_started(_direction: int) -> void:
	_hop_left = HOP_TIME


## The tint is set on a copy of the mesh's material, so one car's tier never
## tints another car.
func _take_own_material() -> void:
	for child: Node in get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			_material = (mesh.material_override as StandardMaterial3D).duplicate()
			_material.emission_enabled = true
			_material.emission_energy_multiplier = 0.0
			mesh.material_override = _material
			return


func _make_sparks() -> void:
	_spark_material = ParticleProcessMaterial.new()
	_spark_material.direction = Vector3(0.0, 0.6, 1.0)
	_spark_material.spread = 25.0
	_spark_material.initial_velocity_min = 3.0
	_spark_material.initial_velocity_max = 6.0
	_spark_material.gravity = Vector3(0.0, -12.0, 0.0)
	_spark_material.scale_min = 0.6
	_spark_material.scale_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var spark_look := StandardMaterial3D.new()
	spark_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_look.vertex_color_use_as_albedo = true
	quad.material = spark_look
	for offset: Vector3 in SPARK_OFFSETS:
		var sparks := GPUParticles3D.new()
		sparks.amount = 24
		sparks.lifetime = 0.3
		sparks.local_coords = false
		sparks.emitting = false
		sparks.process_material = _spark_material
		sparks.draw_pass_1 = quad
		sparks.position = offset
		add_child(sparks)
		_sparks.append(sparks)


func _update_tier_cues() -> void:
	var tier: int = _car.drift_tier if _car.is_drifting else 0
	var boosting: bool = _car.boost_time_left > 0.0
	var cue_tier: int = _car.boost_tier if boosting else tier
	if _material != null:
		if cue_tier > 0:
			_material.emission = TIER_COLORS[cue_tier - 1]
			_material.emission_energy_multiplier = (
				BOOST_TINT_ENERGY if boosting else TIER_TINT_ENERGY
			)
		else:
			_material.emission_energy_multiplier = 0.0
	var spark_on: bool = tier > 0 and _car.is_on_floor()
	if spark_on:
		_spark_material.color = TIER_COLORS[tier - 1]
	for sparks: GPUParticles3D in _sparks:
		sparks.emitting = spark_on


## Current tint colour and energy, for tests and readouts.
func tint() -> Color:
	if _material == null or _material.emission_energy_multiplier <= 0.0:
		return Color.BLACK
	return _material.emission


func sparks_emitting() -> bool:
	return not _sparks.is_empty() and _sparks[0].emitting
