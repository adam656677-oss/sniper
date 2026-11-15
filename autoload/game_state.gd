extends Node

# Single source of truth for simulation state. Registered as the GameState autoload.

signal paused_changed(paused: bool)
signal intel_collected
signal mission_finished

var paused := false
var finished := false
var intel := false

func reset() -> void:
	paused = false
	finished = false
	intel = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func simulation_active() -> bool:
	return not paused and not finished

func set_paused(value: bool) -> void:
	paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or finished else Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(paused)

func collect_intel() -> void:
	if intel:
		return
	intel = true
	intel_collected.emit()

func finish_mission() -> void:
	if finished:
		return
	finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mission_finished.emit()
