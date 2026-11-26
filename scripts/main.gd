class_name Main
extends Node

## Root scene orchestrator.
##
## Wires the test-track sandbox, the drivable car, the chase camera, and
## the debug overlay together (STATE.md "Next Recommended Tasks" items 7
## and 9). References are assigned here in code rather than via serialized
## cross-node references in the .tscn: all of these are plain siblings
## under Main, so a direct reference is simplest and avoids any ambiguity
## in how an exported property resolves across instanced sub-scenes.
##
## The chase camera is a Phantom Camera rig (ADR-013): GameCamera +
## PhantomCameraHost renders whichever PhantomCamera3D has top priority,
## and CarFollowCam follows the car. Its ChaseCamYawDriver child reads
## `follow_target`, so this is the only place the car is assigned.
##
## A wall hit shakes the camera (T-008). The car's local `impacted` signal
## goes to the ImpactShake emitter's driver, and the emitter's noise layer
## matches CarFollowCam's. In split screen each player needs their own
## emitter, layer and connection, so one car's hit never shakes another
## player's view.
##
## In debug builds only, when the Debug Draw 3D class exists, `_ready()`
## attaches a VehicleDebugDraw node at runtime (T-007, ADR-016). It is loaded
## with `load()` and set through `set()`, so no scene and no release build
## references the script statically.
##
## GameCamera/SpeedFx (T-034) widens the FOV with speed and boost, and pulls
## the camera back on a boost. In split screen each camera needs its own.
##
## An OutOfBoundsReset puts the car back at its spawn pose if it ever falls
## out of the level (T-024), and the follow camera teleports with it.

@onready var _car: VehicleController = $TophatCar
@onready var _follow_cam: PhantomCamera3D = $CarFollowCam
@onready var _impact_shake: ImpactShakeDriver = $ImpactShake/ImpactShakeDriver
@onready var _debug_overlay: DebugOverlay = $DebugOverlay
@onready var _speed_fx: ChaseCamSpeedFx = $GameCamera/SpeedFx


func _ready() -> void:
	_follow_cam.follow_target = _car
	_car.impacted.connect(_on_car_impacted)
	_debug_overlay.target = _car
	_speed_fx.target = _car
	_speed_fx.follow_cam = _follow_cam
	var bounds_reset := OutOfBoundsReset.new()
	bounds_reset.name = "OutOfBoundsReset"
	bounds_reset.target = _car
	bounds_reset.car_reset.connect(_on_car_reset)
	add_child(bounds_reset)
	if OS.is_debug_build() and ClassDB.class_exists(&"DebugDraw3D"):
		var script: GDScript = load("res://scripts/vehicles/vehicle_debug_draw.gd")
		var debug_draw: Node = script.new()
		debug_draw.set(&"target", _car)
		add_child(debug_draw)
	print_rich(
		"[color=green][OverTheBrim][/color] Test track loaded, car spawned, CarFollowCam following."
	)
	EventBus.race_started.emit()


func _on_car_reset(_car_that_reset: VehicleController) -> void:
	_follow_cam.teleport_position()


func _on_car_impacted(impact_speed: float) -> void:
	_impact_shake.shake_for_impact(impact_speed, _car.stats.max_speed)
