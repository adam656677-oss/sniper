extends Control

# Story-first prologue presentation. This is a skippable narrative sequence;
# the playable home/ambush set piece is a later cinematic production task.

var beat_index := 0
var speaker_label: Label
var body_label: Label
var progress_label: Label
var next_button: Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not StoryCampaign.active:
		StoryCampaign.start_new_campaign()
	_build_ui()
	beat_index = clampi(StoryCampaign.prologue_beat, 0, StoryCampaign.PROLOGUE_BEATS.size() - 1)
	_render_beat()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.018, 0.026, 0.03)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 440)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = tr("ECHO RIDGE  //  STORY MODE")
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(0.75, 0.56, 0.31))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)
	var title := Label.new()
	title.text = tr("THE LAST QUIET NIGHT")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.92, 0.89, 0.81))
	column.add_child(title)
	var divider := HSeparator.new()
	column.add_child(divider)
	speaker_label = Label.new()
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 15)
	speaker_label.add_theme_color_override("font_color", Color(0.83, 0.66, 0.4))
	column.add_child(speaker_label)
	body_label = Label.new()
	body_label.custom_minimum_size = Vector2(680, 190)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 21)
	body_label.add_theme_color_override("font_color", Color(0.86, 0.87, 0.84))
	column.add_child(body_label)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.add_theme_color_override("font_color", Color(0.56, 0.58, 0.56))
	column.add_child(progress_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	column.add_child(actions)
	var skip := Button.new()
	skip.text = tr("Skip intro")
	skip.custom_minimum_size = Vector2(160, 42)
	skip.pressed.connect(_begin_mission)
	actions.add_child(skip)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(220, 42)
	next_button.pressed.connect(_advance)
	actions.add_child(next_button)

func _render_beat() -> void:
	var beat: Dictionary = StoryCampaign.PROLOGUE_BEATS[beat_index]
	speaker_label.text = tr(String(beat.speaker))
	body_label.text = tr(String(beat.text))
	progress_label.text = tr("PROLOGUE  //  %02d OF %02d") % [beat_index + 1, StoryCampaign.PROLOGUE_BEATS.size()]
	next_button.text = tr("Begin Kestrel Pass") if beat_index == StoryCampaign.PROLOGUE_BEATS.size() - 1 else tr("Continue")

func _advance() -> void:
	if beat_index >= StoryCampaign.PROLOGUE_BEATS.size() - 1:
		_begin_mission()
		return
	beat_index += 1
	StoryCampaign.set_prologue_beat(beat_index)
	_render_beat()

func _begin_mission() -> void:
	StoryCampaign.set_flag("prologue_intro_seen", true)
	get_tree().change_scene_to_file("res://scenes/ui/prologue_home.tscn")
