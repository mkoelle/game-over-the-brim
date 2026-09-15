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
## No EventBus signals are emitted yet — that lands with the main.tscn
## wiring task, not here.

## Emitted once per stuck episode, when the vehicle has held an abnormal
## airborne-and-not-falling state past STUCK_TIME_THRESHOLD. A plain local
## signal, not an EventBus one — EventBus wiring stays out of this script
## (see the class docstring); a later task connects to this from outside.
signal vehicle_stuck

## Airborne speed (m/s) under which the vehicle counts as "not actually
## falling". Real free-fall gains speed from gravity every frame, so velocity
## staying this low while airborne indicates something is physically blocking
## the car, not normal airtime.
const STUCK_VELOCITY_THRESHOLD: float = 0.5

## Seconds the abnormal state must hold before the stuck signal fires. Matches
## this project's existing "Comic Respawn" convention of resolving within
## roughly 1.5s (docs/design/vehicles.md), so a stuck vehicle is caught and can
## be recovered on a comparable timescale.
const STUCK_TIME_THRESHOLD: float = 1.75

## Throttle magnitude below which the pedal counts as "released" rather than
## a genuine tiny input. Needed because the keyboard/action-map input path
## reads Input.get_action_strength() with no deadzone applied, and keyboard-
## bound actions share a joypad binding (input_source.gd) -- idle analog
## noise from a connected-but-unused gamepad can leak in as a nonzero
## non-exact-0.0 throttle value even when the player intends neither pedal
## held.
const THROTTLE_EPSILON: float = 0.01

## Upward offsets (metres above `_last_valid_grounded_position`) tried in order
## when searching for an unobstructed recovery spot. Fixed and finite so the
## search can never hang or loop unboundedly; the last entry doubles as the
## last-resort fallback when every candidate is still blocked.
const RECOVERY_OFFSETS: Array[float] = [1.0, 2.5, 5.0, 10.0]

## Data-driven tuning knobs (max speed, acceleration, steering, drift grip,
## mass). Assign a VehicleStats .tres in the Inspector.
@export var stats: VehicleStats

## Per-device input reader. Not exported — InputSource isn't a Resource,
## so whoever spawns this vehicle assigns it. Defaults to keyboard so the
## node is drivable standalone with no external wiring.
var input_source: InputSource = InputSource.new()

## This frame's raw input snapshot, kept for external readout only (e.g.
## DebugOverlay) — not read back by this script itself.
var last_input: Dictionary[String, Variant] = {}

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

## Previous frame's grounded state — the landing trigger is edge-detected
## (fires on the touchdown frame only, not every frame spent on the ground).
var _was_grounded: bool = false

## Current induced lean, in degrees. Tracked as state and re-applied to the
## mesh's local rotation each frame, so the decay is deterministic and can't
## accumulate the way repeated rotate_x/rotate_z calls would.
var _lean_pitch_deg: float = 0.0
var _lean_roll_deg: float = 0.0

## What triggered the active lean — "landing", "impact", or "" when level.
## Read externally (the debug HUD); not read back by this script.
var _lean_trigger_cause: String = ""

## Previous frame's lateral-contact state — the impact trigger is edge-
## detected separately from `_was_grounded`, so sliding along a wall doesn't
## re-fire the lean every frame of sustained contact.
var _was_lateral_contact: bool = false

## How long (seconds) the current abnormal airborne-and-not-falling state has
## held. Reset to zero by any floor contact or any real airborne motion.
var _stuck_timer: float = 0.0

## Latched once vehicle_stuck has fired for the current episode, so the signal
## is emitted once per stuck event rather than every frame past the threshold.
var _is_stuck: bool = false

## Last position at which the vehicle had valid floor contact. Read back by
## _find_clear_recovery_position() as the basis for the stuck-recovery point.
var _last_valid_grounded_position: Vector3 = Vector3.ZERO

## Current balance tilt, in degrees, from four-corner support raycasts.
## Deliberately separate fields from `_lean_pitch_deg`/`_lean_roll_deg`: the
## lean is an event-triggered one-shot that decays back to level, while this is
## a continuous readout of how much ground is currently under each corner.
## Additively blended with _lean_pitch_deg/_lean_roll_deg at the mesh-rotation
## write below — both sources are already independently rate-limited, so the
## sum is smooth by construction.
var _balance_pitch_deg: float = 0.0
var _balance_roll_deg: float = 0.0

## How many of the four footprint corners had ground under them as of the
## last grounded physics frame — 0 while airborne. Read externally (the
## debug HUD); not read back by this script itself.
var _balance_supported_corners: int = 4

## The four footprint-corner probe origins in the body's local space, ordered
## [front-left, front-right, back-left, back-right]. Computed once in _ready()
## from the collision box's extents — the shape doesn't change at runtime, so
## re-deriving these every physics frame would be wasted work.
var _balance_corner_offsets: Array[Vector3] = []

## Visual-only node the lean rotation is applied to. Never rotate `self` —
## tilting the CharacterBody3D would tilt the collision shape with it and
## feed back into the physics solver.
@onready var _visual_mesh: MeshInstance3D = $MeshInstance3D

## Source of the footprint extents the balance-tilt corner probes are derived
## from. Read once in _ready(), never mutated — see the note above about never
## rotating the collision body.
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Godot's default floor_max_angle (~45°) would silently cap
	# stats.lean_landing_angle_threshold's exported 0-90° range: a touchdown
	# steeper than floor_max_angle is classified as wall contact, so
	# is_on_floor() never becomes true and the landing trigger never fires.
	floor_max_angle = deg_to_rad(80.0)
	# Seed the edge detector so a vehicle spawned already resting on the
	# ground doesn't register a spurious landing on its first physics frame.
	_was_grounded = is_on_floor()
	# Safe to connect here: _ready() runs once, and vehicle_stuck can't fire
	# before the first _physics_process(), so no emission is missed.
	vehicle_stuck.connect(_on_vehicle_stuck)
	# Cached once rather than per physics frame — the collision box's extents are
	# fixed at runtime, so the four corner offsets derived from them are too.
	var half_extents: Vector3
	if _collision_shape.shape is BoxShape3D:
		half_extents = (_collision_shape.shape as BoxShape3D).size / 2.0
	else:
		# Balance tilt assumes a box collider. A future shape swap needs this
		# revisited deliberately rather than silently no-op-ing on garbage
		# extents, so fall back to tophat_car.tscn's box and say so out loud.
		push_warning("VehicleController expects a BoxShape3D for balance-tilt corner raycasts.")
		half_extents = Vector3(0.5, 0.5, 1.0)
	# Forward is -Z and right is +X (see `forward` in _physics_process), so -Z is
	# the front of the car and -X its left. Y is the box's underside, where a
	# downward support probe starts.
	_balance_corner_offsets = [
		Vector3(-half_extents.x, -half_extents.y, -half_extents.z),  # front-left
		Vector3(half_extents.x, -half_extents.y, -half_extents.z),  # front-right
		Vector3(-half_extents.x, -half_extents.y, half_extents.z),  # back-left
		Vector3(half_extents.x, -half_extents.y, half_extents.z),  # back-right
	]


func _physics_process(delta: float) -> void:
	var input: Dictionary[String, Variant] = input_source.get_input()
	last_input = input
	var throttle: float = float(input.get("throttle", 0.0))
	var steer: float = float(input.get("steer", 0.0))
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
	if throttle > THROTTLE_EPSILON:
		current_speed += throttle * stats.acceleration * control_factor * delta
	elif throttle < -THROTTLE_EPSILON:
		current_speed += throttle * stats.braking_force * control_factor * delta
	else:
		current_speed = move_toward(
			current_speed, 0.0, stats.coast_deceleration * control_factor * delta
		)
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

	# --- Steering: yaw rate scales with steer input, how fast we're going
	# (arcade-style — no spinning in place at a standstill), and
	# control_factor (reduced but not zero in the air). Scaled by
	# signf(current_speed) so steer_right always curves the actual path
	# right on screen, forward or reverse — real cars invert this in
	# reverse (turn the wheel right, the nose swings right but the car
	# actually travels left), which reads as broken controls in a casual
	# party game. "Fun > Realism" (docs/design/game-pillars.md) wins here. ---
	var speed_factor: float = clampf(absf(current_speed) / stats.max_speed, 0.0, 1.0)
	var yaw: float = (
		-steer * stats.steering_rate * speed_factor * delta * signf(current_speed) * control_factor
	)
	rotate_y(yaw)

	# --- Gravity ---
	if grounded:
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	# Captured before move_and_slide() because slide resolution strips the
	# collision-normal component out of `velocity` — reading impact speed
	# after the call would report the post-slide remainder, not the speed we
	# actually hit the wall at.
	var pre_slide_velocity: Vector3 = velocity

	move_and_slide()

	# --- Landing lean (edge-detected: only on the touchdown frame) ---
	if is_on_floor() and not _was_grounded:
		var floor_normal: Vector3 = get_floor_normal()
		var touchdown_angle_deg: float = rad_to_deg(floor_normal.angle_to(Vector3.UP))
		if touchdown_angle_deg > stats.lean_landing_angle_threshold:
			var threshold: float = maxf(stats.lean_landing_angle_threshold, 0.01)
			var intensity: float = clampf(
				remap(touchdown_angle_deg, threshold, threshold * 2.0, 0.0, 1.0), 0.0, 1.0
			)
			var local_normal: Vector3 = (
				(global_transform.basis.orthonormalized().inverse() * floor_normal).normalized()
			)
			_lean_pitch_deg = intensity * stats.max_lean_angle * signf(local_normal.z)
			_lean_trigger_cause = "landing"

	# --- Lateral impact lean (edge-detected independently of the landing
	# trigger): a mostly-horizontal collision normal is a wall-like hit
	# rather than floor/ceiling contact. Only a *new* lateral contact fires
	# the lean — grinding along a wall holds `_was_lateral_contact` true and
	# stays quiet. ---
	var has_lateral_contact: bool = false
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) >= 0.5:
			continue
		has_lateral_contact = true
		if _was_lateral_contact:
			continue
		var impact_speed: float = absf(pre_slide_velocity.dot(normal))
		if impact_speed > stats.lean_impact_speed_threshold:
			var threshold: float = maxf(stats.lean_impact_speed_threshold, 0.01)
			var intensity: float = clampf(
				remap(impact_speed, threshold, threshold * 2.0, 0.0, 1.0), 0.0, 1.0
			)
			var local_normal: Vector3 = (
				(global_transform.basis.orthonormalized().inverse() * normal).normalized()
			)
			_lean_roll_deg = intensity * stats.max_lean_angle * signf(local_normal.x)
			_lean_trigger_cause = "impact"
	_was_lateral_contact = has_lateral_contact

	_was_grounded = is_on_floor()

	# --- Stuck detection: a safety net for physics edge cases (tunneling,
	# wedged geometry, multi-body pileups) that task 2's bounded lean clamp
	# doesn't fully rule out. NOT a general "the car stopped moving" detector.
	#
	# It deliberately covers only the airborne-and-not-falling case, matching
	# this task's literal scope: a car wedged against geometry while still
	# grounded (is_on_floor() true) is NOT caught here. That's a known,
	# documented limitation rather than an oversight — advisory review
	# confirmed it matches the task's written spec and raised the grounded-
	# wedged case as a scope question for product/tech-lead, not a defect.
	#
	# `_last_valid_grounded_position` is tracked here and consumed by
	# _on_vehicle_stuck() via _find_clear_recovery_position().
	#
	# is_on_floor() is re-sampled post-slide (like the lean code above) rather
	# than reusing the pre-slide `grounded` local — that one is captured before
	# move_and_slide() for gravity/control purposes and would lag a frame. ---
	if is_on_floor():
		_last_valid_grounded_position = global_position
		_stuck_timer = 0.0
		_is_stuck = false
	elif velocity.length() < STUCK_VELOCITY_THRESHOLD:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME_THRESHOLD and not _is_stuck:
			_is_stuck = true
			vehicle_stuck.emit()
	else:
		_stuck_timer = 0.0

	# --- Continuous balance tilt: unlike the event-triggered lean above, this
	# runs every grounded frame and reflects current corner support, not a
	# one-shot trigger. Fixes a real playtested bug: a car resting on a ledge
	# with only one corner touching stayed perfectly level with zero tilt,
	# because neither the landing nor impact triggers ever fire for a car that
	# was already continuously grounded when it slid into that position.
	#
	# is_on_floor() is re-sampled here post-slide for the same reason the stuck
	# block above re-samples it: the `grounded` local captured near the top of
	# this function is pre-move_and_slide(), scoped to that frame's
	# throttle/steer/gravity math, and would lag a frame if reused here. ---
	var target_balance_pitch_deg: float = 0.0
	var target_balance_roll_deg: float = 0.0
	if is_on_floor():
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var hits: Array[bool] = []
		for offset: Vector3 in _balance_corner_offsets:
			var origin: Vector3 = global_transform * offset
			var query := PhysicsRayQueryParameters3D.create(
				origin, origin + Vector3.DOWN * stats.balance_raycast_probe_distance, 1, [get_rid()]
			)
			hits.append(not space_state.intersect_ray(query).is_empty())
		_balance_supported_corners = hits.count(true)
		# Corner order from _balance_corner_offsets: [front-left, front-right,
		# back-left, back-right].
		#
		# The collision_mask 1 above mirrors the body's own collision_mask, which
		# assumes physics layer 1 is solid ground only. If a one-way platform or
		# a non-solid trigger volume is ever placed on layer 1 it would register
		# as support even though the body isn't really resting on it; revisit
		# this mask choice deliberately if that ever happens rather than treating
		# it as a given.
		var front_support: float = (int(hits[0]) + int(hits[1])) / 2.0
		var rear_support: float = (int(hits[2]) + int(hits[3])) / 2.0
		var left_support: float = (int(hits[0]) + int(hits[2])) / 2.0
		var right_support: float = (int(hits[1]) + int(hits[3])) / 2.0
		# Sign convention, verified empirically against the mesh rotation these
		# degrees are destined for rather than derived on paper: a positive
		# rotation about local X pitches the nose *up* and a positive rotation
		# about local Z rolls the *right* side up. The car should sag toward
		# whichever corners have nothing under them, so losing front support has
		# to drive pitch negative (nose down) and losing right support has to
		# drive roll negative (right side down) — hence front-minus-rear, and
		# right-minus-left.
		var pitch_intensity: float = clampf(front_support - rear_support, -1.0, 1.0)
		var roll_intensity: float = clampf(right_support - left_support, -1.0, 1.0)
		target_balance_pitch_deg = pitch_intensity * stats.max_balance_tilt_angle
		target_balance_roll_deg = roll_intensity * stats.max_balance_tilt_angle
	else:
		_balance_supported_corners = 0
	var balance_step: float = stats.balance_tilt_response_rate * delta
	_balance_pitch_deg = move_toward(_balance_pitch_deg, target_balance_pitch_deg, balance_step)
	_balance_roll_deg = move_toward(_balance_roll_deg, target_balance_roll_deg, balance_step)

	# --- Self-correction: every frame, triggered or not, the lean decays
	# back to level at a fixed rate — "hard to trigger, always self-
	# corrects." A full max_lean_angle deflection takes exactly
	# lean_correction_duration seconds to unwind. ---
	var decay_step: float = (stats.max_lean_angle / stats.lean_correction_duration) * delta
	_lean_pitch_deg = move_toward(_lean_pitch_deg, 0.0, decay_step)
	_lean_roll_deg = move_toward(_lean_roll_deg, 0.0, decay_step)
	if is_zero_approx(_lean_pitch_deg) and is_zero_approx(_lean_roll_deg):
		_lean_trigger_cause = ""

	# Overwrite (never accumulate) the visual node's local rotation from the
	# tracked degrees — rotate_x/rotate_z would compound frame over frame.
	#
	# Additive blend with the continuous balance tilt computed above: both
	# sources are already independently rate-limited (event lean decays via
	# move_toward, balance tilt smooths via move_toward), so their sum is smooth
	# by construction — no seam, no cross-fade needed. Semantically correct too:
	# a hard landing onto a precarious edge should read as both "just got hit"
	# and "resting badly," and as the event lean decays away what remains is
	# exactly the correct resting-state tilt. Left deliberately unclamped on the
	# combined sum (each source is already independently clamped via its own
	# max_*_angle stat) — ship as-is, flagged for a visual clipping check
	# against the actual mesh at combined extremes during hand-feel testing
	# rather than pre-building an unneeded clamp.
	_visual_mesh.rotation = Vector3(
		deg_to_rad(_lean_pitch_deg + _balance_pitch_deg),
		0.0,
		deg_to_rad(_lean_roll_deg + _balance_roll_deg)
	)


## Picks an unobstructed point above `_last_valid_grounded_position` to recover
## to.
##
## The naive choice — `_last_valid_grounded_position + Vector3(0, 1, 0)` — can
## drop the vehicle straight back into whatever geometry wedged it in the first
## place (a low overhang is the obvious case: the last grounded position is
## *under* it, so +1m is still inside it). That re-triggers stuck detection
## immediately and the vehicle ping-pongs between stuck and "recovered" forever.
##
## So each candidate is probed before it's used. A zero-motion `test_move()`
## with `recovery_as_collision` explicitly `true` reports whether a transform is
## *already* overlapping a collider — verified against Godot 4.7.2: with the
## default `false`, a zero-distance test returns false even when deeply
## embedded, silently missing exactly the case this guards against.
##
## The offset list is fixed and finite, so this always terminates. If every
## candidate is blocked, the largest offset is returned anyway — still strictly
## better than the unchecked +1m, and it keeps the search bounded.
func _find_clear_recovery_position() -> Vector3:
	var base: Vector3 = _last_valid_grounded_position
	for offset_y: float in RECOVERY_OFFSETS:
		var candidate: Vector3 = base + Vector3(0.0, offset_y, 0.0)
		var candidate_transform := Transform3D(global_transform.basis, candidate)
		if not test_move(candidate_transform, Vector3.ZERO, null, 0.001, true):
			return candidate
	return base + Vector3(0.0, RECOVERY_OFFSETS[-1], 0.0)


## Recovers the vehicle after a stuck episode: reposition near the last valid
## ground, kill momentum, level the lean, and re-arm stuck detection so a
## subsequent episode can fire again.
##
## Note that `is_on_floor()` is NOT refreshed by writing `global_position`
## directly — it still reflects the `move_and_slide()` result from earlier this
## frame. That's fine here: that result was already `false` (it's why the stuck
## path fired at all), which is consistent with the vehicle being airborne
## immediately after being lifted clear of the ground.
##
## `_visual_mesh.rotation` is deliberately not written here. This signal is
## emitted synchronously from mid-`_physics_process()`, and the lean-decay block
## further down that same call overwrites the mesh rotation from
## `_lean_pitch_deg`/`_lean_roll_deg` moments later — a write here would be dead
## code, clobbered with the identical value in the same frame.
func _on_vehicle_stuck() -> void:
	global_position = _find_clear_recovery_position()
	velocity = Vector3.ZERO
	_lean_pitch_deg = 0.0
	_lean_roll_deg = 0.0
	_lean_trigger_cause = ""
	_stuck_timer = 0.0
	_is_stuck = false


## Public entry point for the debug hotkey (scripts/ui/debug_overlay.gd) to
## force a recovery on demand, without polling Input itself here (Architecture
## Decision 01). Identical to what vehicle_stuck firing naturally would do.
func force_recovery() -> void:
	_on_vehicle_stuck()
