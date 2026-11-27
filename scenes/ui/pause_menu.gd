class_name PauseMenu
extends Control

# Shown while GameState.paused. Buttons call back into the mission.

var mission: Node
var panel: VBoxContainer
var settings_screen: SettingsScreen
var help_label: Label
const ThemeKit = preload("res://scenes/ui/ui_theme.gd")

func _ready() -> void:
	mission = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ThemeKit.apply(self)
	var overlay := ColorRect.new()
	overlay.color = Color(0.008, 0.014, 0.014, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 0)
	column.add_child(card)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	card.add_child(panel)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.94, 0.78, 0.48))
	panel.add_child(title)
	button("Resume", func(): GameState.set_paused(false))
	button("Load checkpoint", func(): mission.load_slot(SaveSystem.CHECKPOINT_SLOT))
	button("Settings", func(): settings_screen.visible = true; panel.visible = false)
	button("Restart mission", func(): get_tree().reload_current_scene())
	button("Quit to menu", func(): mission.quit_to_menu())
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(help_label)
	refresh_help()
	InputGlyphs.device_changed.connect(on_device_changed)
	settings_screen = SettingsScreen.new()
	settings_screen.visible = false
	settings_screen.closed.connect(func(): settings_screen.visible = false; panel.visible = true)
	column.add_child(settings_screen)
	visible = false

# The controls help names the keys or the controller buttons, whichever was used last.
func refresh_help() -> void:
	help_label.text = mission.controls_help() if mission and mission.has_method("controls_help") else ""

func on_device_changed(_gamepad: bool) -> void:
	refresh_help()

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 40)
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

func _physics_process(_delta: float) -> void:
	var show := GameState.paused and not GameState.finished
	if show != visible:
		visible = show
		panel.visible = true
		settings_screen.visible = false
		if show:
			refresh_help()
