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
	var origin: Vector3 = game.camera.global_position
	var finish: Vector3 = origin - game.camera.global_basis.z * 300.0
	var query := PhysicsRayQueryParameters3D.create(origin, finish)
	query.exclude = [game.player.get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	range_text = "RANGE --" if hit.is_empty() else "SURFACE %.0f m" % origin.distance_to(hit.position)
	queue_redraw()

# Reticle marks: screen offset below centre for each 100 m beyond the zero.
func holdover_marks() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	var game := mission()
	if game == null:
		return marks
	var weapon = game.weapon
	if not weapon.profile().simulated_projectile:
		return marks
	var viewport_size := get_viewport_rect().size
	var pixels_per_radian: float = (viewport_size.y * 0.5) / tan(deg_to_rad(game.camera.fov) * 0.5)
	var zero: float = weapon.zero_range()
	var distance := zero + 100.0
	while distance <= 1000.0:
		var hold: float = weapon.holdover_at(distance)
		marks.append({"range": distance, "pixels": atan2(hold, distance) * pixels_per_radian})
		distance += 100.0
	return marks

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * 0.38
	var ink := Color(0.04, 0.06, 0.04, 0.9)
	var tint := Color(0.0, 0.0, 0.0, 0.88)
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
	draw_string(font, center + Vector2(radius * 0.45, -radius * 0.75), "ZERO %.0f m" % game.weapon.zero_range(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	for mark in holdover_marks():
		var y: float = center.y + mark.pixels
		if y < center.y + radius:
			draw_line(Vector2(center.x - 12, y), Vector2(center.x + 12, y), ink, 1.0)
			draw_string(font, Vector2(center.x + 16, y + 4), "%d" % int(mark.range), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var wind: Vector3 = mission().weapon.wind
	draw_string(font, center + Vector2(-150, radius * 0.78), "Wind X/Z: %.1f / %.1f m/s" % [wind.x, wind.z], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, center + Vector2(-120, -radius * 0.75), "PROTOTYPE - UNCALIBRATED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
