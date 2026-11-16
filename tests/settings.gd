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

func run_tests() -> void:
	settings = root.get_node("Settings")
	state = root.get_node("GameState")
	settings.reset()
	settings.clear_bindings()
	check(settings.get_value("controls", "sensitivity") == 1.0 and settings.get_value("gameplay", "difficulty") == 1, "Defaults are in place")
	check(settings.get_value("nope", "x") == null, "Unknown settings read as null")
	settings.set_value("controls", "sensitivity", 2.5)
	settings.set_value("controls", "invert_y", true)
	settings.set_value("gameplay", "difficulty", 2)
	settings.set_value("gameplay", "killcam", false)
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
