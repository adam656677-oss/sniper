extends CanvasLayer

# Lightweight subtitle/radio overlay shared by story scenes and missions.

var queue: Array[Dictionary] = []
var panel: PanelContainer
var speaker_label: Label
var line_label: Label
var continue_button: Button

func _ready() -> void:
	layer = 20
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.77
	panel.anchor_bottom = 0.97
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 13)
	speaker_label.add_theme_color_override("font_color", Color(0.86, 0.68, 0.39))
	column.add_child(speaker_label)
	line_label = Label.new()
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.add_theme_font_size_override("font_size", 17)
	line_label.custom_minimum_size = Vector2(0, 52)
	column.add_child(line_label)
	continue_button = Button.new()
	continue_button.text = tr("Continue")
	continue_button.custom_minimum_size = Vector2(150, 34)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_button.pressed.connect(advance)
	column.add_child(continue_button)
	panel.visible = false
	shade.visible = false

func enqueue(speaker: String, line: String) -> void:
	queue.append({"speaker": speaker, "line": line})
	if not panel.visible:
		_show_next()

func advance() -> void:
	if queue.is_empty():
		panel.visible = false
		get_child(0).visible = false
		return
	_show_next()

func _show_next() -> void:
	if queue.is_empty():
		panel.visible = false
		get_child(0).visible = false
		return
	var entry: Dictionary = queue.pop_front()
	speaker_label.text = String(entry.get("speaker", ""))
	line_label.text = String(entry.get("line", ""))
	panel.visible = true
	get_child(0).visible = true

func clear_queue() -> void:
	queue.clear()
	if is_instance_valid(panel):
		panel.visible = false
		get_child(0).visible = false
