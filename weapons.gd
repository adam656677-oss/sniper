extends "res://gameplay.gd"

# Fictional gameplay tuning, not verified firearm specifications.
const LOADOUT := [
	{"name": "Recon rifle", "capacity": 5, "reserve": 20, "reload": 2.2, "interval": 0.9, "pellets": 1, "spread": 0.0, "range": 300.0, "fov": 25.0},
	{"name": "Fostech Origin 12", "capacity": 8, "reserve": 32, "reload": 2.6, "interval": 0.35, "pellets": 8, "spread": 0.055, "range": 45.0, "fov": 60.0},
	{"name": "Kel-Tec KSG Tactical", "capacity": 14, "reserve": 28, "reload": 5.0, "interval": 0.95, "pellets": 8, "spread": 0.045, "range": 50.0, "fov": 60.0}
]
var active_weapon := 0
var stored: Array[Dictionary] = []
var spread_rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	spread_rng.randomize()
	for profile in LOADOUT:
		stored.append({"ammo": int(profile.capacity), "reserve": int(profile.reserve), "cooldown": 0.0})

func select_weapon(index: int) -> bool:
	if paused or finished or reload_remaining > 0.0 or index < 0 or index >= LOADOUT.size():
		return false
	stored[active_weapon] = {"ammo": ammo, "reserve": reserve_ammo, "cooldown": shot_remaining}
	active_weapon = index
	ammo = int(stored[index].ammo)
	reserve_ammo = int(stored[index].reserve)
	shot_remaining = float(stored[index].cooldown)
	camera.fov = 75.0
	return true

func begin_reload() -> bool:
	if paused or finished or reload_remaining > 0.0 or ammo >= int(LOADOUT[active_weapon].capacity) or reserve_ammo <= 0:
		return false
	reload_remaining = float(LOADOUT[active_weapon].reload)
	return true

func advance_weapon(delta: float) -> void:
	if paused or finished:
		return
	var elapsed := maxf(delta, 0.0)
	shot_remaining = maxf(0.0, shot_remaining - elapsed)
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - elapsed)
		if reload_remaining == 0.0:
			var transfer := mini(int(LOADOUT[active_weapon].capacity) - ammo, reserve_ammo)
			ammo += transfer
			reserve_ammo -= transfer

func fire_weapon() -> bool:
	if not can_fire():
		return false
	ammo -= 1
	var profile: Dictionary = LOADOUT[active_weapon]
	shot_remaining = float(profile.interval)
	for pellet in range(int(profile.pellets)):
		var angle := spread_rng.randf_range(0.0, TAU)
		var radius := sqrt(spread_rng.randf()) * float(profile.spread)
		var local_direction := Vector3(cos(angle) * radius, sin(angle) * radius, -1.0).normalized()
		var direction := camera.global_basis * local_direction
		var origin := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * float(profile.range))
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider in targets:
			targets.erase(hit.collider)
			hit.collider.queue_free()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not paused and not finished:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_1, KEY_2, KEY_3]:
				select_weapon(int(event.keycode) - int(KEY_1))
				return
		if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_LEFT:
				fire_weapon()
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				camera.fov = float(LOADOUT[active_weapon].fov) if camera.fov > 70.0 else 75.0
				return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not paused:
		hud.text = hud.text.replace("Cycling bolt", "Weapon cycling")
		hud.text += "\nWeapon: %s | 1 Rifle | 2 Origin 12 | 3 KSG" % LOADOUT[active_weapon].name
