extends LevelBase

# Stealth test arena: a walled compound patrolled by hostiles. Complete when
# every hostile is down. Lockdown spawns reinforcements at the gate.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const REINFORCEMENT_COUNT := 2

@export var gate_point := Vector3(0, 1, -95)
var reinforcements_spawned := 0

func _ready() -> void:
	super._ready()
	build_flat_navmesh(Vector3(0, 0, -50), Vector2(220, 220))

func spawn_reinforcements(position: Vector3) -> void:
	for i in range(REINFORCEMENT_COUNT):
		var enemy := ENEMY_SCENE.instantiate()
		enemy.name = "Reinforcement%d" % (reinforcements_spawned + 1)
		reinforcements_spawned += 1
		enemy.position = gate_point + Vector3(2.0 * i - 1.0, 0, 0)
		enemy.patrol_points = PackedVector3Array([position, gate_point])
		$Enemies.add_child(enemy)
		register_enemy(enemy)
		enemy.receive_contact(position)

func objective_text() -> String:
	return "Eliminate all hostiles (%d left)" % enemies.size()

func is_complete() -> bool:
	return enemies.is_empty()
