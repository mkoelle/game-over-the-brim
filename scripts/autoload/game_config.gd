extends Node

## Global configuration and settings constants.

## Gates DebugOverlay (scenes/ui/debug_overlay.tscn) and any other
## developer-only readouts. Off by default — never ships on for players.
## Toggle at runtime with F3 so testers don't need an editor round-trip.
var debug_mode: bool = false

## Test maps, in F4 order (T-035). Index 0 is the sandbox that main.tscn holds.
## Each other map has a Marker3D named "Spawn" where the car starts.
const TRACKS: Array[String] = [
	"res://scenes/arenas/test_track.tscn",
	"res://scenes/arenas/tuning_circuit.tscn",
]

## Short names for `--track=<name>` on the command line (after `--`).
const TRACK_NAMES: Array[String] = ["sandbox", "circuit"]

## The map main.tscn loads. Set by `--track=` at start, cycled with F4.
var track_index: int = 0

## Play the start-of-race camera fly-in (T-036). Tests that check the chase
## camera from the first frames turn it off.
var play_intro: bool = true


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			var wanted: String = arg.trim_prefix("--track=")
			var found: int = TRACK_NAMES.find(wanted)
			if found >= 0:
				track_index = found
			else:
				push_warning("GameConfig: unknown track '%s', using the sandbox" % wanted)


## Resource path of the selected map.
func track_path() -> String:
	return TRACKS[clampi(track_index, 0, TRACKS.size() - 1)]


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey and event.pressed
		and not event.echo and event.physical_keycode == KEY_F3
	):
		debug_mode = not debug_mode
		print_rich("[color=yellow][GameConfig][/color] debug_mode = ", debug_mode)
	elif (
		event is InputEventKey and event.pressed
		and not event.echo and event.physical_keycode == KEY_F4
	):
		track_index = (track_index + 1) % TRACKS.size()
		print_rich("[color=yellow][GameConfig][/color] track = ", TRACK_NAMES[track_index])
		get_tree().reload_current_scene()
