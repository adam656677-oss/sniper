class_name PauseMenu
extends Control

# Shown while GameState.paused. Buttons call back into the mission.

var mission: Node
var panel: VBoxContainer
var settings_screen: SettingsScreen

func _ready() -> void:
	mission = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	panel = VBoxContainer.new()
	column.add_child(panel)
	var title := Label.new()
	title.text = "PAUSED"
	panel.add_child(title)
	button("Resume", func(): GameState.set_paused(false))
	button("Load checkpoint", func(): mission.load_slot(SaveSystem.CHECKPOINT_SLOT))
	button("Settings", func(): settings_screen.visible = true; panel.visible = false)
	button("Restart mission", func(): get_tree().reload_current_scene())
	button("Quit to menu", func(): mission.quit_to_menu())
	var help := Label.new()
	help.text = mission.CONTROLS_HELP if mission and mission.get("CONTROLS_HELP") else ""
	panel.add_child(help)
	settings_screen = SettingsScreen.new()
	settings_screen.visible = false
	settings_screen.closed.connect(func(): settings_screen.visible = false; panel.visible = true)
	column.add_child(settings_screen)
	visible = false

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

func _physics_process(_delta: float) -> void:
	var show := GameState.paused and not GameState.finished
	if show != visible:
		visible = show
		panel.visible = true
		settings_screen.visible = false
