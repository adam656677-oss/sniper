class_name ScopeView
extends SubViewport

# Renders the magnified scope picture. The scope camera follows the player's
# camera every frame; magnification is relative to the hip field of view.
# The installed rifle optic sets the magnification range (see configure()).

const ZOOM_MIN := 4.0
const ZOOM_MAX := 12.0
const ZOOM_STEP := 2.0

var source: Camera3D
var weapon: WeaponRig
var zoom := ZOOM_MIN
var zoom_min := ZOOM_MIN
var zoom_max := ZOOM_MAX
var zoom_step := ZOOM_STEP
var configured: WeaponProfile
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	own_world_3d = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

static func fov_for_zoom(magnification: float, hip_fov: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_fov) * 0.5) / maxf(magnification, 1.0)))

# Follow a weapon rig: its projectile rifle's optic sets the magnification range,
# starting at the optic's lowest power. Handguns leave the rifle's optic in place.
func bind_weapon(rig: WeaponRig) -> void:
	weapon = rig
	configured = null
	sync_optic()
	zoom = zoom_min

# Take the magnification range from a profile and clamp the zoom into it.
func configure(profile: WeaponProfile) -> void:
	configured = profile
	zoom_min = maxf(profile.zoom_min, 1.0)
	zoom_max = maxf(profile.zoom_max, zoom_min)
	zoom_step = maxf(profile.zoom_step, 0.5)
	set_zoom(zoom)

func sync_optic() -> void:
	if weapon == null or weapon.profiles.is_empty():
		return
	var current := weapon.profile()
	if current.simulated_projectile and current != configured:
		configure(current)

func set_zoom(value: float) -> void:
	zoom = clampf(zoom_min + snappedf(value - zoom_min, zoom_step), zoom_min, zoom_max)

func zoom_in() -> bool:
	var before := zoom
	set_zoom(zoom + zoom_step)
	return zoom != before

func zoom_out() -> bool:
	var before := zoom
	set_zoom(zoom - zoom_step)
	return zoom != before

func current_fov() -> float:
	return fov_for_zoom(zoom, clampf(float(Settings.get_value("video", "fov")), 60.0, 110.0))

func follow() -> void:
	sync_optic()
	if source == null:
		return
	camera.global_transform = source.global_transform
	camera.fov = current_fov()
	camera.current = true

func _process(_delta: float) -> void:
	follow()
