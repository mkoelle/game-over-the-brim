class_name VehicleController
extends CharacterBody3D
## Arcade-style drivable vehicle body.
##
## Reads a per-device `InputSource` (Architecture Decision 01 —
## docs/architecture/overview.md — vehicles never poll `Input.*` globally)
## and a data-driven `VehicleStats` resource (docs/design/vehicles.md's
## Technical Implementation section) to move a `CharacterBody3D` with
## simple forward acceleration/braking, speed-scaled steering, a drift
## slip that lets velocity lag behind the facing direction, and reduced
## (not zero) control while airborne — matching kart-racer convention
## rather than a fully unpowered ballistic fall.
##
## It emits no EventBus signals. Its one signal, `impacted`, is local to
## this vehicle (see below).

## Emitted on the first physics frame of a wall contact, not on every
## frame of a scrape. It fires again during a contact only for a much
## harder hit, such as scraping one wall into another in a corner.
## `impact_speed` is how fast the car was moving into the wall, in m/s:
## the pre-slide velocity along the wall normal. Floor and ceiling
## contacts never emit it.
##
## Local and per-vehicle on purpose: in split screen only this car's camera
## should shake, so it never goes through EventBus (T-008).
signal impacted(impact_speed: float)

## A contact whose normal is within about 45 degrees of straight up or
## down (|normal.y| at or above this) is a floor or a ceiling, not a wall.
## This matches the default floor_max_angle.
const WALL_NORMAL_MAX_Y: float = 0.7

## A wall contact that starts within this many seconds of the last one is
## the same hit, so a scrape that flickers on and off the wall emits
## `impacted` once.
const WALL_REARM_TIME: float = 0.1

## During a contact, a frame whose into-wall speed beats the fastest so far
## by this much, in m/s, is a new hit (a second wall). With today's stats,
## steering harder into the same wall adds at most about 1 m/s per frame.
const HARDER_HIT_SPEED: float = 3.0

## Data-driven tuning knobs (max speed, acceleration, steering, drift grip,
## mass). Assign a VehicleStats .tres in the Inspector.
@export var stats: VehicleStats

## Per-device input reader. Not exported — InputSource isn't a Resource,
## so whoever spawns this vehicle assigns it. Defaults to keyboard so the
## node is drivable standalone with no external wiring.
var input_source: InputSource = InputSource.new()

## This frame's raw input snapshot, kept for external readout only (e.g.
## DebugOverlay) — not read back by this script itself.
var last_input: Dictionary[String, Variant] = { }

## The steer value actually applied this tick, after the input ramp
## (T-027). -1 is full left, +1 full right. Public for debug readouts.
var steer_applied: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _time_since_wall_contact: float = INF
var _contact_peak_speed: float = 0.0


func _physics_process(delta: float) -> void:
	var input: Dictionary[String, Variant] = input_source.get_input()
	last_input = input
	var throttle: float = float(input.get("throttle", 0.0))
	var steer: float = _ramped_steer(float(input.get("steer", 0.0)), delta)
	var drift: bool = bool(input.get("drift", false))

	var forward: Vector3 = -transform.basis.z
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed: float = flat_velocity.dot(forward)
	var grounded: bool = is_on_floor()

	# --- Control effectiveness: full on the ground, partial while airborne
	# (stats.air_control). Kart racers consistently give the player some
	# control and continued boosting mid-jump rather than an unpowered
	# ballistic fall — Super Mario Kart's handling is fully ground-
	# equivalent in the air, Crash Team Racing's air-brake lets you turn
	# *tighter* than on the ground. This project splits the difference:
	# meaningful but reduced control, so a launch's momentum still
	# dominates instead of the car snapping to a new heading mid-flight. ---
	var control_factor: float = 1.0 if grounded else stats.air_control

	# --- Acceleration / braking along the vehicle's forward basis ---
	if throttle >= 0.0:
		current_speed += throttle * stats.acceleration * control_factor * delta
	else:
		current_speed += throttle * stats.braking_force * control_factor * delta
	current_speed = clampf(current_speed, -stats.max_speed, stats.max_speed)

	var target_flat_velocity: Vector3 = forward * current_speed

	# --- Drift (grounded) / air control (airborne): blend velocity toward
	# the target instead of snapping to it — on the ground this is the
	# slide-through-a-corner mechanic; airborne, the same blend at a lower
	# rate is what keeps a ramp launch's momentum dominant instead of the
	# floaty "re-snap every frame" bug this replaced. ---
	if not grounded:
		flat_velocity = flat_velocity.lerp(target_flat_velocity, stats.air_control)
	elif drift:
		flat_velocity = flat_velocity.lerp(target_flat_velocity, stats.drift_grip)
	else:
		flat_velocity = target_flat_velocity

	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z

	# --- Steering (T-027): a flat yaw rate once moving, so the turn radius
	# grows with speed (handling-reference.md section 1). It fades in from
	# steer_min_speed, so the car never spins on the spot, and is scaled by
	# control_factor (reduced but not zero in the air). Scaled by
	# signf(current_speed) so steer_right always curves the actual path
	# right on screen, forward or reverse — real cars invert this in
	# reverse (turn the wheel right, the nose swings right but the car
	# actually travels left), which reads as broken controls in a casual
	# party game. "Fun > Realism" (docs/design/game-pillars.md) wins here. ---
	var fade: float = steer_speed_fade(
		absf(current_speed),
		stats.steer_min_speed,
		stats.steer_full_speed,
	)
	var yaw: float = (
		-steer * stats.steering_rate * fade * delta * signf(current_speed) * control_factor
	)
	rotate_y(yaw)

	# --- Gravity ---
	if grounded:
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	# The slide removes the into-wall part of velocity, so read it before.
	var pre_slide_velocity: Vector3 = velocity
	move_and_slide()
	_detect_wall_impact(pre_slide_velocity, delta)


## Steering strength from 0 to 1 by speed: 0 at or below `min_speed`, 1 at or
## above `full_speed`, smooth in between (T-027).
static func steer_speed_fade(speed: float, min_speed: float, full_speed: float) -> float:
	if full_speed <= min_speed:
		return 1.0 if speed > min_speed else 0.0
	return smoothstep(min_speed, full_speed, speed)


## Moves `current` toward `target` at a fixed rate, so full lock takes
## `ramp_time` seconds from centre. When the input crosses centre (the signs
## differ), it moves at the slower `reverse_time` rate per unit instead.
## Pure and tick-based, so it is deterministic (T-027).
static func ramp_steer(
	current: float,
	target: float,
	delta: float,
	ramp_time: float,
	reverse_time: float,
) -> float:
	var crossing: bool = current * target < 0.0
	var time: float = reverse_time if crossing else ramp_time
	if time <= 0.0:
		return target
	return move_toward(current, target, delta / time)


func _ramped_steer(raw: float, delta: float) -> float:
	steer_applied = ramp_steer(
		steer_applied,
		clampf(raw, -1.0, 1.0),
		delta,
		stats.steer_ramp_time,
		stats.steer_reverse_time,
	)
	return steer_applied


## Emits `impacted` on the first frame of a wall contact, or for a much
## harder hit during one. It reads only is_on_wall() and get_wall_normal(),
## which return plain values, so it allocates nothing.
## get_slide_collision() would hand out a KinematicCollision3D object.
func _detect_wall_impact(pre_slide_velocity: Vector3, delta: float) -> void:
	var normal: Vector3 = get_wall_normal()
	if not is_on_wall() or absf(normal.y) >= WALL_NORMAL_MAX_Y:
		_time_since_wall_contact += delta
		return
	var impact_speed: float = -pre_slide_velocity.dot(normal)
	if _time_since_wall_contact >= WALL_REARM_TIME:
		# A new contact: any speed into the wall is a hit.
		_contact_peak_speed = 0.0
		if impact_speed > 0.0:
			impacted.emit(impact_speed)
	elif impact_speed > _contact_peak_speed + HARDER_HIT_SPEED:
		# Still touching, but suddenly much harder: another wall.
		impacted.emit(impact_speed)
	_time_since_wall_contact = 0.0
	_contact_peak_speed = maxf(_contact_peak_speed, impact_speed)
