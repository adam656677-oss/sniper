extends "res://main.gd"

const MAGAZINE_SIZE := 5
const RELOAD_SECONDS := 2.2
const SHOT_INTERVAL := 0.9
var reserve_ammo := 20
var reload_remaining := 0.0
var shot_remaining := 0.0
var paused := false

func begin_reload() -> bool:
	if paused or finished or reload_remaining > 0.0 or ammo >= MAGAZINE_SIZE or reserve_ammo <= 0:
		return false
	reload_remaining = RELOAD_SECONDS
	return true

func advance_weapon(delta: float) -> void:
	if paused or finished:
		return
	shot_remaining = maxf(0.0, shot_remaining - delta)
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining == 0.0:
			var transferred := mini(MAGAZINE_SIZE - ammo, reserve_ammo)
			ammo += transferred
			reserve_ammo -= transferred

func can_fire() -> bool:
	return not paused and not finished and ammo > 0 and reload_remaining == 0.0 and shot_remaining == 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			paused = not paused
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			return
		if event.keycode == KEY_N:
			get_tree().reload_current_scene()
			return
	if paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		begin_reload()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if not can_fire():
				return
			super._unhandled_input(event)
			shot_remaining = SHOT_INTERVAL
			return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	if paused:
		hud.text = "ECHO RIDGE | PAUSED\nEscape to resume | N to restart"
		return
	advance_weapon(delta)
	super._physics_process(delta)
	if player.position.y < -15.0:
		player.position = Vector3(0, 1, 3)
		player.velocity = Vector3.ZERO
	hud.text = hud.text.replace("Native 3D foundation", "Weapon prototype")
	hud.text = hud.text.replace("R refill", "R reload")
	hud.text = hud.text.replace("Escape release mouse", "Escape pause")
	hud.text += "\nReserve: %d" % reserve_ammo
	if reload_remaining > 0.0:
		hud.text += " | Reloading: %.1fs" % reload_remaining
	elif shot_remaining > 0.0:
		hud.text += " | Cycling bolt"
