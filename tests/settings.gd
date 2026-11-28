extends SceneTree

var failures := 0
var settings: Node
var state: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func make_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click

func run_tests() -> void:
	settings = root.get_node("Settings")
	state = root.get_node("GameState")
	settings.reset()
	settings.clear_bindings()
	check(settings.get_value("controls", "sensitivity") == 1.0 and settings.get_value("gameplay", "difficulty") == 1, "Defaults are in place")
	check(settings.get_value("nope", "x") == null, "Unknown settings read as null")
	check(settings.get_value("gameplay", "blood_effects") == true, "Blood effects are on by default")
	settings.set_value("controls", "sensitivity", 2.5)
	settings.set_value("controls", "invert_y", true)
	settings.set_value("gameplay", "difficulty", 2)
	settings.set_value("gameplay", "killcam", false)
	settings.set_value("gameplay", "blood_effects", false)
	settings.set_value("nope", "x", 1)
	check(settings.values.has("nope") == false, "Unknown settings are ignored")
	check(settings.remap("reload", key_event(KEY_K)), "Reload can be remapped")
	check(InputMap.event_is_action(key_event(KEY_K), "reload") and not InputMap.event_is_action(key_event(KEY_R), "reload"), "Remap takes effect in the InputMap")
	check(not settings.remap("restart", key_event(KEY_X)), "Non-remappable actions are refused")
	check(settings.save_settings() and FileAccess.file_exists(settings.PATH), "Settings save to disk")
	settings.reset()
	settings.clear_bindings()
	check(settings.get_value("controls", "sensitivity") == 1.0 and InputMap.event_is_action(key_event(KEY_R), "reload"), "Reset restores defaults and bindings")
	check(settings.load_settings(), "Settings load from disk")
	settings.apply()
	check(settings.get_value("controls", "sensitivity") == 2.5 and settings.invert_y() and settings.get_value("gameplay", "killcam") == false, "Values round-trip")
	check(settings.get_value("gameplay", "blood_effects") == false, "Turning blood effects off round-trips")
	check(state.difficulty == state.Difficulty.HARD, "Applying settings sets the difficulty")
	check(InputMap.event_is_action(key_event(KEY_K), "reload"), "Bindings round-trip and apply")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(not game.killcam.enabled, "Mission honours the kill cam setting")
	var pitch_before: float = game.player.head.rotation.x
	game.player.look(Vector2(0, 10))
	check(game.player.head.rotation.x > pitch_before, "Inverted look raises the view on mouse-down")
	game.queue_free()
	await process_frame
	var serialized: String = settings.serialize_event(key_event(KEY_K))
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	check(serialized == "key:%d" % KEY_K and settings.serialize_event(mouse) == "mouse:3", "Events serialize to text")
	var back = settings.deserialize_event("mouse:3")
	check(back is InputEventMouseButton and back.button_index == MOUSE_BUTTON_MIDDLE and settings.deserialize_event("garbage") == null, "Events deserialize and reject garbage")
	# Settings screen: tabs, every option bound, remapping by listening.
	settings.reset()
	settings.clear_bindings()
	var screen = load("res://scenes/ui/settings_screen.gd").new()
	root.add_child(screen)
	await process_frame
	check(screen.tabs.get_tab_count() == 6, "Settings has video, audio, controls, gameplay, accessibility and key tabs")
	var bound := 0
	for section in settings.DEFAULTS:
		for key in settings.DEFAULTS[section]:
			if screen.sliders.has(section + "/" + key) or screen.checks.has(section + "/" + key) or key == "difficulty":
				bound += 1
	var total := 0
	for section in settings.DEFAULTS:
		total += settings.DEFAULTS[section].size()
	check(bound == total, "Every setting has a control (%d of %d)" % [bound, total])
	check(settings.get_value("controls", "aim_assist") == true and screen.checks.has("controls/aim_assist") and screen.checks["controls/aim_assist"].button_pressed, "Aim assist defaults on and has a check box")
	check(screen.remap_buttons.size() == settings.REMAPPABLE.size() and screen.remap_buttons["reload"].text == "R", "Every remappable action shows its key")
	screen.start_listening("reload")
	check(screen.remap_buttons["reload"].text == "Press a key...", "Choosing an action waits for a key")
	check(screen.capture_binding(key_event(KEY_J)) and screen.remap_buttons["reload"].text == "J", "The next key becomes the binding")
	check(InputMap.event_is_action(key_event(KEY_J), "reload"), "The captured key works in play")
	screen.start_listening("fire")
	check(screen.capture_binding(key_event(KEY_ESCAPE)) and screen.listening_action == "" and InputMap.event_is_action(make_click(), "fire"), "Escape cancels without changing the binding")
	screen.sliders["audio/music"].value = 0.25
	screen.checks["accessibility/reduced_motion"].button_pressed = true
	screen.checks["accessibility/colorblind_reticle"].button_pressed = true
	screen.checks["gameplay/realism_ranging"].button_pressed = true
	screen.sliders["video/resolution_scale"].value = 0.75
	var blood_box: CheckBox = screen.checks.get("gameplay/blood_effects")
	check(blood_box != null and blood_box.text == "Blood effects" and blood_box.get_parent().get_parent() == screen.tabs.get_node("Gameplay"), "Blood effects is a checkbox on the gameplay tab")
	check(blood_box != null and blood_box.button_pressed, "The blood effects box shows the default")
	if blood_box:
		blood_box.button_pressed = false
	screen.apply_from_controls()
	var saved := ConfigFile.new()
	check(settings.get_value("gameplay", "blood_effects") == false and saved.load(settings.PATH) == OK and saved.get_value("gameplay", "blood_effects", true) == false, "Unticking blood effects applies and saves it")
	var music := AudioServer.get_bus_index("Music")
	check(AudioServer.bus_count == 3 and music > 0 and absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.25)) < 0.01, "Music volume reaches its audio bus")
	check(is_equal_approx(root.scaling_3d_scale, 0.75), "Render scale reaches the viewport")
	screen.queue_free()
	await process_frame
	var mission = load("res://range_mission.tscn").instantiate()
	root.add_child(mission)
	mission.set_physics_process(false)
	await process_frame
	check(not mission.killcam.enabled, "Reduced motion disables slow motion")
	var overlay = mission.get_node("ScopeLayer/ScopeOverlay")
	check(overlay.reticle_ink().r > 0.9, "High-contrast reticle is bright")
	mission.weapon.toggle_aim()
	mission._physics_process(0.016)
	check(mission.measured_range < 0.0, "Realistic ranging hides range in the scope")
	mission.weapon.toggle_aim()
	mission.stealth.toggle_binoculars()
	mission._physics_process(0.016)
	check(mission.measured_range > 0.0, "Binoculars still range with realistic ranging")
	mission.queue_free()
	await process_frame
	settings.reset()
	settings.clear_bindings()
	settings.apply()
	var file := FileAccess.open(settings.PATH, FileAccess.WRITE)
	file.store_string("[controls]\nsensitivity = \"not a number\"\n[gameplay\n")
	file.close()
	settings.reset()
	check(not settings.load_settings() and settings.get_value("controls", "sensitivity") == 1.0, "A corrupt settings file leaves defaults in place")
	settings.reset()
	settings.clear_bindings()
	settings.save_settings()
	if failures == 0:
		print("SETTINGS TESTS PASSED")
	quit(0 if failures == 0 else 1)
