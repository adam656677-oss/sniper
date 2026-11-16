class_name TriggerZone
extends Node3D

# Axis-aligned box the level polls with the player's position each physics
# step. Deterministic and headless-friendly; no physics areas involved.

signal entered(zone: TriggerZone)
signal exited(zone: TriggerZone)

@export var size := Vector3(4, 4, 4)
var inside := false
var enabled := true

func contains(point: Vector3) -> bool:
	var local := point - global_position
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5

func check(point: Vector3) -> void:
	if not enabled:
		return
	var now := contains(point)
	if now and not inside:
		inside = true
		entered.emit(self)
	elif not now and inside:
		inside = false
		exited.emit(self)
