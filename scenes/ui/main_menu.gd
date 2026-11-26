extends Control

# Main menu: continue from the last checkpoint, pick a mission, change settings, quit.
# scene_changer is swapped by tests so no scene change happens headlessly.

const MissionCatalog = preload("res://scenes/ui/mission_catalog.gd")
const ThemeKit = preload("res://scenes/ui/ui_theme.gd")
const BackdropShader = preload("res://scenes/ui/menu_backdrop.gdshader")

enum Screen { HOME, MISSIONS, SETTINGS, WORKBENCH, RECORDS, EVIDENCE }

var screen: int = Screen.HOME
var scene_changer: Callable
var home: VBoxContainer
var missions: VBoxContainer
var settings_screen: SettingsScreen
var workbench: WorkbenchScreen
var records: VBoxContainer
var records_text: Label
var evidence: VBoxContainer
var evidence_text: Label
var continue_button: Button
var story_mode_button: Button
var continue_story_button: Button
var status: Label

func _ready() -> void:
	scene_changer = func(path: String): get_tree().change_scene_to_file(path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ThemeKit.apply(self)
	var backdrop := ColorRect.new()
	backdrop.name = "TacticalBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BackdropShader
	backdrop.material = backdrop_material
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	home = VBoxContainer.new()
	home.alignment = BoxContainer.ALIGNMENT_CENTER
	home.add_theme_constant_override("separation", 12)
	column.add_child(home)
	var title := Label.new()
	title.text = "ECHO RIDGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	title.add_theme_constant_override("outline_size", 3)
	home.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("FIELD OPERATIONS  //  SINGLE-PLAYER CAMPAIGN")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.58, 0.37))
	home.add_child(subtitle)
	continue_button = button(home, "Continue", continue_checkpoint)
	story_mode_button = button(home, tr("New Story"), start_story_mode)
	continue_story_button = button(home, tr("Continue Story"), continue_story)
	button(home, "Missions", func(): show_screen(Screen.MISSIONS))
	button(home, "Workbench", func(): show_screen(Screen.WORKBENCH))
	button(home, "Records", func(): show_screen(Screen.RECORDS))
	button(home, tr("Evidence"), func(): show_screen(Screen.EVIDENCE))
	button(home, "Settings", func(): show_screen(Screen.SETTINGS))
	button(home, "Quit", func(): get_tree().quit())
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	home.add_child(status)
	var version := Label.new()
	version.text = build_label()
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-220, -32)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.size = Vector2(210, 24)
	add_child(version)
	missions = VBoxContainer.new()
	column.add_child(missions)
	for i in range(MissionCatalog.count()):
		var mission: Dictionary = MissionCatalog.get_mission(i)
		button(missions, tr(String(mission.title)), func(): start_mission(i))
		var brief := Label.new()
		brief.text = tr(String(mission.brief))
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brief.custom_minimum_size = Vector2(340, 0)
		brief.add_theme_font_size_override("font_size", 12)
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
	evidence = VBoxContainer.new()
	column.add_child(evidence)
	evidence_text = Label.new()
	evidence_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_text.custom_minimum_size = Vector2(360, 180)
	evidence.add_child(evidence_text)
	button(evidence, "Back", func(): show_screen(Screen.HOME))
	show_screen(Screen.HOME)

# "v0.4.0 (abc1234)" when CI stamped a build, "v0.4.0 (dev)" otherwise.
static func build_label() -> String:
	var version := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var build := "dev"
	if FileAccess.file_exists("res://build_info.txt"):
		build = FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
	return "v%s (%s)" % [version, build]

func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 42)
	b.focus_mode = Control.FOCUS_ALL
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
	evidence.visible = screen == Screen.EVIDENCE
	if screen == Screen.RECORDS:
		records_text.text = "\n".join(Progression.summary_lines())
	if screen == Screen.EVIDENCE:
		evidence_text.text = "\n".join(StoryCampaign.evidence_lines())
	if screen == Screen.WORKBENCH:
		workbench.load_into_controls()
	continue_button.disabled = not SaveSystem.has_save(SaveSystem.CHECKPOINT_SLOT)
	continue_story_button.disabled = not StoryCampaign.can_continue()
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

func start_story_mode() -> String:
	StoryCampaign.start_new_campaign()
	continue_story_button.disabled = not StoryCampaign.can_continue()
	var path := "res://scenes/ui/story_prologue.tscn"
	scene_changer.call(path)
	return path

func continue_story() -> String:
	var path := StoryCampaign.continue_scene_path()
	if path.is_empty():
		return ""
	if StoryCampaign.active_chapter != "prologue":
		StoryCampaign.begin_chapter(StoryCampaign.active_chapter)
	scene_changer.call(path)
	return path
