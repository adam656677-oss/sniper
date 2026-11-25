extends Node

# Single source of truth for simulation state. Registered as the GameState autoload.

signal paused_changed(paused: bool)
signal intel_collected
signal mission_finished
signal mission_failed

enum Difficulty { EASY, NORMAL, HARD }
const PERCEPTION_MULTIPLIER := {Difficulty.EASY: 0.6, Difficulty.NORMAL: 1.0, Difficulty.HARD: 1.5}
const ACCURACY_MULTIPLIER := {Difficulty.EASY: 0.5, Difficulty.NORMAL: 1.0, Difficulty.HARD: 1.5}

var paused := false
var finished := false
var failed := false
var intel := false
var difficulty: int = Difficulty.NORMAL

func perception_multiplier() -> float:
	return PERCEPTION_MULTIPLIER[difficulty]

func accuracy_multiplier() -> float:
	return ACCURACY_MULTIPLIER[difficulty]

func reset() -> void:
	paused = false
	finished = false
	failed = false
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

func fail_mission() -> void:
	if finished:
		return
	failed = true
	finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mission_failed.emit()
