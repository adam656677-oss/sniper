class_name SteelPlate
extends StaticBody3D

# Range plate: rings and falls when hit, stands back up after a delay.
# Never "dies", so the level keeps it as a target forever.

signal rung(plate: SteelPlate, distance_label: String)

const RESET_SECONDS := 4.0

@export var range_metres := 100.0
var hit_count := 0
var fallen := false
var reset_remaining := 0.0
@onready var plate: Node3D = $Plate
@onready var collision: CollisionShape3D = $Collision

func is_alive() -> bool:
	return true

func take_hit(_shape_index: int, _damage: float) -> float:
	hit_count += 1
	if not fallen:
		fallen = true
		reset_remaining = RESET_SECONDS
		plate.rotation_degrees.x = -85.0
		collision.set_deferred("disabled", true)
	rung.emit(self, "%d m" % int(range_metres))
	return 0.0

func reset() -> void:
	fallen = false
	reset_remaining = 0.0
	plate.rotation_degrees.x = 0.0
	collision.set_deferred("disabled", false)

func _physics_process(delta: float) -> void:
	if fallen and GameState.simulation_active():
		reset_remaining = maxf(0.0, reset_remaining - delta)
		if reset_remaining == 0.0:
			reset()
