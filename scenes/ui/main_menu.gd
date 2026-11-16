extends Control

# Main menu: continue from the last checkpoint, pick a mission, change settings, quit.
# scene_changer is swapped by tests so no scene change happens headlessly.

const MissionCatalog = preload("res://scenes/ui/mission_catalog.gd")

enum Screen { HOME, MISSIONS, SETTINGS, WORKBENCH, RECORDS }

var screen: int = Screen.HOME
var scene_changer: Callable
var home: VBoxContainer
var missions: VBoxContainer
var settings_screen: SettingsScreen
var workbench: WorkbenchScreen
var records: VBoxContainer
var records_text: Label
var continue_button: Button
var status: Label

func _ready() -> void:
	scene_changer = func(path: String): get_tree().change_scene_to_file(path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	center.add_child(column)
	home = VBoxContainer.new()
	column.add_child(home)
	var title := Label.new()
	title.text = "ECHO RIDGE"
	home.add_child(title)
	continue_button = button(home, "Continue", continue_checkpoint)
	button(home, "Missions", func(): show_screen(Screen.MISSIONS))
	button(home, "Workbench", func(): show_screen(Screen.WORKBENCH))
	button(home, "Records", func(): show_screen(Screen.RECORDS))
	button(home, "Settings", func(): show_screen(Screen.SETTINGS))
	button(home, "Quit", func(): get_tree().quit())
	status = Label.new()
	home.add_child(status)
	missions = VBoxContainer.new()
	column.add_child(missions)
	for i in range(MissionCatalog.count()):
		var mission: Dictionary = MissionCatalog.get_mission(i)
		button(missions, tr(String(mission.title)), func(): start_mission(i))
		var brief := Label.new()
		brief.text = tr(String(mission.brief))
		missions.add_child(brief)
	button(missions, "Back", func(): show_screen(Screen.HOME))
	settings_screen = SettingsScreen.new()
	settings_screen.closed.connect(func(): show_screen(Screen.HOME))
	column.add_child(settings_screen)
	workbench = WorkbenchScreen.new()
	workbench.closed.connect(func(): show_screen(Screen.HOME))
	column.add_child(workbench)
	records = VBoxContainer.new()
	column.add_child(records)
	records_text = Label.new()
	records.add_child(records_text)
	button(records, "Back", func(): show_screen(Screen.HOME))
	show_screen(Screen.HOME)

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func show_screen(value: int) -> void:
	screen = value
	home.visible = screen == Screen.HOME
	missions.visible = screen == Screen.MISSIONS
	settings_screen.visible = screen == Screen.SETTINGS
	workbench.visible = screen == Screen.WORKBENCH
	records.visible = screen == Screen.RECORDS
	if screen == Screen.RECORDS:
		records_text.text = "\n".join(Progression.summary_lines())
	if screen == Screen.WORKBENCH:
		workbench.load_into_controls()
	continue_button.disabled = not SaveSystem.has_save(SaveSystem.CHECKPOINT_SLOT)
	status.text = tr("Checkpoint available") if not continue_button.disabled else tr("No checkpoint yet")
	if screen == Screen.SETTINGS:
		settings_screen.load_into_controls()

func start_mission(index: int) -> String:
	var mission: Dictionary = MissionCatalog.get_mission(index)
	if mission.is_empty():
		return ""
	SaveSystem.pending = {}
	scene_changer.call(mission.scene)
	return mission.scene

func continue_checkpoint() -> String:
	if not SaveSystem.request_load(SaveSystem.CHECKPOINT_SLOT):
		status.text = tr("Checkpoint could not be loaded:") + " " + SaveSystem.last_error
		return ""
	var scene: String = String(SaveSystem.pending.scene)
	scene_changer.call(scene)
	return scene
