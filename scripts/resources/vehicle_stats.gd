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

## Seconds of in-turn drifting to reach each boost tier (T-031). Three tiers
## (owner decision, FC-1). Tier 1 is quick so a casual player gets a payout
## on a normal corner (handling-reference.md sections 2 and 6).
@export var drift_tier_times: PackedFloat32Array = PackedFloat32Array([0.85, 1.9, 3.0])

## Boost length, in seconds, paid out for tiers 1, 2 and 3 (section 2:
## 0.5-0.8, 1.2-1.7 and 2.0-2.6 s).
@export var boost_times: PackedFloat32Array = PackedFloat32Array([0.7, 1.45, 2.3])

## Extra top speed while boosting, in m/s. 4.8 is +20% of 24 (section 2:
## +15-25%).
@export var boost_speed: float = 4.8

## Acceleration, in m/s^2, toward the boosted top speed while boosting.
@export var boost_acceleration: float = 25.0

## Trick boost (T-033): extra top speed, in m/s, and length, in seconds, paid
## on landing after a trick. 6.7 m/s is +28% of 24, stronger than a drift
## boost because it needs a ramp (handling-reference.md section 3: +25-30%,
## 0.6-1.2 s).
@export var trick_boost_speed: float = 6.7
@export var trick_boost_time: float = 0.9

## Boost gauge spend (T-039): extra top speed, in m/s, and length, in seconds,
## for one gauge segment.
@export var gauge_boost_speed: float = 4.8
@export var gauge_boost_time: float = 1.0

## Share of the into-wall speed the car bounces back with on a hard hit
## (T-029). 0 is a dead stop, 1 a perfect bounce. The target is 0.3-0.5.
@export_range(0.0, 1.0) var wall_restitution: float = 0.4

## Time constant, in seconds, for the body to turn along a wall after a
## glancing hit, so the car slides off instead of grinding (T-029).
@export var wall_align_time: float = 0.1

## Vehicle mass in kilograms — feeds collision response (heavier vehicles
## resist spin-outs and punch through lighter ones on impact).
@export var mass: float = 1000.0

## Share of the ground yaw rate available in the air (T-030). The genre keeps
## air control small: steering adds a few degrees of yaw, and the launch keeps
## its line (handling-reference.md section 3: 15-30%). There is no throttle in
## the air.
@export_range(0.0, 1.0) var air_steer_share: float = 0.25

## Gravity multiplier while airborne (T-030). Arcade jumps fall faster than
## real ones, so hang time stays short (section 3: 1.3-1.8).
@export var air_gravity_scale: float = 1.6
