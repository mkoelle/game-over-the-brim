class_name ImpactShakeDriver
extends Node
## Turns a car's wall hit into a short camera shake (T-008).
##
## It must be a child of a PhantomCameraNoiseEmitter3D. main.gd connects
## the car's local `VehicleController.impacted` signal to
## `shake_for_impact`. The emitter only reaches PhantomCamera3D nodes that
## share its `noise_emitter_layer`. In split screen, give each player their
## own emitter and layer, so a hit shakes only that player's view.
##
## The noise resource should be rotational only. Positional noise could
## move the camera back into a wall that its collision just pulled it
## away from (ADR-013, T-005).

## Hits slower than this into the wall, in m/s, do not shake.
@export var min_shake_speed: float = 3.0

## Noise amplitude for a full-speed head-on hit. With the ImpactShake noise
## in main.tscn, 10 gives a peak camera rotation of about 2.5 degrees.
@export var max_amplitude: float = 10.0

## Seconds at full shake for the lightest hit.
@export var min_hold_time: float = 0.03

## Seconds at full shake for a full-speed hit.
@export var max_hold_time: float = 0.08

## Seconds to fade out after the lightest hit.
@export var min_decay_time: float = 0.10

## Seconds to fade out after a full-speed hit.
@export var max_decay_time: float = 0.22

var _emitter: PhantomCameraNoiseEmitter3D
var _active_strength: float = 0.0


func _ready() -> void:
	_emitter = get_parent() as PhantomCameraNoiseEmitter3D
	# Use our own copy: the amplitude is rewritten on every hit, and a
	# scene's sub-resource is shared by every instance of that scene.
	_emitter.noise = _emitter.noise.duplicate() as PhantomCameraNoise3D


## Returns 0 below `min_shake_speed`, rising linearly to 1 at `full_speed`.
func shake_strength(impact_speed: float, full_speed: float) -> float:
	if impact_speed <= min_shake_speed or full_speed <= min_shake_speed:
		return 0.0
	return clampf(inverse_lerp(min_shake_speed, full_speed, impact_speed), 0.0, 1.0)


## Starts a shake scaled by how hard the car hit. `full_speed` is the speed
## that gives the strongest shake (the car's top speed). A hit weaker than
## the shake still playing is ignored, so it cannot cut that shake short.
## Returns true if a shake started.
func shake_for_impact(impact_speed: float, full_speed: float) -> bool:
	var strength: float = shake_strength(impact_speed, full_speed)
	if strength <= 0.0:
		return false
	if _emitter.is_emitting() and strength < _active_strength:
		return false
	_active_strength = strength
	_emitter.noise.amplitude = max_amplitude * strength
	_emitter.duration = lerpf(min_hold_time, max_hold_time, strength)
	_emitter.decay_time = lerpf(min_decay_time, max_decay_time, strength)
	_emitter.emit()
	return true
