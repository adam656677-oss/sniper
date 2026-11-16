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

func joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func joy_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event

func run_tests() -> void:
	state = root.get_node("GameState")
	root.get_node("Settings").reset()
	# Controller bindings.
	for action in ["move_forward", "move_left", "fire", "aim", "interact", "reload", "pause", "look_left", "look_down", "next_weapon", "zero_up", "hold_breath"]:
		var has_pad := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		check(has_pad, "Action %s has a controller binding" % action)
	check(InputMap.event_is_action(joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), "fire") and InputMap.event_is_action(joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), "aim"), "Triggers fire and aim")
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	var player = game.player
	Input.action_press("look_right", 1.0)
	var yaw_before: float = player.rotation.y
	player.stick_look(0.5)
	Input.action_release("look_right")
	check(player.rotation.y < yaw_before - 0.5, "Right stick turns the view")
	game._unhandled_input(joy_button(JOY_BUTTON_LEFT_SHOULDER))
	check(game.weapon.active == 1, "Left bumper cycles to the next weapon")
	game._unhandled_input(joy_button(JOY_BUTTON_LEFT_SHOULDER))
	check(game.weapon.active == 0, "Cycling wraps back to the rifle")
	var press := joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	game._unhandled_input(press)
	check(game.weapon.aiming and game.is_aiming(), "Pulling the left trigger aims")
	game._unhandled_input(joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	check(not game.weapon.aiming, "Releasing the left trigger stops aiming")
	# Tutorial.
	var level = game.level
	var log = level.mission_log
	check(log.status("t_aim") == log.Status.ACTIVE and log.status("t_ring_100") == log.Status.HIDDEN, "The tutorial starts with aiming")
	level.advance_tutorial()
	check(level.tutorial_step == 0, "Steps wait for their condition")
	game.weapon.toggle_aim()
	level.advance_tutorial()
	check(log.status("t_aim") == log.Status.COMPLETE and log.status("t_ring_100") == log.Status.ACTIVE, "Aiming completes the first step and reveals the next")
	check(not log.lines().has("[x] Aim down the scope (right click or left trigger) (optional)"), "Finished tutorial steps leave the HUD list")
	level.plate_at(100.0).take_hit(-1, 0.0)
	level.advance_tutorial()
	check(level.tutorial_step == 2, "Ringing the 100 m plate advances")
	game.measured_range = 320.0
	level.advance_tutorial()
	check(level.tutorial_step == 3, "Reading a long range advances")
	game.weapon.adjust_zero(2)
	level.advance_tutorial()
	check(level.tutorial_step == 4 and game.weapon.zero_range() == 300.0, "Zeroing to 300 m advances")
	level.plate_at(300.0).take_hit(-1, 0.0)
	game.sway.holding = true
	level.plate_at(700.0).take_hit(-1, 0.0)
	level.advance_tutorial()
	check(level.tutorial_done() and log.status("t_holdover") == log.Status.COMPLETE, "Conditions met together finish the remaining steps at once")
	check(not state.finished, "Finishing the tutorial does not end the range")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("TUTORIAL TESTS PASSED")
	quit(0 if failures == 0 else 1)
