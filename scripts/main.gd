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
## The map comes from GameConfig (T-035): the sandbox by default, and F4 or
## `--track=circuit` for the tuning circuit.
##
## An OutOfBoundsReset puts the car back at its spawn pose if it ever falls
## out of the level (T-024), and the follow camera teleports with it.

## Intro vantage, relative to the car at spawn, in metres: behind, above and to
## the right. About 22 degrees down onto the car from 25 m away.
const INTRO_BACK: float = 22.0
const INTRO_UP: float = 10.0
const INTRO_SIDE: float = 7.0

## Seconds the intro holds its still shot before flying to the chase camera.
const INTRO_HOLD: float = 0.4

@onready var _car: VehicleController = $TophatCar
@onready var _follow_cam: PhantomCamera3D = $CarFollowCam
@onready var _impact_shake: ImpactShakeDriver = $ImpactShake/ImpactShakeDriver
@onready var _debug_overlay: DebugOverlay = $DebugOverlay
@onready var _speed_fx: ChaseCamSpeedFx = $GameCamera/SpeedFx
@onready var _intro_cam: PhantomCamera3D = $IntroCam


func _ready() -> void:
	var moved: bool = _use_selected_track()
	_follow_cam.follow_target = _car
	if moved:
		_teleport_camera_next_frame()
	_play_intro()
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


## Swaps the sandbox for the map GameConfig selects (T-035), and starts the car
## at that map's "Spawn" marker. Returns true if it swapped. The sandbox stays
## the default, so tests and `task run` are unchanged.
func _use_selected_track() -> bool:
	var path: String = GameConfig.track_path()
	var current: Node = get_node_or_null("TestTrack")
	if current == null or current.scene_file_path == path:
		return false
	var track: Node3D = (load(path) as PackedScene).instantiate()
	remove_child(current)
	current.free()
	add_child(track)
	move_child(track, 0)
	var spawn: Marker3D = track.get_node_or_null("Spawn") as Marker3D
	if spawn != null:
		_car.global_transform = spawn.global_transform
		_car.velocity = Vector3.ZERO
		_car.reset_physics_interpolation()
	return true


## Start-of-race camera (T-036). IntroCam holds a still shot above and behind
## the car, then hands over to CarFollowCam. Phantom Camera flies between them
## with CarFollowCam's tween (1.8 s, cubic ease in-out). Before this the camera
## flew in from the world origin, which worked on the small sandbox but swept
## 70 m on the circuit. GameConfig.play_intro turns it off (tests use that).
func _play_intro() -> void:
	if not GameConfig.play_intro:
		_intro_cam.priority = 0
		return
	_intro_cam.global_transform = intro_vantage(_car.global_transform)
	await get_tree().create_timer(INTRO_HOLD).timeout
	_intro_cam.priority = 0


## Intro vantage pose for a car at `car`: behind it, above it, and a little to
## its right, looking at the car. Pure, so it is tested.
static func intro_vantage(car: Transform3D) -> Transform3D:
	var at: Vector3 = car.origin + Vector3.UP * 1.0
	var from: Vector3 = (
		car.origin + car.basis.z * INTRO_BACK + car.basis.x * INTRO_SIDE + Vector3.UP * INTRO_UP
	)
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


## Starts the camera behind the car at its new spawn, not flying in from the
## sandbox spawn. It waits one frame, because Phantom Camera builds its
## third-person rig during its first frame.
func _teleport_camera_next_frame() -> void:
	await get_tree().process_frame
	_follow_cam.teleport_position()


func _on_car_reset(_car_that_reset: VehicleController) -> void:
	_follow_cam.teleport_position()


func _on_car_impacted(impact_speed: float) -> void:
	_impact_shake.shake_for_impact(impact_speed, _car.stats.max_speed)
