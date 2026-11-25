extends Label

# Mission HUD text. Content is written by the mission each physics frame.

const ThemeKit = preload("res://scenes/ui/ui_theme.gd")

func _ready() -> void:
	ThemeKit.apply(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(16, 16)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size = Vector2(600, 0)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.88, 0.91, 0.87))
	add_theme_constant_override("outline_size", 2)
	add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.018, 0.95))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
