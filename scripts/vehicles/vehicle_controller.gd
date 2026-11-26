class_name VehicleController
extends CharacterBody3D
## Arcade-style drivable vehicle body.
##
## Reads a per-device `InputSource` (Architecture Decision 01 —
## docs/architecture/overview.md — vehicles never poll `Input.*` globally)
## and a data-driven `VehicleStats` resource (docs/design/vehicles.md's
## Technical Implementation section) to move a `CharacterBody3D`. The
## handling rework (docs/plans/handling-rework-plan.md) adds:
## - T-027: a flat yaw-rate steering curve with a standstill fade and a
##   steer ramp
## - T-028: a speed and travel-direction model with frame-rate independent
##   grip, and a locked-direction drift whose slide angle is the gap between
##   the body heading and the travel direction
## Control is reduced (not zero) while airborne.
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

## Emitted when a drift starts. `direction` is +1 for right, -1 for left.
signal drift_started(direction: int)

## Emitted when a drift ends, for any reason.
signal drift_ended

## A contact whose normal is within about 45 degrees of straight up or
## down (|normal.y| at or above this) is a floor or a ceiling, not a wall.
## This matches the default floor_max_angle.
const WALL_NORMAL_MAX_Y: float = 0.7

## A wall contact that starts within this many seconds of the last one is
## the same hit, so a scrape that flickers on and off the wall emits
## `impacted` once.
const WALL_REARM_TIME: float = 0.1

## Smallest steer input that starts a drift (T-028).
const DRIFT_ENTRY_STEER: float = 0.3

## Inside a drift, steer maps to this share of the drift turn: full out-turn
## gives the minimum, full in-turn the maximum (STK 0.2 / 0.8, T-028).
const DRIFT_STEER_MIN: float = 0.2
const DRIFT_STEER_MAX: float = 0.8

## A drift ends below this share of `drift_min_speed`, so speed noise at the
## threshold does not flicker it on and off.
const DRIFT_EXIT_SPEED_RATIO: float = 0.8

## A drift survives this long in the air, in seconds, so a bump does not end
## it.
const DRIFT_AIR_GRACE: float = 0.3

## Below this speed, in m/s, the slide angle reads 0.
const MIN_SLIDE_SPEED: float = 0.5

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

## Signed speed along the travel direction, in m/s. Negative is reversing
## (T-028).
var speed: float = 0.0

## True while drifting (T-028).
var is_drifting: bool = false

## Locked drift direction: +1 right, -1 left, 0 when not drifting.
var drift_direction: int = 0

## Signed angle, in degrees, from the body heading to the travel direction
## around +Y. It is positive when the car travels to the left of its nose.
var slide_angle_deg: float = 0.0

## The steer value actually applied this tick, after the input ramp
## (T-027). -1 is full left, +1 full right. Public for debug readouts.
var steer_applied: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _time_since_wall_contact: float = INF
var _contact_peak_speed: float = 0.0
var _drift_air_time: float = 0.0


func _physics_process(delta: float) -> void:
	var input: Dictionary[String, Variant] = input_source.get_input()
	last_input = input
	var throttle: float = float(input.get("throttle", 0.0))
	var raw_steer: float = clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	var steer: float = _ramped_steer(raw_steer, delta)
	var drift_held: bool = bool(input.get("drift", false))
	var grounded: bool = is_on_floor()

	# --- Control effectiveness: full on the ground, partial while airborne
	# (stats.air_control), so a launch's momentum still dominates. ---
	var control_factor: float = 1.0 if grounded else stats.air_control

	# --- Speed and travel direction (T-028). The velocity itself holds both:
	# its length is the speed and its direction is where the car is going.
	# Reading them back each tick, instead of projecting the velocity onto
	# the facing direction, means a slide or a wall no longer bleeds speed
	# by itself, and an outside change (a respawn, a wall) is kept. ---
	var body_forward: Vector3 = -global_transform.basis.z
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	speed = signed_speed(flat, body_forward, speed)
	var travel: Vector3 = travel_direction(flat, body_forward, speed)

	# --- Acceleration / braking ---
	if throttle >= 0.0:
		speed += throttle * stats.acceleration * control_factor * delta
	else:
		speed += throttle * stats.braking_force * control_factor * delta
	speed = clampf(speed, -stats.max_speed, stats.max_speed)

	_update_drift(drift_held, raw_steer, grounded, delta)

	# --- Steering (T-027): a flat yaw rate once moving, so the turn radius
	# grows with speed (handling-reference.md section 1). It fades in from
	# steer_min_speed, so the car never spins on the spot, and is scaled by
	# control_factor (reduced but not zero in the air). Scaled by
	# signf(speed) so steer_right always curves the actual path right on
	# screen, forward or reverse — real cars invert this in reverse, which
	# reads as broken controls in a casual party game. "Fun > Realism"
	# (docs/design/game-pillars.md) wins here.
	# In a drift (T-028) the direction is locked, and the steer picks 20-80%
	# of a faster drift turn: steering in tightens the line, steering out
	# widens it, and neither exits the drift. ---
	var yaw_rate: float
	if is_drifting:
		yaw_rate = (
			-float(drift_direction) * stats.steering_rate * stats.drift_turn_multiplier
			* drift_steer_share(steer * float(drift_direction))
		)
	else:
		var fade: float = steer_speed_fade(
			absf(speed),
			stats.steer_min_speed,
			stats.steer_full_speed,
		)
		yaw_rate = -steer * stats.steering_rate * fade * signf(speed)
	rotate_y(yaw_rate * control_factor * delta)
	body_forward = -global_transform.basis.z

	# --- Grip (T-028): on the ground the travel direction turns toward the
	# body heading with a time constant, short while gripping and long while
	# drifting, which is the slide. It is frame-rate independent. In the air
	# the travel direction is kept, so a launch keeps its line. ---
	if grounded:
		var tau: float = stats.drift_slide_time if is_drifting else stats.grip_time
		travel = turn_toward(travel, body_forward, 1.0 - exp(-delta / tau))
		travel = clamp_slide(travel, body_forward, deg_to_rad(stats.max_slide_angle_deg))
	slide_angle_deg = (
		rad_to_deg(body_forward.signed_angle_to(travel, Vector3.UP))
		if absf(speed) > MIN_SLIDE_SPEED
		else 0.0
	)
	var new_flat: Vector3 = travel * speed
	velocity.x = new_flat.x
	velocity.z = new_flat.z

	# --- Gravity ---
	if grounded:
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	# The slide removes the into-wall part of velocity, so read it before.
	var pre_slide_velocity: Vector3 = velocity
	move_and_slide()
	_detect_wall_impact(pre_slide_velocity, delta)


## Signed speed from a flat velocity: its length, negative when it points
## behind the body. When it is almost sideways, it keeps the sign of
## `previous`.
static func signed_speed(flat: Vector3, body_forward: Vector3, previous: float) -> float:
	var magnitude: float = flat.length()
	if magnitude < 0.01:
		return 0.0
	var along: float = flat.dot(body_forward)
	if absf(along) < 0.05 * magnitude:
		return magnitude * (signf(previous) if previous != 0.0 else 1.0)
	return magnitude * signf(along)


## Unit direction of forward travel. When reversing, it points along the body,
## so that `travel * speed` (speed < 0) moves backward.
static func travel_direction(flat: Vector3, body_forward: Vector3, signed: float) -> Vector3:
	if flat.length() < 0.01:
		return body_forward
	var dir: Vector3 = flat.normalized()
	return -dir if signed < 0.0 else dir


## Turns unit vector `from` toward `to` around +Y by fraction `t` of the angle
## between them.
static func turn_toward(from: Vector3, to: Vector3, t: float) -> Vector3:
	return from.rotated(Vector3.UP, from.signed_angle_to(to, Vector3.UP) * clampf(t, 0.0, 1.0))


## Keeps `travel` within `max_angle` radians of `body` around +Y.
static func clamp_slide(travel: Vector3, body: Vector3, max_angle: float) -> Vector3:
	var angle: float = body.signed_angle_to(travel, Vector3.UP)
	if absf(angle) <= max_angle:
		return travel
	return body.rotated(Vector3.UP, signf(angle) * max_angle)


## Share of the drift turn for a steer value relative to the drift direction:
## -1 is full out-turn, +1 full in-turn (T-028).
static func drift_steer_share(relative_steer: float) -> float:
	return lerpf(DRIFT_STEER_MIN, DRIFT_STEER_MAX, (clampf(relative_steer, -1.0, 1.0) + 1.0) * 0.5)


## Whether a drift may start this tick (T-028): button held, steer past the
## entry threshold, fast enough, on the ground, and moving forward.
static func can_start_drift(
	held: bool,
	raw_steer: float,
	signed: float,
	grounded: bool,
	min_speed: float,
) -> bool:
	return held and grounded and absf(raw_steer) >= DRIFT_ENTRY_STEER and signed >= min_speed


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


func _update_drift(held: bool, raw_steer: float, grounded: bool, delta: float) -> void:
	if is_drifting:
		_drift_air_time = 0.0 if grounded else _drift_air_time + delta
		if (
			not held or speed < stats.drift_min_speed * DRIFT_EXIT_SPEED_RATIO
			or _drift_air_time > DRIFT_AIR_GRACE
		):
			_end_drift()
		return
	if can_start_drift(held, raw_steer, speed, grounded, stats.drift_min_speed):
		is_drifting = true
		drift_direction = 1 if raw_steer > 0.0 else -1
		_drift_air_time = 0.0
		drift_started.emit(drift_direction)


func _end_drift() -> void:
	is_drifting = false
	drift_direction = 0
	drift_ended.emit()


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
