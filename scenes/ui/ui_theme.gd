extends RefCounted
class_name UITheme

# Shared visual language for the tactical interface: charcoal surfaces,
# restrained amber accents and readable cool-white text.
static func apply(root: Control) -> void:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", Color(0.82, 0.86, 0.84))
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.8))
	theme.set_color("font_color", "Button", Color(0.88, 0.90, 0.86))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.94, 0.78))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.78, 0.42))
	theme.set_color("font_disabled_color", "Button", Color(0.40, 0.43, 0.42))
	theme.set_font_size("font_size", "Label", 16)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_constant("outline_size", "Label", 1)
	theme.set_color("font_outline_color", "Label", Color(0.02, 0.03, 0.03, 0.9))
	theme.set_constant("h_separation", "Button", 12)
	theme.set_constant("v_separation", "VBoxContainer", 10)
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 12)
	var normal := _panel(Color(0.075, 0.09, 0.09, 0.96), Color(0.24, 0.29, 0.28, 0.9), 1, 5)
	var hover := _panel(Color(0.14, 0.15, 0.13, 0.99), Color(0.76, 0.48, 0.20, 1.0), 2, 5)
	var pressed := _panel(Color(0.20, 0.15, 0.10, 1.0), Color(0.95, 0.63, 0.27, 1.0), 2, 5)
	var disabled := _panel(Color(0.055, 0.065, 0.065, 0.8), Color(0.16, 0.18, 0.18, 0.8), 1, 5)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("panel", "PanelContainer", _panel(Color(0.035, 0.047, 0.047, 0.94), Color(0.30, 0.34, 0.31, 0.95), 1, 10))
	theme.set_stylebox("panel", "TabContainer", _panel(Color(0.035, 0.047, 0.047, 0.92), Color(0.22, 0.27, 0.25, 0.9), 1, 6))
	theme.set_color("font_color", "TabBar", Color(0.75, 0.80, 0.77))
	theme.set_color("font_selected_color", "TabBar", Color(1.0, 0.78, 0.42))
	root.theme = theme

static func _panel(fill: Color, border: Color, border_size: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_size)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
