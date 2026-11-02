extends Control

var game: Node
var range_text := "RANGE --"

func _ready() -> void:
	game = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera):
		visible = false
		return
	visible = game.active_weapon == 0 and game.camera.fov < 70.0 and not game.paused and not game.finished
	if not visible:
		return
	var origin: Vector3 = game.camera.global_position
	var finish: Vector3 = origin - game.camera.global_basis.z * 300.0
	var query := PhysicsRayQueryParameters3D.create(origin, finish)
	query.exclude = [game.player.get_rid()]
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	range_text = "RANGE --" if hit.is_empty() else "SURFACE %.0f m" % origin.distance_to(hit.position)
	queue_redraw()

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
	var wind: Vector3 = game.wind_acceleration
	draw_string(font, center + Vector2(-150, radius * 0.78), "Wind acceleration X/Z: %.1f / %.1f m/s^2" % [wind.x, wind.z], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(font, center + Vector2(-120, -radius * 0.75), "PROTOTYPE - UNCALIBRATED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
