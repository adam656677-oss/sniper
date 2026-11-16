class_name ScopeView
extends SubViewport

# Renders the magnified scope picture. The scope camera follows the player's
# camera every frame; magnification is relative to the hip field of view.

const ZOOM_MIN := 4.0
const ZOOM_MAX := 12.0
const ZOOM_STEP := 2.0

var source: Camera3D
var zoom := ZOOM_MIN
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	own_world_3d = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

static func fov_for_zoom(magnification: float, hip_fov: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_fov) * 0.5) / maxf(magnification, 1.0)))

func set_zoom(value: float) -> void:
	zoom = clampf(snappedf(value, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)

func zoom_in() -> bool:
	var before := zoom
	set_zoom(zoom + ZOOM_STEP)
	return zoom != before

func zoom_out() -> bool:
	var before := zoom
	set_zoom(zoom - ZOOM_STEP)
	return zoom != before

func current_fov() -> float:
	return fov_for_zoom(zoom, clampf(float(Settings.get_value("video", "fov")), 60.0, 110.0))

func follow() -> void:
	if source == null:
		return
	camera.global_transform = source.global_transform
	camera.fov = current_fov()
	camera.current = true

func _process(_delta: float) -> void:
	follow()
