extends Node3D

# Mission root: wires the level, player, weapon rig and HUD together and
# routes input to the right system. Simulation state lives in GameState.

@onready var level: Node3D = $Level
@onready var player: Player = $Player
@onready var weapon: WeaponRig = $WeaponRig
@onready var hud: Label = $HUDLayer/HUD
var camera: Camera3D

func _ready() -> void:
	GameState.reset()
	camera = player.camera
	player.spawn_point = level.spawn_point
	player.position = level.spawn_point
	weapon.camera = camera
	weapon.excluded = [player.get_rid()]
	weapon.body_hit.connect(level.on_body_hit)
	update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		GameState.set_paused(true)

func interact() -> void:
	if level.near_terminal(player.position):
		GameState.collect_intel()
	if GameState.intel and level.near_extraction(player.position):
		GameState.finish_mission()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("pause"):
		if not GameState.finished:
			GameState.set_paused(not GameState.paused)
		return
	if not GameState.simulation_active():
		return
	if event.is_action_pressed("reload"):
		weapon.begin_reload()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("weapon_1"):
		weapon.select_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		weapon.select_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		weapon.select_weapon(2)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("fire"):
			weapon.fire_weapon()
		elif event.is_action_pressed("aim"):
			weapon.toggle_aim()

func update_hud() -> void:
	var objective := "Return to the green extraction marker and press E" if GameState.intel else "Reach the gold terminal ahead and press E"
	if GameState.finished:
		objective = "MISSION COMPLETE - N to restart"
	elif GameState.paused:
		objective = "PAUSED - Escape to resume | N to restart"
	hud.text = "ECHO RIDGE | prototype\n%s\n%s | Ammo %d / %d | %s | Targets left: %d | In flight: %d\n1-3 weapon | Left fire | Right aim | R reload | E interact | Escape pause" % [
		objective, weapon.profile().display_name, weapon.ammo, weapon.reserve_ammo, weapon.status_text(), level.targets.size(), weapon.projectiles.size()]

func _physics_process(delta: float) -> void:
	weapon.advance_weapon(delta)
	weapon.advance_projectiles(delta)
	if GameState.finished:
		weapon.projectiles.clear()
	update_hud()
