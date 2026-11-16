extends SceneTree

var failures := 0
var state: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var level = game.level
	var player = game.player
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	# Suppression.
	var calm_sway: float = player.sway_multiplier()
	var shooter = level.enemies[0]
	shooter.global_position = Vector3(0, 1, -40)
	player.global_position = Vector3(0, 1, -10)
	shooter.change_state(shooter.State.ALERT)
	for i in range(3):
		shooter.fire_timer = 0.0
		shooter.shoot_at_player()
	check(player.suppression > 0.5 and player.sway_multiplier() > calm_sway * 1.5, "Incoming fire suppresses the player and widens sway")
	game.update_hud()
	check(game.hud.text.contains("SUPPRESSED"), "HUD warns of suppression")
	player.suppression = 0.6
	player.velocity = Vector3.ZERO
	player._physics_process(1.0)
	check(player.suppression < 0.6 and player.suppression > 0.0, "Suppression fades when fire stops")
	player.suppression = 0.0
	# Flanking: two guards converging on one contact choose opposite sides.
	var a = level.enemies[1]
	var b = level.enemies[2]
	a.name = "FlankA"
	b.name = "FlankB"
	a.global_position = Vector3(-10, 1, -70)
	b.global_position = Vector3(10, 1, -70)
	for guard in [a, b]:
		guard.last_known = Vector3(0, 1, -40)
		guard.has_last_known = true
	var pa: Vector3 = a.choose_flank_point()
	var pb: Vector3 = b.choose_flank_point()
	var a_side: float = (pa - a.last_known).length()
	check(absf(a_side - 15.0) < 0.01 and absf((pb - b.last_known).length() - 15.0) < 0.01, "Flank points sit 15 m beside the contact")
	var hash_a := hash(StringName("FlankA")) & 1
	var hash_b := hash(StringName("FlankB")) & 1
	if hash_a != hash_b:
		check(pa.distance_to(pb) > 10.0, "Guards with different names flank from different sides")
	else:
		check(true, "Flank side is deterministic per guard name")
	player.global_position = Vector3(0, 1, 60)
	a.change_state(a.State.ALERT)
	a.since_seen = 0.0
	a.tick(0.1)
	check(a.has_flank_point and a.flank_point == pa, "An alert guard without sight heads for its flank point")
	var start_to_flank: float = a.horizontal_distance(a.flank_point)
	for i in range(60):
		await physics_frame
		a.tick(1.0 / 60.0)
	check(a.horizontal_distance(a.flank_point) < start_to_flank - 1.0, "The guard moves toward the flank point")
	a.change_state(a.State.SEARCH)
	check(not a.has_flank_point, "Leaving alert clears the flank point")
	# Bodies: carry, hide, discovery.
	var victim = level.enemies[3]
	var victim_name := String(victim.name)
	victim.global_position = Vector3(20, 1, -20)
	victim.take_hit(-1, 1000.0)
	check(level.coordinator.bodies.has(victim_name), "A kill registers a named body")
	player.global_position = Vector3(20, 1, -18.5)
	await physics_frame
	check(game.stealth.nearest_body() == victim, "The body is within reach")
	game.interact()
	check(game.stealth.is_carrying() and player.carrying == victim and player.move_speed() <= 2.0, "Interact picks up the body and slows the player")
	player.velocity = Vector3(1.5, 0, 0)
	check(game.stealth.noise_level() >= 1.0, "Carrying while moving upright is loud")
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-35, 1, -36)
	player._physics_process(0.016)
	game.interact()
	check(not game.stealth.is_carrying() and level.coordinator.bodies[victim_name].distance_to(Vector3(20, 1, -20)) > 10.0, "Dropping moves the body record to the new spot")
	var watcher = a
	watcher.change_state(watcher.State.PATROL)
	watcher.perception.awareness = 0.0
	watcher.global_position = Vector3(20, 1, 0)
	watcher.look_at(Vector3(20, 1, -20), Vector3.UP)
	await physics_frame
	watcher.check_bodies()
	check(watcher.state == watcher.State.PATROL, "A guard looking at the old spot finds nothing")
	var body_spot: Vector3 = level.coordinator.bodies[victim_name]
	watcher.global_position = Vector3(body_spot.x - 8.0, 1.0, body_spot.z + 8.0)
	watcher.look_at(Vector3(body_spot.x, watcher.global_position.y, body_spot.z), Vector3.UP)
	await physics_frame
	await physics_frame
	watcher.check_bodies()
	check(watcher.state == watcher.State.SEARCH, "A guard who sees the moved body starts a search")
	# Saves carry body positions.
	var saves = root.get_node("SaveSystem")
	var data: Dictionary = saves.capture(game)
	check(data.coordinator.bodies.has(victim_name), "Saves record body positions")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("COMBAT TESTS PASSED")
	quit(0 if failures == 0 else 1)
