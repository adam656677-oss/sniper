extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var enemy: Enemy = game.level.enemies[0]
	var visual: EnemyVisual = enemy.get_node("VisualRig")
	check(visual != null and visual.get_child_count() >= 9, "Enemy has a generated humanoid visual rig")
	check(not enemy.get_node("Head/HeadMesh").visible and not enemy.get_node("Torso/TorsoMesh").visible, "Old blockout cubes are hidden")
	check(enemy.get_node("Head") is CollisionShape3D and enemy.get_node("Torso") is CollisionShape3D, "Original hit-zone collision shapes remain intact")
	check(not visual.held_weapon.visible, "Patrol pose keeps the held weapon lowered")
	enemy.change_state(Enemy.State.ALERT)
	visual._process(0.2)
	check(visual.held_weapon.visible and visual.left_arm.rotation.x < 0.0, "Alert state raises the weapon into a combat-ready pose")
	enemy.velocity = Vector3(1, 0, 0)
	visual._process(0.1)
	check(absf(visual.left_leg.rotation.x) > 0.1, "Movement drives a procedural walking cycle")
	enemy.die()
	visual._process(0.2)
	check(visual.rotation.z > 0.1 and visual.position.y < 0.0, "Death state adds a visual collapse")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("ENEMY VISUAL TESTS PASSED")
	quit(0 if failures == 0 else 1)
