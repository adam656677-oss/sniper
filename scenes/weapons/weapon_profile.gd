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

func to_stats() -> Dictionary:
	return {
		"capacity": capacity, "reserve": reserve, "reload": reload_seconds, "interval": shot_interval,
		"pellets": pellets, "spread": spread, "range": max_range, "fov": aim_fov
	}
