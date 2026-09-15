class_name DebugOverlay
extends CanvasLayer
## Developer-only readout: speed, live input, FPS. Gated behind
## GameConfig.debug_mode (off by default, toggled at runtime with F3) —
## never shown to players. See docs/standards/manual-testing.md.
##
## Reads VehicleController.last_input rather than polling Input.* itself,
## so this shows exactly what the car is actually reacting to (Architecture
## Decision 01 — the car never polls Input.* globally either).

## The vehicle to read telemetry from. Assigned externally (e.g. main.gd),
## same pattern as ChaseCamera.target.
@export var target: VehicleController

@onready var _label: Label = $PanelContainer/Label


## Debug-only hotkey: F4 forces the stuck/flip recovery on `target` immediately,
## so a tester can exercise the recovery path without first having to wedge the
## car into geometry and wait out STUCK_TIME_THRESHOLD. Gated behind
## GameConfig.debug_mode exactly like the rest of this file — developer tooling,
## never reachable by players. F3 is already the debug_mode toggle itself
## (scripts/autoload/game_config.gd), hence F4 here.
func _unhandled_input(event: InputEvent) -> void:
	if not GameConfig.debug_mode:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.is_echo()
		and event.physical_keycode == KEY_F4
	):
		if target != null:
			target.force_recovery()


func _process(_delta: float) -> void:
	visible = GameConfig.debug_mode
	if not visible or target == null:
		return

	var flat_velocity: Vector3 = Vector3(target.velocity.x, 0.0, target.velocity.z)
	var speed: float = flat_velocity.length()
	var throttle: float = float(target.last_input.get("throttle", 0.0))
	var steer: float = float(target.last_input.get("steer", 0.0))
	var drift: bool = bool(target.last_input.get("drift", false))
	var lean_pitch: float = target._lean_pitch_deg
	var lean_roll: float = target._lean_roll_deg
	var lean_cause: String = (
		"none" if target._lean_trigger_cause.is_empty() else target._lean_trigger_cause
	)
	var balance_pitch: float = target._balance_pitch_deg
	var balance_roll: float = target._balance_roll_deg
	var balance_corners: int = target._balance_supported_corners

	_label.text = (
		(
			"Speed: %.1f / %.1f m/s\nThrottle: %+.2f\nSteer: %+.2f\nDrift: %s\n"
			+ "Lean: pitch %+.1f roll %+.1f (%s)\n"
			+ "Balance: pitch %+.1f roll %+.1f (%d/4 corners)\nFPS: %d"
		)
		% [
			speed,
			target.stats.max_speed,
			throttle,
			steer,
			"YES" if drift else "no",
			lean_pitch,
			lean_roll,
			lean_cause,
			balance_pitch,
			balance_roll,
			balance_corners,
			Engine.get_frames_per_second(),
		]
	)
