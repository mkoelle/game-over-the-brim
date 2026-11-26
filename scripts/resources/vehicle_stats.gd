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

## Yaw rate at full steering input once the car is moving, in
## radians/second. It stays flat with speed, so the turn radius grows with
## speed, as in the genre (T-027, handling-reference.md section 1): 1.4 rad/s
## gives about 7 m at 10 m/s and 17 m at 24 m/s.
@export var steering_rate: float = 1.4

## Below this speed, in m/s, the car does not rotate at all.
@export var steer_min_speed: float = 1.0

## Steering fades in from `steer_min_speed` and reaches full strength at this
## speed, in m/s.
@export var steer_full_speed: float = 7.0

## Seconds for the steer input to ramp from centre to full lock. A keyboard
## then feels like a soft analog stick.
@export var steer_ramp_time: float = 0.17

## Seconds per full unit of steer when the input crosses centre (left to
## right). This is slower than ramping up from centre.
@export var steer_reverse_time: float = 0.28

## Time constant, in seconds, for the travel direction to follow the body
## heading while gripping (T-028). Small means planted. It is frame-rate
## independent: `1 - exp(-delta / grip_time)` per tick.
@export var grip_time: float = 0.06

## The same time constant while drifting. Larger means a longer slide. The
## slide angle settles near `yaw rate x drift_slide_time` (T-028).
@export var drift_slide_time: float = 0.4

## Slowest speed, in m/s, at which a drift can start. Below 80% of it a
## drift ends (T-028).
@export var drift_min_speed: float = 11.0

## How much faster the body yaws in a drift than at normal full lock. Steer
## input then picks 20-80% of that rate (T-028).
@export var drift_turn_multiplier: float = 1.5

## Largest angle, in degrees, between the body and the travel direction.
@export var max_slide_angle_deg: float = 35.0

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
