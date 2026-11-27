extends Control

# Scope reticle drawn over the view while the projectile rifle is aimed.

var range_text := "RANGE --"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func mission() -> Node:
	return owner

func _physics_process(_delta: float) -> void:
	var game := mission()
	if game == null or not is_instance_valid(game.camera):
		visible = false
		return
	var scoped: bool = game.weapon.profile().simulated_projectile and game.camera.fov < 70.0
	visible = scoped and GameState.simulation_active()
	if not visible:
		return
	var measured: float = game.measured_range
	range_text = "RANGE --" if measured < 0.0 else "RANGE %.0f m" % measured
	queue_redraw()

# Reticle marks: screen offset below centre for each reticle step beyond the zero,
# out to the optic's reticle reach or the rifle's maximum range.
func holdover_marks() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	var game := mission()
	if game == null:
		return marks
	var weapon = game.weapon
	if not weapon.profile().simulated_projectile:
		return marks
	var viewport_size := get_viewport_rect().size
	var scope_fov: float = game.scope_view.current_fov() if game.get("scope_view") else game.camera.fov
	var radius := minf(viewport_size.x, viewport_size.y) * 0.38
	var pixels_per_radian: float = radius / tan(deg_to_rad(scope_fov) * 0.5)
	var optic: WeaponProfile = weapon.profile()
	var step := maxf(optic.reticle_step, 10.0)
	var reach := minf(optic.reticle_max, optic.max_range)
	var zero: float = weapon.zero_range()
	var distance := zero + step
	while distance <= reach + 0.001:
		var hold: float = weapon.holdover_at(distance)
		marks.append({"range": distance, "pixels": atan2(hold, distance) * pixels_per_radian})
		distance += step
	return marks

# The magnified picture from the scope viewport, as a textured disc.
func draw_scope_picture(center: Vector2, radius: float) -> void:
	var game := mission()
	if game == null or not game.get("scope_view"):
		return
	var texture: Texture2D = game.scope_view.get_texture()
	if texture == null:
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(64):
		var a := TAU * float(i) / 64.0
		var direction := Vector2(cos(a), sin(a))
		points.append(center + direction * radius)
		uvs.append(Vector2(0.5, 0.5) + direction * 0.5)
		colors.append(Color.WHITE)
	draw_polygon(points, colors, uvs, texture)

func reticle_ink() -> Color:
	return Color(1.0, 0.85, 0.0, 1.0) if Settings.high_contrast_reticle() else Color(0.04, 0.06, 0.04, 0.9)

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * 0.38
	var ink := reticle_ink()
	var tint := Color(0.0, 0.0, 0.0, 0.88)
	draw_scope_picture(center, radius)
	for i in range(96):
		var a := TAU * float(i) / 96.0
		var b := TAU * float(i + 1) / 96.0
		var u := Vector2(cos(a), sin(a))
		var v := Vector2(cos(b), sin(b))
		var outer := viewport_size.length()
		draw_colored_polygon(PackedVector2Array([center + u * radius, center + u * outer, center + v * outer, center + v * radius]), tint)
	draw_arc(center, radius, 0.0, TAU, 128, ink, 3.0, true)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), ink, 1.0, true)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), ink, 1.0, true)
	for tick in range(-4, 5):
		if tick == 0:
			continue
		var offset := float(tick) * radius / 6.0
		draw_line(center + Vector2(offset, -4), center + Vector2(offset, 4), ink, 1.0)
		draw_line(center + Vector2(-4, offset), center + Vector2(4, offset), ink, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-90, radius * 0.65), range_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var game := mission()
	draw_string(font, center + Vector2(radius * 0.45, -radius * 0.75), "ZERO %.0f m | %.0fx" % [game.weapon.zero_range(), game.scope_view.zoom], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var last_label_y := -1000.0
	var label_every := int(maxf(game.weapon.profile().reticle_step, 10.0) * 2.0)
	for mark in holdover_marks():
		var y: float = center.y + mark.pixels
		if y < center.y + radius:
			draw_line(Vector2(center.x - 12, y), Vector2(center.x + 12, y), ink, 1.0)
			if int(mark.range) % label_every == 0 and mark.pixels - last_label_y >= 12.0:
				draw_string(font, Vector2(center.x + 16, y + 4), "%d" % int(mark.range), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
				last_label_y = mark.pixels
	draw_string(font, center + Vector2(-150, radius * 0.78), game.wind_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
