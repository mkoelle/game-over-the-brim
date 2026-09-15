class_name VehicleStats
extends Resource
## Data-driven tuning knobs for one vehicle archetype.
##
## Per docs/design/vehicles.md's Technical Implementation section, physics
## tuning is exposed as exported variables on a Resource so designers can
## live-tune acceleration, grip, drift slip, and top speed without touching
## `vehicle_controller.gd` or recompiling scripts. One `.tres` instance per
## archetype (e.g. `resources/vehicles/stovepipe_speedster.tres`).
##
## Defaults on this script are deliberately snappy arcade values, not
## simulation-accurate ones — "Fun > Realism" is pillar #1
## (docs/design/game-pillars.md).

## Top speed the vehicle can reach under full throttle, in meters/second.
@export var max_speed: float = 25.0

## Forward speed gained per second under full throttle, in meters/second^2.
@export var acceleration: float = 15.0

## Forward speed lost per second under full brake, in meters/second^2.
@export var braking_force: float = 25.0

## Forward speed lost per second while coasting (no throttle, no brake), in
## meters/second^2. Weaker than braking_force so active braking still feels
## stronger than simply lifting off the gas.
@export var coast_deceleration: float = 8.0

## Turn rate at full steering input, in radians/second.
@export var steering_rate: float = 2.5

## Fraction of lateral grip retained while drifting, 0..1 — 1.0 means no
## slide at all, lower values mean more slide/slip through the drift.
@export_range(0.0, 1.0) var drift_grip: float = 0.6

## Vehicle mass in kilograms — feeds collision response (heavier vehicles
## resist spin-outs and punch through lighter ones on impact).
@export var mass: float = 1000.0

## Fraction of ground throttle/brake/steering effectiveness retained while
## airborne (0..1) — kart racers consistently give the player some control
## and continued boosting mid-jump rather than a pure unpowered ballistic
## fall (Super Mario Kart's handling is fully ground-equivalent in the
## air; Crash Team Racing's air-brake lets you turn *tighter* than on the
## ground). This isn't full ground grip: velocity blends toward the
## target instead of snapping to it, so momentum from the launch is still
## dominant.
@export_range(0.0, 1.0) var air_control: float = 0.35

## Maximum pitch/roll lean angle reachable from a landing/impact event, in
## degrees. Clamped well short of a full tip-over — this is a bounded,
## self-correcting consequence, not a flip.
@export_range(0.0, 45.0) var max_lean_angle: float = 20.0

## Touchdown angle (degrees, between the vehicle's up vector and the
## ground normal at the instant of landing) above which a landing induces
## lean. Shallower landings stay clean — no lean triggered.
@export_range(0.0, 90.0) var lean_landing_angle_threshold: float = 15.0

## Lateral impact speed (m/s) above which a hard side impact induces lean,
## independent of landing angle — either trigger alone is sufficient, not
## both required at once.
@export var lean_impact_speed_threshold: float = 8.0

## Time (seconds) for an induced lean to decay back to level once
## triggered — keeps the mechanic "hard to trigger, always self-corrects."
@export var lean_correction_duration: float = 0.6

## Maximum pitch/roll tilt reachable from resting on partial support (e.g.
## balanced on a ledge with one corner hanging in open air), in degrees.
## Deliberately a separate cap from max_lean_angle — this is a continuous,
## always-on reflection of current support, not a decaying one-shot response
## to a trigger, so it has different tuning needs.
@export_range(0.0, 45.0) var max_balance_tilt_angle: float = 15.0

## How far below the chassis (meters) each of the four footprint-corner
## support raycasts probes for ground. Short — this is a "is this corner
## still touching something" check, not a general ground-clearance sensor.
@export var balance_raycast_probe_distance: float = 0.5

## Degrees per second the balance tilt is allowed to change by, in either
## direction. Continuous support state can flicker corner-to-corner over
## rough ground; this smooths the tilt's response instead of snapping to
## every raycast fluctuation, which is what keeps ordinary uneven-terrain
## driving from reading as twitchy.
@export var balance_tilt_response_rate: float = 60.0
