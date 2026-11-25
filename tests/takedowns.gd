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
	var takedown: TakedownController = game.takedown
	var player: Player = game.player
	var level: LevelBase = game.level
	var enemy: Enemy = level.enemies[0]
	enemy.global_position = Vector3(0, 1, 0)
	enemy.look_at(Vector3(0, 1, -10), Vector3.UP)
	player.global_position = Vector3(0, 1, 2)
	check(InputMap.has_action("takedown"), "Takedown has a dedicated keyboard action")
	check(takedown.candidate() == enemy, "An unaware enemy can be selected from behind at close range")
	check(takedown.start(), "A valid stealth takedown starts")
	check(takedown.active and takedown.cinematic_camera.current and not game.camera.current, "Takedown switches to a third-person cinematic camera")
	check(not player.is_physics_processing() and not level.is_physics_processing(), "Player and level simulation freeze during the cinematic")
	takedown.advance(0.6)
	check(not enemy.is_alive() and game.stats.kills == 1, "The takedown silently eliminates the target and records the kill")
	takedown.advance(0.7)
	check(not takedown.active and game.camera.current and game.get_node("HUDLayer").visible, "Camera, HUD and simulation return after the cinematic")
	check(player.is_physics_processing() and level.is_physics_processing(), "Player and level processing are restored")

	var front_enemy: Enemy = level.enemies[0]
	front_enemy.global_position = Vector3(0, 1, 0)
	front_enemy.look_at(Vector3(0, 1, -10), Vector3.UP)
	player.global_position = Vector3(0, 1, -2)
	check(takedown.candidate() == null and not takedown.start(), "Takedown is rejected when approaching from the front")
	player.global_position = Vector3(0, 1, 30)
	check(takedown.candidate() == null, "Takedown is rejected outside close range")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("TAKEDOWN TESTS PASSED")
	quit(0 if failures == 0 else 1)
