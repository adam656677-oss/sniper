class_name WeaponProfile
extends Resource

# Fictional gameplay tuning for one weapon. Not real firearm specifications.
# The gunsmith module derives modified profiles from a base profile; see gunsmith.gd.

@export var display_name := "Rifle"
@export var family := "recon"
@export var capacity := 5
@export var reserve := 20
@export var reload_seconds := 2.2
@export var shot_interval := 0.9
@export var pellets := 1
@export var spread := 0.0
@export var max_range := 300.0
@export var aim_fov := 25.0
@export var simulated_projectile := false
@export var muzzle_velocity := 180.0
@export var drag_coefficient := 0.0
@export var zero_range := 0.0
@export var damage := 50.0
@export var suppressed := false
@export var recoil_degrees := 3.0
# Rifle optic: magnification range of the rendered scope view and the holdover
# reticle (a mark every reticle_step metres beyond the zero, out to reticle_max).
# The defaults are the standard 4x to 12x scope; gunsmith optics override them.
@export var zoom_min := 4.0
@export var zoom_max := 12.0
@export var zoom_step := 2.0
@export var reticle_step := 100.0
@export var reticle_max := 1000.0

func to_stats() -> Dictionary:
	return {
		"capacity": capacity, "reserve": reserve, "reload": reload_seconds, "interval": shot_interval,
		"pellets": pellets, "spread": spread, "range": max_range, "fov": aim_fov,
		"zoom_min": zoom_min, "zoom_max": zoom_max, "zoom_step": zoom_step,
		"reticle_step": reticle_step, "reticle_max": reticle_max
	}
