class_name AimSway
extends Node

# Breath-hold and sway model. Produces a small angular offset in degrees that the
# mission applies to the camera while aiming. Fictional tuning.

const BASE_AMPLITUDE_DEG := 0.35
const HOLD_MULTIPLIER := 0.25
const EXHAUSTED_MULTIPLIER := 2.0
const BREATH_CAPACITY := 6.0
const BREATH_RECOVERY_PER_SECOND := 0.75
const RECOVERY_FRACTION := 0.35
const NOISE_SPEED := 0.6

var breath := BREATH_CAPACITY
var holding := false
var exhausted := false
var stance_multiplier := 1.0
var time := 0.0
var noise := FastNoiseLite.new()

func _ready() -> void:
	noise.seed = 1337
	noise.frequency = 1.0

func breath_fraction() -> float:
	return breath / BREATH_CAPACITY

func can_hold() -> bool:
	return not exhausted and breath > 0.0

func set_holding(value: bool) -> bool:
	if value and not can_hold():
		holding = false
		return false
	holding = value
	return holding

func amplitude_degrees() -> float:
	var amplitude := BASE_AMPLITUDE_DEG * stance_multiplier
	if exhausted:
		amplitude *= EXHAUSTED_MULTIPLIER
	elif holding:
		amplitude *= HOLD_MULTIPLIER
	return amplitude

func advance(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	time += dt * (0.5 if holding else 1.0)
	if holding:
		breath = maxf(0.0, breath - dt)
		if breath == 0.0:
			holding = false
			exhausted = true
	else:
		breath = minf(BREATH_CAPACITY, breath + BREATH_RECOVERY_PER_SECOND * dt)
		if exhausted and breath >= BREATH_CAPACITY * RECOVERY_FRACTION:
			exhausted = false

func offset_degrees() -> Vector2:
	var amplitude := amplitude_degrees()
	var x := noise.get_noise_1d(time * NOISE_SPEED * 100.0)
	var y := noise.get_noise_1d(time * NOISE_SPEED * 100.0 + 5000.0)
	return Vector2(x, y) * amplitude
