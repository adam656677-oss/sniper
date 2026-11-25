extends Label

# Mission HUD text. Content is written by the mission each physics frame.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 16)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size = Vector2(560, 0)
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
