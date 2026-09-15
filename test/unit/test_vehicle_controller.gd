extends GdUnitTestSuite

## Real behavioral coverage for VehicleController (STATE.md's Next Recommended
## Tasks item 8), replacing reliance on the boot-only smoke test in
## test/integration/test_main.gd.
##
## Input is driven through the scene_runner's simulate_action_press()/
## simulate_action_release(), the same pattern test/integration/test_main.gd
## uses for scene_runner()/simulate_frames(). Under the hood
## GdUnitSceneRunnerImpl calls Input.action_press("throttle", 1.0) /
## Input.action_release("throttle") on the shared global action map
## (see addons/gdUnit4/src/core/GdUnitSceneRunnerImpl.gd:126-143,554-561) —
## which is exactly the action map InputSource._get_input_from_action_map()
## reads via Input.get_action_strength()/is_action_pressed() for the default
## keyboard device (input_source.gd:66-75). That means this exercises the
## real keyboard InputSource code path end to end with no fake/stub needed,
## and is more reliable under scene_runner than calling global
## Input.action_press() directly, since the runner also tracks and
## auto-releases any action left pressed when it is disposed
## (GdUnitSceneRunnerImpl.gd:592-608). We still explicitly release the
## action at the end of every test as a belt-and-suspenders guard against
## state leaking into the next test case, per this project's convention of
## deterministic per-test cleanup.

const TOPHAT_CAR_SCENE := "res://scenes/vehicles/tophat_car.tscn"

## 3 seconds at the default 60 Hz physics tick — comfortably past
## stats.max_speed / stats.acceleration (~1.7s for the Stovepipe Speedster)
## so the clamp in vehicle_controller.gd is actually exercised, not just
## the ramp-up.
const THROTTLE_FRAMES := 180

## --- Induced lean: landing tilt + lateral impact -----------------------------
##
## The cases below exercise vehicle_controller.gd's lean block end to end: the
## edge-detected landing trigger, the independently edge-detected lateral-impact
## trigger, the intensity clamp at stats.max_lean_angle, and the per-frame
## move_toward() decay back to level.
##
## Three design choices here replace approaches that looked simpler but were
## actually wrong, so each is worth explaining:
##
## 1. Every lean case builds its VehicleStats in code (_make_test_stats) rather
##    than reading the scene's stovepipe_speedster.tres. That .tres overrides
##    none of the lean fields today, so it silently inherits vehicle_stats.gd's
##    script defaults — values a designer is free to retune at any time. Pinning
##    the thresholds here means a balance pass can never quietly turn a
##    "triggers above threshold" case into a no-op that still reports green.
##
## 2. Frames are stepped as *physics* frames (_simulate_physics_frames), not via
##    runner.simulate_frames(). simulate_frames() awaits process_frame
##    (GdUnitSceneRunnerImpl.gd:411-418), and how many fixed-delta physics ticks
##    the engine accumulates per process frame is a function of wall-clock time —
##    measured here at roughly 0.43 ticks per process frame, drifting with
##    machine load. Awaiting physics_frame yields exactly one physics step per
##    await, which makes the whole simulation a pure function of the tick count.
##    That is what lets the reproducibility cases assert *bit-exact* equality
##    between two independent runs instead of settling for an approximation.
##
## 3. Each case parks its car in its own lane along +X (_prepare_car). The runner
##    parents the scene to the scene-tree *root*, so the StaticBody3D that
##    _add_floor_under() adds as a sibling outlives its runner and stays in the
##    tree for every later test in this file. A car dropped at the origin
##    therefore lands on a leftover flat floor from an earlier case instead of
##    the tilted slab under test. Lane separation makes each case immune to that;
##    the lean helpers below additionally auto_free() their bodies so these cases
##    do not leak the same way.

## Spacing between per-test car lanes along +X. Wider than the 200-unit flat
## floor and the 40-unit tilted slab, so no two cases can ever share geometry —
## and wide enough that lane 1 clears the ±100 footprint of the leftover floors
## the throttle cases above leave parked at the origin.
const LEAN_LANE_SPACING := 500.0

## Height above the car's spawn point at which a tilted slab is parked, so the
## car genuinely free-falls onto it. Deliberately generous rather than a
## computed near-zero gap: the offset math for "how far below a *tilted* box's
## centre is its surface, at this X/Z" is easy to get subtly wrong, and a real
## fall sidesteps the question entirely.
const LEAN_DROP_HEIGHT := 5.0

## Physics ticks from scene start at which a ±30° landing case is sampled.
##
## Fixed rather than "loop until the edge fires, then read", because the lean is
## a *transient*: the trigger frame sets it and the very same frame's decay step
## starts unwinding it. A wait-for-it loop would read whatever value happened to
## survive scheduling jitter. Empirically the 30° drop touches down on tick 50
## (pitch 9.33 after that frame's own decay) and reaches level on tick 64, so 55
## sits mid-window with ~5 ticks of slack on either side.
const LEAN_LANDING_TRIGGER_FRAMES := 55

## Ticks to run a landing case that must *not* trigger, or whose clamped peak is
## being tracked. Comfortably past the shallowest touchdown measured here (tick
## 53) so "no lean" means "landed and stayed level", not "never landed".
const LEAN_LANDING_SETTLE_FRAMES := 90

## Where the impact wall sits relative to the car, and how far it is yawed.
##
## The yaw is the load-bearing part. _physics_process re-derives flat velocity as
## `forward * forward_speed` on every grounded frame, so any lateral component
## assigned to `velocity` is projected away before the car has moved — a car on
## the ground can only travel along its own forward axis. A wall square to that
## axis therefore yields a collision normal with *zero* local X, and roll sign is
## driven by signf(local_normal.x). Yawing the wall is what puts a real X
## component in the normal while leaving the car's basis untouched.
const LEAN_WALL_OFFSET := Vector3(0.0, 0.0, -4.0)
const LEAN_WALL_YAW_DEG := 30.0

## Approach speeds for the impact cases, in m/s along the car's forward axis.
## Only the component along the wall normal counts toward the threshold, so the
## effective impact speed is these times cos(LEAN_WALL_YAW_DEG): 6.93 (over the
## 5.0 threshold), 3.46 (under it), and 17.3 (far enough over that the intensity
## remap saturates and the clamp has to do real work).
const LEAN_IMPACT_SPEED := 8.0
const LEAN_IMPACT_SPEED_BELOW_THRESHOLD := 4.0
const LEAN_IMPACT_SPEED_OVERDRIVEN := 20.0

## Physics ticks at which an impact case is sampled — same transient-window
## reasoning as LEAN_LANDING_TRIGGER_FRAMES. Contact lands on tick 16 (roll 7.05
## after that frame's decay) and levels off by tick 27.
const LEAN_IMPACT_TRIGGER_FRAMES := 20

## Ticks to run an impact case that must not trigger, or whose clamped peak is
## being tracked — well past the tick-16 contact of the fastest case and past the
## slower approach of the below-threshold one.
const LEAN_IMPACT_SETTLE_FRAMES := 80

## --- Stuck detection + recovery ----------------------------------------------
##
## The cases at the bottom of this file exercise vehicle_controller.gd's stuck
## block (the timer gate and the one-shot vehicle_stuck emission) together with
## _on_vehicle_stuck()'s recovery. Three properties of that code shape every
## choice below and are worth stating once rather than re-deriving per case:
##
## 1. Recovery is *synchronous*. _ready() connects _on_vehicle_stuck to
##    vehicle_stuck, so the handler runs inside the very same _physics_process()
##    call that emits — by the time any later frame is observed, _stuck_timer and
##    _is_stuck have already been reset to their idle values by the recovery
##    itself. Polling for "_is_stuck became true" can therefore never succeed.
##    These cases instead attach their own listener and step one tick at a time,
##    so the first frame after the emission is read directly.
##
## 2. The abnormal state the detector looks for is airborne-and-not-falling
##    (`not is_on_floor() and velocity.length() < STUCK_VELOCITY_THRESHOLD`).
##    Reproducing that needs no wedge geometry at all: park the car in open air
##    and zero its velocity after every tick, cancelling that tick's gravity
##    accumulation before it can grow past the 0.5 m/s threshold. A real wedge
##    would add a large, fragile collider whose only contribution is the same two
##    facts this achieves directly.
##
## 3. _last_valid_grounded_position only advances while is_on_floor() is true and
##    otherwise sits at its Vector3.ZERO default, so a car that has never touched
##    ground would "recover" to the world origin and prove nothing. Every case
##    lands on a real floor first, captures where that left the tracked position,
##    and only then lifts off — straight up, staying over the same floor, so the
##    recovery target below is genuinely clear and the first RECOVERY_OFFSETS
##    entry is the one that wins.

## How far straight up a landed car is lifted to stage the stuck state. Far
## enough that is_on_floor() reads false immediately (well past the 0.1 default
## floor_snap_length) with room to spare for the ~0.3 units the car still creeps
## down over the hold, and far enough above the recovery target that arriving
## there is unambiguous.
const STUCK_LIFT_HEIGHT := 8.0

## Ticks allowed for the car to drop the ~0 units onto its flat floor and settle.
## Generous rather than minimal — the only thing riding on it is that
## _last_valid_grounded_position has been written at least once.
const STUCK_LANDING_FRAMES := 30

## Safety cap on the hold loop. Roughly twice the ~105 ticks
## STUCK_TIME_THRESHOLD needs at 60 Hz, so a regression that stops the signal
## firing fails the assertion in under four seconds instead of hanging the suite.
const STUCK_MAX_HOLD_FRAMES := 200

## Lean deflection (degrees) held artificially across the stuck hold, for the
## case that checks recovery levels the car out. It has to be re-applied every
## tick: the controller's own decay would otherwise unwind any one-off value long
## before the 105-tick timer elapses, leaving nothing for the reset to clear.
const STUCK_LEAN_HOLD_DEG := 10.0

## --- Balance tilt: continuous corner support -----------------------------------
##
## Unlike the event-triggered lean above, balance tilt is a live function of
## current support and re-evaluates every grounded tick — there is no edge to
## wait for. Two things shape every case below:
##
## 1. _add_floor_under's near-zero drop (the flat floor sits with its top face
##    essentially flush with the car's underside at spawn, per its own doc
##    comment) means "landed" happens almost immediately; the frame budget here
##    is mostly for the tilt's own move_toward smoothing to reach its target
##    (balance_tilt_response_rate=60 deg/sec, max_balance_tilt_angle=15 deg, so
##    a full-intensity target takes 15/60=0.25s=15 ticks to reach), not for
##    falling.
##
## 2. The partial-support case needs a floor that covers only the REAR half of
##    the car's footprint (local Z >= 0 — forward is -Z, so the front corners
##    sit at local Z=-1.0 and the rear at Z=+1.0 on this project's 1x1x2
##    collision box) while leaving the front two corners over open air. A
##    second flat, wide (200-unit X, same as _add_floor_under) slab whose near
##    edge lands exactly at the car's spawn Z accomplishes this without needing
##    the tilted-slab machinery above — this floor is deliberately flat, only
##    positioned so half of it isn't there.

## Ticks to land (near-instant per note 1) plus reach a full-intensity balance
## target, plus margin against a tick or two of touchdown wobble before the
## smoothing has something settled to converge on.
const BALANCE_SETTLE_FRAMES := 60


## Ground control (accel/brake/drift/steer) only runs while is_on_floor()
## is true — a deliberate fix so the car falls ballistically off a ramp
## instead of having its velocity re-snapped to the current facing every
## frame while airborne. Tests that exercise ground behavior need an
## actual floor under the standalone car instance, or is_on_floor() is
## always false and throttle correctly does nothing.
func _add_floor_under(car: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(200, 1, 200)
	floor_body.add_child(shape)
	floor_body.position = car.global_position + Vector3(0, -1.0, 0)
	car.get_parent().add_child(floor_body)


## Hand-picked stats for the lean cases. Every value is explicit so no assertion
## below depends on a future balance pass; see design note 1 above. The first
## seven are plausible-but-unexercised defaults — only the four lean fields
## actually drive these tests.
func _make_test_stats() -> VehicleStats:
	var stats := VehicleStats.new()
	stats.max_speed = 30.0
	stats.acceleration = 15.0
	stats.braking_force = 25.0
	# Zeroed, not left at the VehicleStats script default: these lean/impact
	# cases assign velocity directly and rely on it staying constant absent
	# throttle input to reach the wall/floor at a known speed. A nonzero
	# coast_deceleration (added for unrelated cruise-control-feel work) would
	# bleed that speed off before contact and silently shrink the margin
	# between LEAN_IMPACT_SPEED and lean_impact_speed_threshold.
	stats.coast_deceleration = 0.0
	stats.steering_rate = 2.5
	stats.drift_grip = 0.6
	stats.mass = 1000.0
	stats.air_control = 0.35
	stats.max_lean_angle = 20.0
	stats.lean_landing_angle_threshold = 20.0
	stats.lean_impact_speed_threshold = 5.0
	stats.lean_correction_duration = 0.5
	# Pinned for the same reason as everything above, even though these match the
	# VehicleStats script defaults today: the balance-tilt cases assert against a
	# specific clamp magnitude and a specific smoothing rate, and inheriting those
	# from a file a designer is free to retune would let a balance pass silently
	# turn a bounded-tilt assertion into one that never reaches its target.
	stats.max_balance_tilt_angle = 15.0
	stats.balance_raycast_probe_distance = 0.5
	stats.balance_tilt_response_rate = 60.0
	return stats


## Moves a freshly-instantiated car into its own lane and pins its stats, before
## a single physics tick has run. scene_runner() adds the scene synchronously and
## never awaits, so _ready() has fired but _physics_process() has not — which is
## exactly the window in which the stats swap is still invisible to the vehicle.
func _prepare_car(runner: GdUnitSceneRunner, lane: int) -> VehicleController:
	var car: VehicleController = runner.scene()
	car.global_position = Vector3(lane * LEAN_LANE_SPACING, 0.0, 0.0)
	car.stats = _make_test_stats()
	return car


## Drops a tilted slab `drop_height` below the car for it to free-fall onto.
##
## The slab is bounded to 8 units along Z on purpose. The flat floor helper's
## 200x200 box works because a flat box never rises; rotate that same box about
## X by 30° and its far edge climbs 50 units, swallowing the car whole so
## is_on_floor() is true on tick 1 and nothing ever falls. 8 units of Z means the
## slab's high edge stays below the car's underside for every tilt used here.
func _add_tilted_floor_under(car: Node3D, tilt_deg: float, drop_height: float) -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(40, 1, 8)
	floor_body.add_child(shape)
	floor_body.position = car.global_position + Vector3(0, -drop_height, 0)
	floor_body.rotation = Vector3(deg_to_rad(tilt_deg), 0.0, 0.0)
	car.get_parent().add_child(floor_body)


## Parks a wall slab at `offset` from the car, yawed `yaw_deg` about Y so its
## face meets the car's forward axis obliquely — see LEAN_WALL_YAW_DEG for why
## the angle is mandatory rather than decorative. Tall enough (6 units) that the
## car can only ever reach its vertical face, never its top or bottom cap, so the
## controller's abs(normal.y) < 0.5 lateral filter always accepts the contact.
func _add_wall(car: Node3D, offset: Vector3, yaw_deg: float) -> void:
	var wall_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20, 6, 1)
	wall_body.add_child(shape)
	wall_body.position = car.global_position + offset
	wall_body.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	car.get_parent().add_child(wall_body)


## Advances exactly `count` fixed-delta physics steps — the deterministic
## stepping described in design note 2 above.
func _simulate_physics_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().physics_frame


## Ticks needed for a full-deflection lean to unwind, plus margin. The bare
## product is the theoretical minimum and leaves no room for the trigger landing
## a frame or two later than expected, so five ticks are added on top.
func _decay_frames(stats: VehicleStats) -> int:
	return ceili(stats.lean_correction_duration * 60.0) + 5


## Runs one landing scenario to a fixed tick count and reports the pitch it was
## holding at that instant. Split out so the reproducibility and sign cases can
## build two independent runs from identical code instead of two hand-copied
## blocks that might drift apart.
func _measure_landing_pitch(lane: int, tilt_deg: float, frames: int) -> float:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, lane)
	_add_tilted_floor_under(car, tilt_deg, LEAN_DROP_HEIGHT)
	await _simulate_physics_frames(frames)
	return car._lean_pitch_deg


## Impact-side twin of _measure_landing_pitch: drives the car into a yawed wall
## on flat ground and reports the roll held at `frames`.
func _measure_impact_roll(lane: int, yaw_deg: float, speed: float, frames: int) -> float:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, lane)
	_add_floor_under(car)
	_add_wall(car, LEAN_WALL_OFFSET, yaw_deg)
	car.velocity = Vector3(0.0, 0.0, -speed)
	await _simulate_physics_frames(frames)
	return car._lean_roll_deg


## Stages a stuck episode's preconditions: drops `car` onto a fresh flat floor,
## lets it settle so _last_valid_grounded_position is written from a real
## touchdown, then lifts it straight up into open air with its momentum killed.
## Returns the grounded position the controller actually recorded, which is what
## the recovery assertions are measured against.
##
## The tracked value is read back rather than reconstructed from
## car.global_position: the two agree here, but only one of them is the input
## _find_clear_recovery_position() will use, and asserting against the other
## would silently pass if the tracking ever stopped following the car.
func _land_then_lift(car: VehicleController) -> Vector3:
	_add_floor_under(car)
	await _simulate_physics_frames(STUCK_LANDING_FRAMES)
	# Without this the lift below would be staging a car that never landed, and
	# every recovery assertion would be measured against Vector3.ZERO.
	assert_bool(car.is_on_floor()).is_true()
	var landed: Vector3 = car._last_valid_grounded_position
	car.global_position += Vector3(0.0, STUCK_LIFT_HEIGHT, 0.0)
	car.velocity = Vector3.ZERO
	return landed


## Holds an already-lifted `car` in the airborne-and-not-falling state, one
## physics tick at a time, until vehicle_stuck fires. Returns the 1-based tick on
## which it fired, or -1 if it never did within `max_frames`.
##
## Two details are load-bearing:
##
## - The listener writes through a single-element Array, not a plain bool.
##   GDScript lambdas capture their enclosing locals *by value*, so assigning to
##   a captured bool would update the lambda's private copy and the loop would
##   spin to the cap forever. An Array's value is a reference, so the mutation is
##   visible here.
##
## - The loop stops *before* re-zeroing velocity on the tick the signal fired.
##   Recovery runs synchronously inside that same tick and sets velocity itself;
##   zeroing it again afterwards would make the caller's velocity assertion pass
##   whether or not the controller ever did its job.
##
## `lean_hold_deg`, when non-zero, re-applies a lean deflection at the top of
## every tick so a non-zero lean is still standing when recovery fires — see
## STUCK_LEAN_HOLD_DEG.
func _hold_until_stuck(car: VehicleController, max_frames: int, lean_hold_deg := 0.0) -> int:
	var fired: Array[bool] = [false]
	car.vehicle_stuck.connect(func() -> void: fired[0] = true)

	for frame in range(max_frames):
		if not is_zero_approx(lean_hold_deg):
			car._lean_pitch_deg = lean_hold_deg
			car._lean_roll_deg = lean_hold_deg
			car._lean_trigger_cause = "landing"
		await _simulate_physics_frames(1)
		if fired[0]:
			return frame + 1
		# Cancels this tick's gravity accumulation before it can climb past
		# STUCK_VELOCITY_THRESHOLD — the whole "wedged" simulation, per design
		# note 2 in the stuck section above.
		car.velocity = Vector3.ZERO

	return -1


## Ticks the stuck timer needs at the default 60 Hz physics rate. Derived from
## the controller's own constant so a retune there can never leave these cases
## asserting against a stale number.
func _stuck_threshold_frames() -> int:
	return floori(VehicleController.STUCK_TIME_THRESHOLD * 60.0)


func test_loads_without_error() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()

	assert_object(car).is_instanceof(VehicleController)
	assert_object(car.stats).is_instanceof(VehicleStats)
	assert_object(car.stats).is_not_null()


func test_accelerates_under_throttle_and_respects_max_speed() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()
	_add_floor_under(car)
	var start_position: Vector3 = car.global_position

	runner.simulate_action_press("throttle")
	await runner.simulate_frames(THROTTLE_FRAMES)

	var forward: Vector3 = -car.global_transform.basis.z
	var flat_velocity: Vector3 = Vector3(car.velocity.x, 0.0, car.velocity.z)
	var forward_speed: float = flat_velocity.dot(forward)

	# Moved forward from the start position (horizontal plane only —
	# ground control (and therefore this whole test) requires
	# is_on_floor(), so a floor is added under the car above).
	var flat_displacement: Vector3 = Vector3(
		car.global_position.x - start_position.x, 0.0, car.global_position.z - start_position.z
	)
	assert_float(flat_displacement.length()).is_greater(0.0)

	# Actually accelerated, and never exceeds the configured cap — this is
	# the clampf(...) in vehicle_controller.gd's _physics_process actually
	# doing its job.
	assert_float(forward_speed).is_greater(0.0)
	assert_float(forward_speed).is_less_equal(car.stats.max_speed)

	runner.simulate_action_release("throttle")


func test_no_nan_or_inf_during_sustained_throttle() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car: VehicleController = runner.scene()

	runner.simulate_action_press("throttle")
	await runner.simulate_frames(THROTTLE_FRAMES)

	var position: Vector3 = car.global_position
	var velocity: Vector3 = car.velocity

	assert_bool(is_finite(position.x)).is_true()
	assert_bool(is_finite(position.y)).is_true()
	assert_bool(is_finite(position.z)).is_true()
	assert_bool(is_finite(velocity.x)).is_true()
	assert_bool(is_finite(velocity.y)).is_true()
	assert_bool(is_finite(velocity.z)).is_true()

	runner.simulate_action_release("throttle")


func test_landing_lean_triggers_above_threshold_and_is_reproducible() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 1)
	# 30° clears the 20° landing threshold, and stays well under the ~60° point
	# at which a floor normal would also satisfy the impact path's
	# abs(normal.y) < 0.5 filter — above that the two triggers overlap and a
	# "landing" case could actually be measuring an impact.
	_add_tilted_floor_under(car, 30.0, LEAN_DROP_HEIGHT)

	await _simulate_physics_frames(LEAN_LANDING_TRIGGER_FRAMES)

	assert_float(car._lean_pitch_deg).is_not_zero()
	assert_str(car._lean_trigger_cause).is_equal("landing")
	assert_float(absf(car._lean_pitch_deg)).is_less_equal(car.stats.max_lean_angle + 0.01)

	# Reproducibility: an identical scenario, stepped the identical number of
	# fixed-delta physics ticks, must land on the *same float*. Godot's physics
	# is deterministic for identical initial conditions on a single physics
	# thread, so bit-exact equality is the correct expectation — asserting only
	# "approximately equal" here would hide exactly the drift this case exists
	# to catch. The second run uses lane 2 because both scenes are alive at once.
	#
	# The comparison value is captured now, before the second run starts —
	# get_tree().physics_frame is one clock shared by every live scene, so
	# awaiting frames for the second car's drop also advances this first car's
	# physics (it keeps decaying) rather than leaving it untouched. Reading
	# car._lean_pitch_deg fresh after the second run would compare against a
	# value that has since decayed toward zero, not the one actually being
	# reproduced.
	var first_pitch: float = car._lean_pitch_deg
	var repeat_pitch: float = await _measure_landing_pitch(2, 30.0, LEAN_LANDING_TRIGGER_FRAMES)
	assert_float(repeat_pitch).is_equal(first_pitch)


func test_landing_lean_sign_flips_with_opposite_tilt() -> void:
	# Both signs are measured fresh and compared to *each other*. Hard-coding
	# "a +30° slope pitches the car positive" would bake in an assumption about
	# tophat_car.tscn's spawn orientation that no assertion here can justify;
	# what the mechanic actually promises is that mirrored terrain mirrors the
	# lean, and that is a relative claim.
	var pitch_positive_tilt: float = await _measure_landing_pitch(
		3, 30.0, LEAN_LANDING_TRIGGER_FRAMES
	)
	var pitch_negative_tilt: float = await _measure_landing_pitch(
		4, -30.0, LEAN_LANDING_TRIGGER_FRAMES
	)

	# Guard the comparison first: signf(0.0) is 0.0, so two untriggered runs
	# would otherwise satisfy "same sign" and pass vacuously.
	assert_float(pitch_positive_tilt).is_not_zero()
	assert_float(pitch_negative_tilt).is_not_zero()
	assert_float(signf(pitch_positive_tilt)).is_equal(-signf(pitch_negative_tilt))


func test_landing_below_threshold_does_not_trigger_lean() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 5)
	# 10° is under the 20° threshold, so the touchdown is classified as clean.
	_add_tilted_floor_under(car, 10.0, LEAN_DROP_HEIGHT)

	await _simulate_physics_frames(LEAN_LANDING_SETTLE_FRAMES)

	# Assert the car actually landed before asserting it stayed level —
	# otherwise a car that missed the slab entirely and is still falling would
	# report zero lean and pass for the wrong reason.
	assert_bool(car.is_on_floor()).is_true()
	assert_float(car._lean_pitch_deg).is_equal_approx(0.0, 0.0001)
	assert_str(car._lean_trigger_cause).is_empty()


func test_landing_lean_clamps_at_max_angle() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 6)
	# 50° against a 20°/40° remap band drives raw intensity to 1.5 — i.e. 30°
	# of pitch if the clamp were missing. Still under the impact filter's ~60°
	# crossover and under the controller's 80° floor_max_angle, so this is
	# unambiguously a landing.
	_add_tilted_floor_under(car, 50.0, LEAN_DROP_HEIGHT)

	# The peak is tracked across the window rather than sampled at one tick: the
	# clamp's job is to bound the lean at *every* instant, and a single sample
	# could only ever miss a momentary overshoot.
	var peak_pitch := 0.0
	for _frame in range(LEAN_LANDING_SETTLE_FRAMES):
		await _simulate_physics_frames(1)
		peak_pitch = maxf(peak_pitch, absf(car._lean_pitch_deg))

	assert_float(peak_pitch).is_less_equal(car.stats.max_lean_angle + 0.01)
	# And the clamp was genuinely reached, not merely never approached — without
	# this the assertion above would pass on a car that never leaned at all.
	assert_float(peak_pitch).is_greater(car.stats.max_lean_angle * 0.9)


func test_landing_lean_decays_to_level() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 7)
	_add_tilted_floor_under(car, 30.0, LEAN_DROP_HEIGHT)

	await _simulate_physics_frames(LEAN_LANDING_TRIGGER_FRAMES)
	assert_float(car._lean_pitch_deg).is_not_zero()
	assert_str(car._lean_trigger_cause).is_equal("landing")

	await _simulate_physics_frames(_decay_frames(car.stats))

	assert_float(car._lean_pitch_deg).is_equal_approx(0.0, 0.0001)
	assert_str(car._lean_trigger_cause).is_empty()


func test_impact_lean_triggers_above_threshold_and_is_reproducible() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 8)
	# Flat floor, not a drop: is_on_floor() is true from the first tick to the
	# last, so the landing edge (is_on_floor() and not _was_grounded) can never
	# fire and whatever lean shows up is unambiguously the impact path's.
	_add_floor_under(car)
	_add_wall(car, LEAN_WALL_OFFSET, LEAN_WALL_YAW_DEG)
	# Velocity is assigned directly rather than driven by holding throttle: a
	# throttle ramp would make the speed at contact a function of how far the
	# wall happens to be, which is precisely the coupling that makes such a test
	# fragile to retune.
	car.velocity = Vector3(0.0, 0.0, -LEAN_IMPACT_SPEED)

	await _simulate_physics_frames(LEAN_IMPACT_TRIGGER_FRAMES)

	assert_float(car._lean_roll_deg).is_not_zero()
	assert_str(car._lean_trigger_cause).is_equal("impact")
	assert_float(absf(car._lean_roll_deg)).is_less_equal(car.stats.max_lean_angle + 0.01)

	# Captured before the second run starts — see the matching note in
	# test_landing_lean_triggers_above_threshold_and_is_reproducible: the
	# physics clock is shared across every live scene, so the second car's
	# drive-in keeps decaying this first car's roll too.
	var first_roll: float = car._lean_roll_deg
	var repeat_roll: float = await _measure_impact_roll(
		9, LEAN_WALL_YAW_DEG, LEAN_IMPACT_SPEED, LEAN_IMPACT_TRIGGER_FRAMES
	)
	assert_float(repeat_roll).is_equal(first_roll)


func test_impact_lean_sign_flips_with_opposite_side() -> void:
	# Mirroring the wall's yaw mirrors which side of the car the oblique face
	# presents, and therefore flips the sign of the collision normal's local X
	# component — the term signf() reads to pick the roll direction. As with the
	# landing sign case, the claim asserted is relative, never absolute.
	var roll_wall_right: float = await _measure_impact_roll(
		10, LEAN_WALL_YAW_DEG, LEAN_IMPACT_SPEED, LEAN_IMPACT_TRIGGER_FRAMES
	)
	var roll_wall_left: float = await _measure_impact_roll(
		11, -LEAN_WALL_YAW_DEG, LEAN_IMPACT_SPEED, LEAN_IMPACT_TRIGGER_FRAMES
	)

	assert_float(roll_wall_right).is_not_zero()
	assert_float(roll_wall_left).is_not_zero()
	assert_float(signf(roll_wall_right)).is_equal(-signf(roll_wall_left))


func test_impact_below_threshold_does_not_trigger_lean() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 12)
	_add_floor_under(car)
	_add_wall(car, LEAN_WALL_OFFSET, LEAN_WALL_YAW_DEG)
	# 4.0 m/s along forward is only 3.46 m/s into the yawed face — under the
	# 5.0 threshold, so contact happens but induces nothing.
	car.velocity = Vector3(0.0, 0.0, -LEAN_IMPACT_SPEED_BELOW_THRESHOLD)

	await _simulate_physics_frames(LEAN_IMPACT_SETTLE_FRAMES)

	# Prove the car was actually stopped by the wall first. Unobstructed it
	# would have travelled 4 m/s * 80 ticks / 60 Hz = 5.33 units down -Z; being
	# short of -3.0 means the wall is doing its job and this is a real
	# below-threshold contact rather than a car that never arrived.
	assert_float(car.global_position.z).is_greater(-3.0)
	assert_float(car._lean_roll_deg).is_equal_approx(0.0, 0.0001)
	assert_str(car._lean_trigger_cause).is_empty()


func test_impact_lean_clamps_at_max_angle() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 13)
	_add_floor_under(car)
	_add_wall(car, LEAN_WALL_OFFSET, LEAN_WALL_YAW_DEG)
	# 20 m/s forward is 17.3 m/s into the face, against a 5.0/10.0 remap band —
	# raw intensity 2.46, i.e. 49° of roll with the clamp removed.
	car.velocity = Vector3(0.0, 0.0, -LEAN_IMPACT_SPEED_OVERDRIVEN)

	var peak_roll := 0.0
	for _frame in range(LEAN_IMPACT_SETTLE_FRAMES):
		await _simulate_physics_frames(1)
		peak_roll = maxf(peak_roll, absf(car._lean_roll_deg))

	assert_float(peak_roll).is_less_equal(car.stats.max_lean_angle + 0.01)
	assert_float(peak_roll).is_greater(car.stats.max_lean_angle * 0.9)


func test_impact_lean_decays_to_level() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 14)
	_add_floor_under(car)
	_add_wall(car, LEAN_WALL_OFFSET, LEAN_WALL_YAW_DEG)
	car.velocity = Vector3(0.0, 0.0, -LEAN_IMPACT_SPEED)

	await _simulate_physics_frames(LEAN_IMPACT_TRIGGER_FRAMES)
	assert_float(car._lean_roll_deg).is_not_zero()
	assert_str(car._lean_trigger_cause).is_equal("impact")

	await _simulate_physics_frames(_decay_frames(car.stats))

	assert_float(car._lean_roll_deg).is_equal_approx(0.0, 0.0001)
	assert_str(car._lean_trigger_cause).is_empty()


func test_stuck_signal_fires_after_sustained_held_state() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 15)
	await _land_then_lift(car)

	var fired_on_frame: int = await _hold_until_stuck(car, STUCK_MAX_HOLD_FRAMES)

	# Fired at all, within the cap.
	assert_int(fired_on_frame).is_not_equal(-1)
	# And fired *late* — at or past the tick the timer actually needs. This is
	# the half that proves the emission is gated rather than instant; the
	# companion case below comes at the same property from the other side.
	# is_greater_equal rather than a hard equality because the timer accumulates
	# a float delta 105 times, so the crossing tick is allowed to land one step
	# either side of the theoretical one.
	assert_int(fired_on_frame).is_greater_equal(_stuck_threshold_frames() - 1)
	assert_int(fired_on_frame).is_less_equal(STUCK_MAX_HOLD_FRAMES)


func test_stuck_signal_does_not_fire_before_threshold() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 16)
	await _land_then_lift(car)

	# Five ticks of margin under the crossing point, so this stays green against
	# the same float-accumulation slop the case above allows for.
	var frames_below_threshold: int = _stuck_threshold_frames() - 5
	var fired_on_frame: int = await _hold_until_stuck(car, frames_below_threshold)

	# -1 means the loop ran its full budget without the signal ever arriving.
	assert_int(fired_on_frame).is_equal(-1)
	# The car really was held in the abnormal state for all of those ticks, so
	# the silence above is the timer gate holding rather than the scenario having
	# quietly fallen apart (landed again, or picked up real falling speed).
	assert_bool(car.is_on_floor()).is_false()
	assert_float(car._stuck_timer).is_greater(0.0)
	assert_bool(car._is_stuck).is_false()


func test_recovery_resets_position_velocity_and_stuck_state() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 17)
	var landed_position: Vector3 = await _land_then_lift(car)

	var fired_on_frame: int = await _hold_until_stuck(car, STUCK_MAX_HOLD_FRAMES)
	assert_int(fired_on_frame).is_not_equal(-1)

	# Nothing may be awaited between here and the assertions: the recovered car
	# is airborne again, so further ticks would restart the stuck timer and start
	# walking the position back down.
	#
	# The expected spot is the *first* RECOVERY_OFFSETS entry, not merely
	# "somewhere above the landing". This scenario deliberately leaves the space
	# over the recovery target empty, so the clearance probe must accept that
	# first candidate — pinning it catches a probe that has started rejecting
	# clear positions and silently falling through to a larger offset.
	var expected_position: Vector3 = (
		landed_position + Vector3(0.0, VehicleController.RECOVERY_OFFSETS[0], 0.0)
	)
	assert_vector(car.global_position).is_equal_approx(expected_position, Vector3.ONE * 0.001)

	assert_vector(car.velocity).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	assert_float(car._stuck_timer).is_equal(0.0)
	# Re-armed, not latched: a later episode has to be able to fire again.
	assert_bool(car._is_stuck).is_false()


func test_recovery_clears_lean_state() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 18)
	await _land_then_lift(car)

	# The lean is re-applied every tick of the hold (including the tick recovery
	# fires on), so there is genuinely a deflection standing for
	# _on_vehicle_stuck() to clear. Left to itself the controller's decay would
	# unwind STUCK_LEAN_HOLD_DEG in ~15 ticks, long before the ~105-tick timer.
	var fired_on_frame: int = await _hold_until_stuck(
		car, STUCK_MAX_HOLD_FRAMES, STUCK_LEAN_HOLD_DEG
	)
	assert_int(fired_on_frame).is_not_equal(-1)

	assert_float(car._lean_pitch_deg).is_equal(0.0)
	assert_float(car._lean_roll_deg).is_equal(0.0)
	assert_str(car._lean_trigger_cause).is_empty()


## Parks a floor under only the rear half (local Z >= 0) of `car`'s footprint,
## leaving the front two corners over open air — see design note 2 above.
func _add_rear_half_floor_under(car: Node3D) -> void:
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(200, 1, 100)
	floor_body.add_child(shape)
	# Same Y placement as _add_floor_under (top face flush with the car's
	# underside); centered 50 units into +Z so the slab's near edge sits
	# exactly at the car's spawn Z instead of astride it.
	floor_body.position = car.global_position + Vector3(0.0, -1.0, 50.0)
	car.get_parent().add_child(floor_body)


func test_balance_tilt_zero_when_all_corners_supported() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 19)
	_add_floor_under(car)

	await _simulate_physics_frames(BALANCE_SETTLE_FRAMES)

	assert_bool(car.is_on_floor()).is_true()
	assert_float(car._balance_pitch_deg).is_equal_approx(0.0, 0.0001)
	assert_float(car._balance_roll_deg).is_equal_approx(0.0, 0.0001)
	assert_int(car._balance_supported_corners).is_equal(4)


func test_balance_tilt_nonzero_and_bounded_with_partial_support() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 20)
	_add_rear_half_floor_under(car)

	await _simulate_physics_frames(BALANCE_SETTLE_FRAMES)

	# Grounded on the rear half, not fallen through or missed the slab.
	assert_bool(car.is_on_floor()).is_true()
	assert_int(car._balance_supported_corners).is_equal(2)

	# Front corners unsupported, rear supported: pitch_intensity =
	# front_support - rear_support = 0.0 - 1.0, so the sign convention in
	# vehicle_controller.gd (positive pitch = nose up) requires this go
	# negative — nose dips toward the missing support.
	assert_float(car._balance_pitch_deg).is_less(0.0)
	assert_float(absf(car._balance_pitch_deg)).is_less_equal(
		car.stats.max_balance_tilt_angle + 0.01
	)
	# The asymmetry here is only front/rear — left and right corners are
	# equally (un)supported on each side, so roll should stay level.
	assert_float(car._balance_roll_deg).is_equal_approx(0.0, 0.0001)


func test_balance_tilt_zero_when_airborne() -> void:
	var runner := scene_runner(TOPHAT_CAR_SCENE)
	var car := _prepare_car(runner, 21)
	# No floor anywhere near this lane — is_on_floor() reads false from the
	# first physics tick, which is what drives _balance_supported_corners away
	# from its resting-default of 4 (the field starts at 4, not 0, so this
	# case only proves anything once at least one grounded-false tick runs).
	await _simulate_physics_frames(10)

	assert_bool(car.is_on_floor()).is_false()
	assert_float(car._balance_pitch_deg).is_equal_approx(0.0, 0.0001)
	assert_float(car._balance_roll_deg).is_equal_approx(0.0, 0.0001)
	assert_int(car._balance_supported_corners).is_equal(0)
