extends LevelBase

# Stealth test arena: a walled compound patrolled by hostiles. Complete when
# every hostile is down. Lockdown spawns reinforcements at the gate.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const REINFORCEMENT_COUNT := 2

@export var gate_point := Vector3(0, 1, -95)
var reinforcements_spawned := 0
var exfil_zone: TriggerZone

func _ready() -> void:
	super._ready()
	build_flat_navmesh(Vector3(0, 0, -50), Vector2(220, 220))

func setup_objectives() -> void:
	mission_log.add("eliminate", "Eliminate all hostiles", MissionLog.Kind.PRIMARY, maxi(enemies.size(), 1))
	mission_log.add("exfil", "Reach the north gate", MissionLog.Kind.PRIMARY, 1, true)
	mission_log.add("undetected", "Stay undetected", MissionLog.Kind.SECONDARY)
	mission_log.add("silent", "Fire only suppressed weapons", MissionLog.Kind.OPTIONAL)
	coordinator.level_changed.connect(on_alert_changed)
	exfil_zone = add_trigger("ExfilZone", gate_point, Vector3(8, 4, 6))
	exfil_zone.enabled = false
	exfil_zone.entered.connect(func(_zone): mission_log.complete("exfil"))

func restore_triggers() -> void:
	exfil_zone.enabled = mission_log.status("exfil") == MissionLog.Status.ACTIVE

func on_alert_changed(level: int) -> void:
	if level >= AlertCoordinator.Level.ALERT:
		mission_log.fail("undetected")

func report_noise(position: Vector3, radius: float, loudness: float = 1.0) -> void:
	super.report_noise(position, radius, loudness)
	if loudness >= 1.0 and radius > 100.0:
		mission_log.fail("silent")

func on_enemy_died(enemy: Node) -> void:
	super.on_enemy_died(enemy)
	mission_log.progress("eliminate")
	if mission_log.status("eliminate") == MissionLog.Status.COMPLETE:
		mission_log.activate("exfil")
		exfil_zone.enabled = true

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
	mission_log.set_goal("eliminate", int(mission_log.find("eliminate").goal) + REINFORCEMENT_COUNT)

