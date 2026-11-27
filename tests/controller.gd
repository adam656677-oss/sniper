extends SceneTree

# Controller support: the InputGlyphs device tracker and its prompt text, prompts
# and tutorial steps following the device mid-mission, the aim assist setting,
# and right-stick friction over a hostile that never moves the aim by itself.

var failures := 0
var settings: Node
var state: Node
var glyphs: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func key_event(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event

func mouse_button(index: MouseButton, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event

func joy_button(index: JoyButton, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func defaults() -> void:
	settings.reset()
	settings.clear_bindings()
	settings.apply()

# The controller's guide button and F12 have no action, so they switch the device
# without doing anything in play. Parsed events are buffered and dispatched at the
# start of a later frame, so wait two.
func touch_controller() -> void:
	Input.parse_input_event(joy_button(JOY_BUTTON_GUIDE))
	Input.parse_input_event(joy_button(JOY_BUTTON_GUIDE, false))
	await process_frame
	await process_frame

func touch_keyboard() -> void:
	Input.parse_input_event(key_event(KEY_F12))
	Input.parse_input_event(key_event(KEY_F12, false))
	await process_frame
	await process_frame

func run_tests() -> void:
	settings = root.get_node("Settings")
	state = root.get_node("GameState")
	glyphs = root.get_node_or_null("InputGlyphs")
	defaults()
	check(glyphs != null, "An InputGlyphs autoload tracks the input device")
	if glyphs != null:
		await device_tests()
		glyph_tests()
		await prompt_tests()
		await aim_assist_setting_tests()
		await friction_tests()
	defaults()
	settings.save_settings()
	if failures == 0:
		print("CONTROLLER TESTS PASSED")
	quit(0 if failures == 0 else 1)

func device_tests() -> void:
	glyphs.set_gamepad(false)
	var switches: Array = []
	var record := func(pad: bool): switches.append(pad)
	glyphs.device_changed.connect(record)
	check(not glyphs.gamepad, "Keyboard and mouse is the starting device")
	glyphs.note_event(joy_button(JOY_BUTTON_A))
	check(glyphs.gamepad and switches == [true], "A controller button press switches to the controller and signals it")
	glyphs.note_event(key_event(KEY_W))
	check(not glyphs.gamepad and switches == [true, false], "A key press switches back to keyboard and mouse")
	glyphs.note_event(joy_axis(JOY_AXIS_RIGHT_X, 0.15))
	check(not glyphs.gamepad, "Stick drift inside the dead zone does not switch")
	glyphs.note_event(joy_axis(JOY_AXIS_RIGHT_X, 0.8))
	check(glyphs.gamepad, "Pushing a stick switches to the controller")
	glyphs.note_event(mouse_motion(Vector2(1, 1)))
	check(glyphs.gamepad, "A one-pixel mouse nudge does not switch")
	glyphs.note_event(mouse_motion(Vector2(30, 5)))
	check(not glyphs.gamepad, "Moving the mouse switches to keyboard and mouse")
	glyphs.note_event(joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	check(glyphs.gamepad, "Pulling a trigger switches to the controller")
	glyphs.note_event(key_event(KEY_W, false))
	check(glyphs.gamepad, "A key release alone does not switch")
	glyphs.note_event(mouse_button(MOUSE_BUTTON_LEFT))
	check(not glyphs.gamepad, "A mouse click switches to keyboard and mouse")
	var count := switches.size()
	glyphs.note_event(key_event(KEY_E))
	check(switches.size() == count, "Staying on one device does not signal a change")
	glyphs.device_changed.disconnect(record)
	await touch_controller()
	check(glyphs.gamepad, "A controller event from the engine's input path reaches the tracker")
	await touch_keyboard()
	check(not glyphs.gamepad, "A key event from the engine's input path reaches the tracker")

func glyph_tests() -> void:
	defaults()
	var keyboard := {"interact": "E", "reload": "R", "sprint": "Shift", "fire": "Left click", "aim": "Right click",
		"zoom_in": "Wheel up", "zoom_out": "Wheel down", "zero_up": "]", "zero_down": "[", "pause": "Escape", "quick_save": "F5", "quick_load": "F9", "takedown": "F"}
	var wrong: Array[String] = []
	for action in keyboard:
		if glyphs.glyph_for(action, false) != keyboard[action]:
			wrong.append("%s=%s" % [action, glyphs.glyph_for(action, false)])
	check(wrong.is_empty(), "Keyboard and mouse prompts name the bound key or button" + ("" if wrong.is_empty() else ": " + ", ".join(wrong)))
	var pad := {"interact": "A", "crouch": "B", "reload": "X", "binoculars": "Y", "next_weapon": "LB", "tag": "RB",
		"aim": "LT", "fire": "RT", "sprint": "L3", "hold_breath": "L3", "prone": "R3", "pause": "Start", "zero_up": "D-pad Up",
		"zero_down": "D-pad Down", "throw": "D-pad Left", "zoom_in": "D-pad Right", "move_forward": "Left stick", "look_left": "Right stick"}
	wrong.clear()
	for action in pad:
		if glyphs.glyph_for(action, true) != pad[action]:
			wrong.append("%s=%s" % [action, glyphs.glyph_for(action, true)])
	check(wrong.is_empty(), "Controller prompts use Xbox-style button names" + ("" if wrong.is_empty() else ": " + ", ".join(wrong)))
	glyphs.set_gamepad(false)
	var on_keyboard: String = glyphs.glyph("interact")
	glyphs.set_gamepad(true)
	check(on_keyboard == "E" and glyphs.glyph("interact") == "A", "The current-device prompt follows the last device used")
	glyphs.set_gamepad(false)
	settings.remap("interact", key_event(KEY_H))
	check(glyphs.glyph_for("interact", false) == "H", "A remapped key shows its new key")
	check(glyphs.glyph_for("interact", true) == "A" and InputMap.event_is_action(joy_button(JOY_BUTTON_A), "interact"), "Remapping the key keeps the controller button")
	settings.remap("fire", mouse_button(MOUSE_BUTTON_MIDDLE))
	check(glyphs.glyph_for("fire", false) == "Middle click" and glyphs.glyph_for("fire", true) == "RT", "A remapped mouse button shows its name and keeps the trigger")
	settings.remap("reload", joy_button(JOY_BUTTON_Y))
	check(glyphs.glyph_for("reload", true) == "Y" and glyphs.glyph_for("reload", false) == "R", "A remapped controller button shows its name and keeps the key")
	defaults()
	check(glyphs.glyph_for("interact", false) == "E" and glyphs.glyph_for("fire", false) == "Left click" and glyphs.glyph_for("reload", true) == "X", "Clearing bindings restores the default prompts")
	check(glyphs.has_binding("interact", true) and not glyphs.has_binding("restart", true) and not glyphs.has_binding("next_weapon", false), "Bindings are known per device")
	check(glyphs.glyph_for("restart", true) == "N", "An action with no controller binding falls back to its key")
	check(glyphs.glyph_for("no_such_action", true) == "Unbound", "An unknown action reads as unbound")
	glyphs.set_gamepad(false)
	check(glyphs.fill("Press {interact} to use {nope}") == "Press E to use {nope}", "Prompt tokens become the key and unknown tokens stay as written")
	glyphs.set_gamepad(true)
	check(glyphs.fill("Press {interact}") == "Press A", "Prompt tokens become the controller button")
	check(glyphs.fill_bound("{restart} restart") == "" and glyphs.fill_bound("{interact} interact") == "A interact", "Help entries for actions the controller cannot reach are left out")
	glyphs.set_gamepad(false)

func prompt_tests() -> void:
	defaults()
	glyphs.set_gamepad(false)
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var log = game.level.mission_log
	check(log.lines().has("[ ] Aim down the scope (Right click) (optional)"), "The first tutorial step names the mouse button")
	await frames(1)
	check(game.hud.text.contains("Aim down the scope (Right click)"), "The HUD shows the keyboard prompt")
	await touch_controller()
	await frames(2)
	check(glyphs.gamepad and game.hud.text.contains("Aim down the scope (LT)"), "Touching the controller mid-mission switches the HUD prompt to LT")
	check(log.line(log.find("t_zero")).contains("Raise your zero to 300 m with D-pad Up") and log.line(log.find("t_breath")).contains("Hold your breath (L3) while scoped"), "Later tutorial steps name controller buttons")
	await touch_keyboard()
	await frames(2)
	check(game.hud.text.contains("Aim down the scope (Right click)") and log.line(log.find("t_zero")).contains("with ]") and log.line(log.find("t_breath")).contains("(Shift)"), "Going back to the keyboard restores the key prompts")
	settings.remap("aim", mouse_button(MOUSE_BUTTON_MIDDLE))
	await frames(2)
	check(game.hud.text.contains("Aim down the scope (Middle click)"), "The tutorial prompt follows a remapped aim button")
	defaults()
	var help: String = game.controls_help()
	check(help.contains("Shift sprint, or hold breath while aiming") and help.contains("E interact") and help.contains("Left click fire") and help.contains("F silent takedown") and help.contains("2–4 handguns") and help.contains("F5 quick save") and help.contains("F9 quick load"), "Keyboard help lists the keys")
	check(not help.contains("next weapon"), "Keyboard help leaves out the controller-only weapon cycle")
	glyphs.set_gamepad(true)
	help = game.controls_help()
	check(help.contains("L3 sprint, or hold breath while aiming") and help.contains("A interact") and help.contains("RT fire") and help.contains("LT aim") and help.contains("LB next weapon") and help.contains("Start pause"), "Controller help lists the buttons")
	check(not help.contains("silent takedown") and not help.contains("quick save") and not help.contains("Shift"), "Controller help leaves out keyboard-only actions")
	glyphs.set_gamepad(false)
	var body := Node3D.new()
	game.add_child(body)
	game.player.carrying = body
	await frames(2)
	check(game.hud.text.contains("CARRYING BODY (E to drop)"), "The carry prompt names the interact key")
	await touch_controller()
	await frames(2)
	check(game.hud.text.contains("CARRYING BODY (A to drop)"), "The carry prompt names the interact button on the controller")
	game.player.carrying = null
	body.queue_free()
	var pause = game.get_node("HUDLayer/PauseMenu")
	await touch_keyboard()
	state.set_paused(true)
	await frames(2)
	check(pause.visible and pause.help_label.text.contains("E interact"), "The pause menu help shows keys")
	await touch_controller()
	check(pause.help_label.text.contains("A interact") and not pause.help_label.text.contains("E interact"), "The pause menu help follows a device switch while paused")
	state.set_paused(false)
	game.queue_free()
	await process_frame
	await touch_keyboard()
	var recon = load("res://main.tscn").instantiate()
	root.add_child(recon)
	await frames(2)
	check(recon.level.mission_log.lines()[0].contains("Reach the gold terminal ahead and press E"), "Mission objectives name the interact key")
	await touch_controller()
	check(recon.level.mission_log.lines()[0].contains("Reach the gold terminal ahead and press A"), "Mission objectives name the interact button on the controller")
	recon.queue_free()
	await process_frame
	await touch_keyboard()

func aim_assist_setting_tests() -> void:
	defaults()
	check(settings.get_value("controls", "aim_assist") == true and settings.has_method("aim_assist") and settings.aim_assist(), "Aim assist is on by default")
	var screen = load("res://scenes/ui/settings_screen.gd").new()
	root.add_child(screen)
	await process_frame
	var box: CheckBox = screen.checks.get("controls/aim_assist")
	check(box != null and box.button_pressed and box.get_parent().get_parent().name == "Controls", "The controls tab has a ticked aim assist check box")
	if box != null:
		box.button_pressed = false
		screen.apply_from_controls()
	check(settings.get_value("controls", "aim_assist") == false, "Unticking it turns aim assist off")
	settings.reset()
	check(settings.get_value("controls", "aim_assist") == true and settings.load_settings() and settings.get_value("controls", "aim_assist") == false, "Aim assist off persists in the settings file")
	screen.queue_free()
	await process_frame
	defaults()
	settings.save_settings()

# One right-stick look step from the current aim; returns the yaw and pitch change and puts the aim back.
func stick_step(player: Node, stick: Vector2, delta := 0.1) -> Vector2:
	for action in ["look_left", "look_right", "look_up", "look_down"]:
		Input.action_release(action)
	if stick.x > 0.0:
		Input.action_press("look_right", stick.x)
	if stick.y > 0.0:
		Input.action_press("look_down", stick.y)
	var yaw: float = player.rotation.y
	var pitch: float = player.head.rotation.x
	player.stick_look(delta)
	var change := Vector2(player.rotation.y - yaw, player.head.rotation.x - pitch)
	for action in ["look_left", "look_right", "look_up", "look_down"]:
		Input.action_release(action)
	player.rotation.y = yaw
	player.head.rotation.x = pitch
	return change

func mouse_step(player: Node, relative: Vector2) -> Vector2:
	var yaw: float = player.rotation.y
	var pitch: float = player.head.rotation.x
	player.look(relative)
	var change := Vector2(player.rotation.y - yaw, player.head.rotation.x - pitch)
	player.rotation.y = yaw
	player.head.rotation.x = pitch
	return change

func friction_tests() -> void:
	defaults()
	var game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await frames(3)
	var player = game.player
	var camera: Camera3D = game.camera
	var assist_path := "res://scenes/player/aim_assist.gd"
	check(ResourceLoader.exists(assist_path) and game.has_method("aim_friction") and player.get("look_friction") != null, "The mission feeds aim friction into the player's stick look")
	if not ResourceLoader.exists(assist_path) or not game.has_method("aim_friction"):
		game.queue_free()
		return
	var forward := -camera.global_basis.z
	var right := camera.global_basis.x
	var aim_point := camera.global_position + forward * 25.0
	var free := stick_step(player, Vector2(1, 0))
	var free_mouse := mouse_step(player, Vector2(40, 0))
	check(free.x < 0.0 and is_equal_approx(game.aim_friction(), 1.0), "With no hostile in sight the stick turns at full speed")
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.name = "AssistHostile"
	game.level.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = aim_point
	game.level.register_enemy(enemy)
	await frames(2)
	state.difficulty = state.Difficulty.NORMAL
	var expected: float = 1.0 - load(assist_path).strength_for(state.perception_multiplier())
	var slowed := stick_step(player, Vector2(1, 0))
	check(slowed.x < 0.0 and absf(slowed.x / free.x - expected) < 0.01, "A hostile under the crosshair slows the stick to %.0f%% (%.2f)" % [expected * 100.0, slowed.x / free.x])
	check(expected > 0.4 and expected < 0.8, "Friction slows but never stops the stick at Normal")
	settings.set_value("controls", "aim_assist", false)
	var off := stick_step(player, Vector2(1, 0))
	var diagonal_free := stick_step(player, Vector2(0.6, 0.3))
	settings.set_value("controls", "aim_assist", true)
	check(is_equal_approx(off.x, free.x), "With aim assist off the stick turns at full speed over a hostile")
	var mouse_over := mouse_step(player, Vector2(40, 0))
	check(is_equal_approx(mouse_over.x, free_mouse.x), "Mouse look gets no friction over a hostile")
	var diagonal := stick_step(player, Vector2(0.6, 0.3))
	var diagonal_free_ratio := diagonal_free.y / diagonal_free.x
	check(absf(diagonal.y / diagonal.x - diagonal_free_ratio) < 0.001 and absf(diagonal.x / diagonal_free.x - expected) < 0.01, "Friction scales the stick evenly, so the aim keeps the direction the player pushes")
	var yaw: float = player.rotation.y
	var pitch: float = player.head.rotation.x
	enemy.global_position = aim_point + right * 0.5
	await frames(1)
	var near: float = game.aim_friction()
	player.stick_look(0.5)
	check(is_equal_approx(player.rotation.y, yaw) and is_equal_approx(player.head.rotation.x, pitch), "With the stick at rest a nearby hostile never pulls the aim")
	check(near < 1.0 and near > expected, "A hostile just beside the crosshair gives lighter friction (%.2f)" % near)
	enemy.global_position = aim_point + right * 4.0
	await frames(1)
	check(is_equal_approx(stick_step(player, Vector2(1, 0)).x, free.x), "A hostile well off the crosshair gives no friction")
	enemy.global_position = aim_point
	var wall: Node3D = game.level.spawn_box(camera.global_position + forward * 12.0, Vector3(4, 4, 0.5), Color(0.4, 0.4, 0.4))
	await frames(2)
	check(is_equal_approx(stick_step(player, Vector2(1, 0)).x, free.x), "A hostile behind cover gives no friction")
	wall.queue_free()
	await frames(2)
	game.weapon.toggle_aim()
	check(game.is_aiming(), "The rifle scope is up")
	settings.set_value("controls", "aim_assist", false)
	var scoped_free := stick_step(player, Vector2(1, 0))
	settings.set_value("controls", "aim_assist", true)
	var scoped := stick_step(player, Vector2(1, 0))
	check(absf(scoped.x / scoped_free.x - expected) < 0.01, "The scope centre over a hostile gets the same friction")
	game.weapon.toggle_aim()
	state.difficulty = state.Difficulty.HARD
	var hard := stick_step(player, Vector2(1, 0)).x / free.x
	state.difficulty = state.Difficulty.EASY
	var easy := stick_step(player, Vector2(1, 0)).x / free.x
	state.difficulty = state.Difficulty.NORMAL
	check(hard > expected and hard < 1.0, "Hard gives less help (%.2f of full speed)" % hard)
	check(easy < expected and easy > 0.2, "Easy gives more help (%.2f of full speed)" % easy)
	var before := -camera.global_basis.z
	game.aim_friction()
	check(before.is_equal_approx(-camera.global_basis.z), "Checking for friction leaves the aim where it was")
	enemy.die()
	await frames(1)
	check(is_equal_approx(stick_step(player, Vector2(1, 0)).x, free.x), "A dead hostile gives no friction")
	game.queue_free()
	await process_frame
