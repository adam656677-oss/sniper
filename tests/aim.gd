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
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var player = game.player
	var sway = game.sway
	check(player.stance == player.Stance.STAND and player.move_speed() == 5.0, "Player starts standing")
	check(player.toggle_stance(player.Stance.CROUCH) and player.stance == player.Stance.CROUCH, "Crouch toggles on")
	check(player.collider.shape.height < 1.8 and player.head.position.y < 0.65, "Crouch lowers collider and eye height")
	check(player.move_speed() < 5.0, "Crouch slows movement")
	check(player.toggle_stance(player.Stance.CROUCH) and player.stance == player.Stance.STAND, "Crouch toggles off")
	check(player.toggle_stance(player.Stance.PRONE) and player.stance == player.Stance.PRONE, "Prone toggles on")
	check(player.move_speed() < 2.5 and player.sway_multiplier() < 0.6, "Prone is slowest and steadiest")
	var prone_amplitude: float = 0.0
	sway.stance_multiplier = player.sway_multiplier()
	prone_amplitude = sway.amplitude_degrees()
	player.set_stance(player.Stance.CROUCH)
	sway.stance_multiplier = player.sway_multiplier()
	var crouch_amplitude: float = sway.amplitude_degrees()
	player.set_stance(player.Stance.STAND)
	sway.stance_multiplier = player.sway_multiplier()
	var stand_amplitude: float = sway.amplitude_degrees()
	check(prone_amplitude < crouch_amplitude and crouch_amplitude < stand_amplitude, "Sway amplitude orders prone < crouch < stand")
	state.set_paused(true)
	check(not player.set_stance(player.Stance.PRONE) and player.stance == player.Stance.STAND, "Pause blocks stance changes")
	state.set_paused(false)
	check(sway.set_holding(true) and sway.holding, "Breath can be held when rested")
	check(sway.amplitude_degrees() < stand_amplitude * 0.5, "Holding breath steadies the aim")
	sway.advance(3.0)
	check(sway.breath_fraction() < 1.0 and sway.holding, "Holding drains breath")
	sway.advance(4.0)
	check(not sway.holding and sway.exhausted and sway.breath_fraction() == 0.0, "Empty lungs force release and exhaustion")
	check(sway.amplitude_degrees() > stand_amplitude, "Exhaustion worsens sway")
	check(not sway.set_holding(true) and not sway.holding, "Cannot hold breath while exhausted")
	sway.advance(1.0)
	check(sway.exhausted, "Short rest does not recover")
	sway.advance(4.0)
	check(not sway.exhausted and sway.can_hold(), "Rest recovers the ability to hold")
	var offset: Vector2 = sway.offset_degrees()
	check(absf(offset.x) <= sway.amplitude_degrees() and absf(offset.y) <= sway.amplitude_degrees(), "Sway offset stays within amplitude")
	game.camera.fov = 25.0
	game.advance_sway(0.016)
	check(absf(game.camera.rotation_degrees.x - game.sway.offset_degrees().y) < 0.001 and game.camera.rotation_degrees.x != 0.0, "Sway is applied to the camera while aiming")
	game.camera.fov = 75.0
	game.advance_sway(0.016)
	check(game.camera.rotation_degrees == Vector3.ZERO, "Sway clears when not aiming")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("AIM TESTS PASSED")
	quit(0 if failures == 0 else 1)
