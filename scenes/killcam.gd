class_name KillCam
extends Node

# Long-shot slow motion. Camera follow is a later visual item; this owns the
# trigger rule and the time-scale envelope so it can be tested headlessly.

const DISTANCE_THRESHOLD := 150.0
const SLOW_SCALE := 0.25
const DURATION_SECONDS := 2.5

var enabled := true
var remaining := 0.0
var last_distance := 0.0

func active() -> bool:
	return remaining > 0.0

func consider(distance: float) -> bool:
	if not enabled or distance < DISTANCE_THRESHOLD or active():
		return false
	last_distance = distance
	remaining = DURATION_SECONDS
	Engine.time_scale = SLOW_SCALE
	return true

func skip() -> void:
	if active():
		remaining = 0.0
		Engine.time_scale = 1.0

# delta is scaled game time; convert back to real seconds.
func advance(delta: float) -> void:
	if not active():
		return
	remaining = maxf(0.0, remaining - maxf(delta, 0.0) / maxf(Engine.time_scale, 0.01))
	if remaining == 0.0:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
