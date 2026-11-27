extends Node

# Player settings persisted to user://settings.cfg. Sections mirror the options
# menu. apply() pushes values into the engine, GameState and the InputMap.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"video": {"fullscreen": false, "vsync": true, "fov": 75.0, "resolution_scale": 1.0},
	"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
	"controls": {"sensitivity": 1.0, "invert_y": false, "hold_to_aim": false},
	"gameplay": {"difficulty": 1, "killcam": true, "realism_ranging": false, "hud_assists": true},
	"accessibility": {"reduced_motion": false, "colorblind_reticle": false, "subtitles": true},
}
const REMAPPABLE := ["move_forward", "move_back", "move_left", "move_right", "sprint", "fire", "aim", "reload", "interact",
	"crouch", "prone", "hold_breath", "binoculars", "tag", "throw", "zero_up", "zero_down", "quick_save", "quick_load"]

signal changed(section: String, key: String, value: Variant)

var values: Dictionary = {}
var bindings: Dictionary = {}
var last_error := ""

func _ready() -> void:
	reset()
	load_settings()
	apply()

func reset() -> void:
	values = {}
	for section in DEFAULTS:
		values[section] = DEFAULTS[section].duplicate()
	bindings = {}

func get_value(section: String, key: String) -> Variant:
	return values.get(section, {}).get(key, DEFAULTS.get(section, {}).get(key))

func set_value(section: String, key: String, value: Variant) -> void:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		return
	values[section][key] = value
	changed.emit(section, key, value)

func save_settings() -> bool:
	var config := ConfigFile.new()
	for section in values:
		for key in values[section]:
			config.set_value(section, key, values[section][key])
	for action in bindings:
		config.set_value("bindings", action, bindings[action])
	var error := config.save(PATH)
	last_error = "" if error == OK else "Could not save settings: %s" % error_string(error)
	return error == OK

# Unreadable or malformed files leave the defaults in place.
func load_settings() -> bool:
	var config := ConfigFile.new()
	if not FileAccess.file_exists(PATH):
		return false
	var error := config.load(PATH)
	if error != OK:
		last_error = "Settings file unreadable, using defaults: %s" % error_string(error)
		return false
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			if config.has_section_key(section, key):
				var loaded = config.get_value(section, key)
				if typeof(loaded) == typeof(DEFAULTS[section][key]):
					values[section][key] = loaded
	if config.has_section("bindings"):
		for action in config.get_section_keys("bindings"):
			if action in REMAPPABLE:
				bindings[action] = String(config.get_value("bindings", action))
	return true

static func serialize_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event.keycode if event.keycode != KEY_NONE else event.physical_keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	if event is InputEventJoypadButton:
		return "pad:%d" % event.button_index
	return ""

static func deserialize_event(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var code := int(parts[1])
	match parts[0]:
		"key":
			var key := InputEventKey.new()
			key.keycode = code as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = code as MouseButton
			return mouse
		"pad":
			var pad := InputEventJoypadButton.new()
			pad.button_index = code as JoyButton
			return pad
	return null

func remap(action: String, event: InputEvent) -> bool:
	if action not in REMAPPABLE or event == null:
		return false
	var text := serialize_event(event)
	if text.is_empty():
		return false
	bindings[action] = text
	apply_binding(action, text)
	changed.emit("bindings", action, text)
	return true

# A binding replaces the action's events on its own device only: a new key or
# mouse button keeps the controller binding, and a new controller button keeps the key.
func apply_binding(action: String, text: String) -> void:
	var event := deserialize_event(text)
	if event == null or not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action):
		if is_pad_event(existing) == is_pad_event(event):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)

static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func clear_bindings() -> void:
	bindings = {}
	InputMap.load_from_project_settings()

func sensitivity() -> float:
	return clampf(float(get_value("controls", "sensitivity")), 0.1, 5.0)

func reduced_motion() -> bool:
	return bool(get_value("accessibility", "reduced_motion"))

func high_contrast_reticle() -> bool:
	return bool(get_value("accessibility", "colorblind_reticle"))

func realism_ranging() -> bool:
	return bool(get_value("gameplay", "realism_ranging"))

func invert_y() -> bool:
	return bool(get_value("controls", "invert_y"))

func apply() -> void:
	GameState.difficulty = clampi(int(get_value("gameplay", "difficulty")), 0, 2)
	for action in bindings:
		apply_binding(action, bindings[action])
	for bus_name in ["Master", "Music", "SFX"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			var key: String = String(bus_name).to_lower()
			AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(float(get_value("audio", key)), 0.0, 1.0)))
	var tree := get_tree()
	if tree and tree.root:
		tree.root.scaling_3d_scale = clampf(float(get_value("video", "resolution_scale")), 0.5, 1.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if get_value("video", "fullscreen") else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("video", "vsync") else DisplayServer.VSYNC_DISABLED)
