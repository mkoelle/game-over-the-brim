class_name OutOfBoundsReset
extends Node
## Safety net for a track (T-024): when a car falls below `kill_height`, it
## has left the level, so put it back at its spawn pose and stop it.
##
## One instance per car, so player ownership stays explicit. The spawn pose
## is the car's transform when `target` is assigned. A race manager with
## checkpoints can replace this pose later.

signal car_reset(car: VehicleController)

## World height below which the car counts as out of the level. The test
## track floor is at y = 0.
@export var kill_height: float = -20.0

var target: VehicleController:
	set(value):
		target = value
		if target != null:
			_spawn = target.global_transform

var _spawn: Transform3D = Transform3D.IDENTITY


func _physics_process(_delta: float) -> void:
	if target == null or target.global_position.y >= kill_height:
		return
	target.global_transform = _spawn
	target.velocity = Vector3.ZERO
	# Teleport: do not interpolate from the fall position (T-020).
	target.reset_physics_interpolation()
	car_reset.emit(target)
