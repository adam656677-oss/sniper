class_name SettingsScreen
extends VBoxContainer

# Options panel bound to the Settings autoload. Built in code so it needs no scene file.

signal closed

const REMAP_LABELS := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right", "sprint": "Sprint",
	"fire": "Fire", "aim": "Aim", "reload": "Reload", "interact": "Interact", "crouch": "Crouch", "prone": "Prone",
	"hold_breath": "Hold breath", "binoculars": "Binoculars", "tag": "Tag target", "throw": "Throw stone",
	"zero_up": "Zero up", "zero_down": "Zero down", "quick_save": "Quick save", "quick_load": "Quick load",
}

var sliders: Dictionary = {} # "section/key" -> HSlider
var checks: Dictionary = {}  # "section/key" -> CheckBox
var difficulty: OptionButton
var remap_buttons: Dictionary = {} # action -> Button
var listening_action := ""
var tabs: TabContainer

func _ready() -> void:
	add_child(make_label("SETTINGS"))
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(600, 380)
	add_child(tabs)
	var video := page("Video")
	add_slider_to(video, "Field of view", "video", "fov", 60.0, 110.0, 1.0)
	add_slider_to(video, "Render scale", "video", "resolution_scale", 0.5, 1.0, 0.05)
	add_check_to(video, "Fullscreen", "video", "fullscreen")
	add_check_to(video, "Vertical sync", "video", "vsync")
	var audio := page("Audio")
	add_slider_to(audio, "Master volume", "audio", "master", 0.0, 1.0, 0.05)
	add_slider_to(audio, "Music volume", "audio", "music", 0.0, 1.0, 0.05)
	add_slider_to(audio, "Effects volume", "audio", "sfx", 0.0, 1.0, 0.05)
	var controls := page("Controls")
	add_slider_to(controls, "Mouse sensitivity", "controls", "sensitivity", 0.1, 5.0, 0.1)
	add_check_to(controls, "Invert vertical look", "controls", "invert_y")
	add_check_to(controls, "Hold to aim", "controls", "hold_to_aim")
	var gameplay := page("Gameplay")
	difficulty = OptionButton.new()
	for name in ["Easy", "Normal", "Hard"]:
		difficulty.add_item(name)
	gameplay.add_child(make_label("Difficulty"))
	gameplay.add_child(difficulty)
	add_check_to(gameplay, "Long-shot slow motion", "gameplay", "killcam")
	add_check_to(gameplay, "HUD assists", "gameplay", "hud_assists")
	add_check_to(gameplay, "Realistic ranging (binoculars only)", "gameplay", "realism_ranging")
	var access := page("Accessibility")
	add_check_to(access, "Reduced motion", "accessibility", "reduced_motion")
	add_check_to(access, "High-contrast reticle", "accessibility", "colorblind_reticle")
	add_check_to(access, "Subtitles", "accessibility", "subtitles")
	var keys := page("Keys")
	for action in Settings.REMAPPABLE:
		var row := HBoxContainer.new()
		keys.add_child(row)
		var label := make_label(REMAP_LABELS.get(action, action))
		label.custom_minimum_size = Vector2(160, 0)
		row.add_child(label)
		var button := make_button("", func(): start_listening(action))
		button.custom_minimum_size = Vector2(160, 0)
		row.add_child(button)
		remap_buttons[action] = button
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(make_button("Apply", apply_from_controls))
	row.add_child(make_button("Defaults", reset_to_defaults))
	row.add_child(make_button("Back", func(): closed.emit()))
	load_into_controls()

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func add_slider_to(parent: Node, text: String, section: String, key: String, minimum: float, maximum: float, step: float) -> HSlider:
	parent.add_child(make_label(text))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(240, 0)
	parent.add_child(slider)
	sliders[section + "/" + key] = slider
	return slider

func add_check_to(parent: Node, text: String, section: String, key: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	parent.add_child(box)
	checks[section + "/" + key] = box
	return box

# Key and mouse button names match the in-game prompts (InputGlyphs).
func binding_text(action: String) -> String:
	var event: InputEvent = InputGlyphs.binding(action, false)
	return InputGlyphs.event_text(event) if event else tr("Unbound")

func load_into_controls() -> void:
	for path in sliders:
		var parts: PackedStringArray = path.split("/")
		sliders[path].value = float(Settings.get_value(parts[0], parts[1]))
	for path in checks:
		var parts: PackedStringArray = path.split("/")
		checks[path].button_pressed = bool(Settings.get_value(parts[0], parts[1]))
	difficulty.selected = int(Settings.get_value("gameplay", "difficulty"))
	refresh_bindings()

func refresh_bindings() -> void:
	for action in remap_buttons:
		remap_buttons[action].text = "Press a key..." if action == listening_action else binding_text(action)

func start_listening(action: String) -> void:
	listening_action = action
	refresh_bindings()

# While listening, the next key or mouse button becomes the binding; Escape cancels.
func capture_binding(event: InputEvent) -> bool:
	if listening_action.is_empty() or not event.is_pressed():
		return false
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		listening_action = ""
		refresh_bindings()
		return true
	if event is InputEventKey or event is InputEventMouseButton:
		Settings.remap(listening_action, event)
		Settings.save_settings()
		listening_action = ""
		refresh_bindings()
		return true
	return false

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and capture_binding(event):
		get_viewport().set_input_as_handled()

func apply_from_controls() -> void:
	for path in sliders:
		var parts: PackedStringArray = path.split("/")
		Settings.set_value(parts[0], parts[1], sliders[path].value)
	for path in checks:
		var parts: PackedStringArray = path.split("/")
		Settings.set_value(parts[0], parts[1], checks[path].button_pressed)
	Settings.set_value("gameplay", "difficulty", difficulty.selected)
	Settings.apply()
	Settings.save_settings()

func reset_to_defaults() -> void:
	Settings.reset()
	Settings.clear_bindings()
	Settings.apply()
	Settings.save_settings()
	load_into_controls()
