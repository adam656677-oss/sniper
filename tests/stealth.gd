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
	level.time_of_day = 1
	level.weather = 0
	var player = game.player
	var stealth = game.stealth
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	# Noise meter.
	player.velocity = Vector3.ZERO
	check(stealth.noise_level() == 0.0, "Standing still makes no noise")
	player.velocity = Vector3(3, 0, 0)
	check(stealth.noise_level() == 1.0, "Walking upright is loud")
	player.set_stance(player.Stance.CROUCH)
	var crouch_noise: float = stealth.noise_level()
	player.set_stance(player.Stance.PRONE)
	check(crouch_noise < 1.0 and stealth.noise_level() < crouch_noise, "Crouching and crawling are progressively quieter")
	player.set_stance(player.Stance.STAND)
	var listener = level.enemies[0]
	listener.global_position = player.global_position + Vector3(0, 0, -8)
	await physics_frame
	player.velocity = Vector3(3, 0, 0)
	stealth.advance(0.6)
	check(listener.state == listener.State.SUSPICIOUS, "Footsteps near a patrol make it suspicious but not alert")
	listener.change_state(listener.State.PATROL)
	listener.perception.awareness = 0.0
	listener.global_position = Vector3(-40, 1, -20)
	player.velocity = Vector3.ZERO
	# Binoculars and tagging.
	var target = level.enemies[1]
	target.global_position = Vector3(0, 1, -45)
	player.global_position = Vector3(0, 1, -5)
	game.camera.global_position = Vector3(0, 1.65, -5)
	game.camera.look_at(target.global_position + Vector3(0, 0.3, 0), Vector3.UP)
	await physics_frame
	check(stealth.tag() == null and stealth.tagged_enemies.is_empty(), "Tagging needs the binoculars up")
	check(stealth.toggle_binoculars() and game.camera.fov < 20.0, "Binoculars narrow the view")
	check(not game.is_aiming(), "Binoculars are not the rifle scope")
	check(stealth.tag() == target and stealth.live_tags() == [target], "Binoculars tag the hostile under the crosshair")
	check(stealth.tag() == target and stealth.tagged_enemies.size() == 1, "Tagging twice keeps one entry")
	game.camera.look_at(Vector3(0, 30, -50), Vector3.UP)
	check(stealth.tag() == null, "Nothing to tag in empty air")
	stealth.set_binoculars(false)
	check(game.camera.fov == 75.0, "Lowering the binoculars restores the view")
	target.take_hit(-1, 1000.0)
	check(stealth.live_tags().is_empty(), "Dead hostiles drop off the tag list")
	# Stones.
	var distracted = level.enemies[0]
	distracted.change_state(distracted.State.PATROL)
	distracted.perception.awareness = 0.0
	distracted.global_position = Vector3(10, 1, -30)
	game.camera.global_position = Vector3(0, 1.65, -5)
	game.camera.look_at(Vector3(0, 1.65, -35), Vector3.UP)
	await physics_frame
	check(stealth.stones == 3 and stealth.throw_stone() and stealth.stones == 2, "Throwing a stone spends one of three")
	check(distracted.state == distracted.State.INVESTIGATE and distracted.last_known.distance_to(Vector3(0, 1.65, -25)) < 1.0, "A guard investigates where the stone landed")
	stealth.throw_stone()
	stealth.throw_stone()
	check(not stealth.throw_stone() and stealth.stones == 0, "No stones left means no throw")
	state.set_paused(true)
	check(not stealth.toggle_binoculars() and not stealth.throw_stone(), "Pause blocks the stealth kit")
	state.set_paused(false)
	game.queue_free()
	await process_frame
	if failures == 0:
		print("STEALTH TESTS PASSED")
	quit(0 if failures == 0 else 1)
