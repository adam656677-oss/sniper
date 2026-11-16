class_name SettingsScreen
extends VBoxContainer

# Options panel bound to the Settings autoload. Built in code so it needs no scene file.

signal closed

var sensitivity: HSlider
var fov: HSlider
var invert: CheckBox
var fullscreen: CheckBox
var killcam: CheckBox
var hud_assists: CheckBox
var difficulty: OptionButton

func _ready() -> void:
	add_child(make_label("SETTINGS"))
	sensitivity = add_slider("Mouse sensitivity", 0.1, 5.0, 0.1)
	fov = add_slider("Field of view", 60.0, 110.0, 1.0)
	invert = add_check("Invert vertical look")
	fullscreen = add_check("Fullscreen")
	killcam = add_check("Long-shot slow motion")
	hud_assists = add_check("HUD assists")
	difficulty = OptionButton.new()
	for name in ["Easy", "Normal", "Hard"]:
		difficulty.add_item(name)
	add_child(make_label("Difficulty"))
	add_child(difficulty)
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(make_button("Apply", apply_from_controls))
	row.add_child(make_button("Defaults", reset_to_defaults))
	row.add_child(make_button("Back", func(): closed.emit()))
	load_into_controls()

func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func add_slider(text: String, minimum: float, maximum: float, step: float) -> HSlider:
	add_child(make_label(text))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(240, 0)
	add_child(slider)
	return slider

func add_check(text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	add_child(box)
	return box

func load_into_controls() -> void:
	sensitivity.value = float(Settings.get_value("controls", "sensitivity"))
	fov.value = float(Settings.get_value("video", "fov"))
	invert.button_pressed = bool(Settings.get_value("controls", "invert_y"))
	fullscreen.button_pressed = bool(Settings.get_value("video", "fullscreen"))
	killcam.button_pressed = bool(Settings.get_value("gameplay", "killcam"))
	hud_assists.button_pressed = bool(Settings.get_value("gameplay", "hud_assists"))
	difficulty.selected = int(Settings.get_value("gameplay", "difficulty"))

func apply_from_controls() -> void:
	Settings.set_value("controls", "sensitivity", sensitivity.value)
	Settings.set_value("video", "fov", fov.value)
	Settings.set_value("controls", "invert_y", invert.button_pressed)
	Settings.set_value("video", "fullscreen", fullscreen.button_pressed)
	Settings.set_value("gameplay", "killcam", killcam.button_pressed)
	Settings.set_value("gameplay", "hud_assists", hud_assists.button_pressed)
	Settings.set_value("gameplay", "difficulty", difficulty.selected)
	Settings.apply()
	Settings.save_settings()

func reset_to_defaults() -> void:
	Settings.reset()
	Settings.clear_bindings()
	Settings.apply()
	Settings.save_settings()
	load_into_controls()
