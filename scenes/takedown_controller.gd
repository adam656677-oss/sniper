class_name TakedownController
extends Node3D

# Close-range stealth finisher with a short third-person camera beat.
# This is a gameplay/camera foundation; authored character animation replaces
# the simple procedural pose/collapse in a later art pass.

const MAX_RANGE := 2.2
const CAMERA_MOVE_SECONDS := 0.38
const FINISH_SECONDS := 1.25
const KILL_AT_SECONDS := 0.58

var mission: Node
var player: Variant
var level: Variant
var return_camera: Camera3D
var cinematic_camera: Camera3D
var hud_layer: CanvasLayer
var viewmodel: Variant
var target: Variant
var active := false
var elapsed := 0.0
var kill_applied := false
var start_transform := Transform3D.IDENTITY
var finish_transform := Transform3D.IDENTITY
var target_focus := Vector3.ZERO
var player_was_processing := true
var level_was_processing := true
var enemy_processing: Array[Dictionary] = []

func bind(owner: Node) -> void:
	mission = owner
	player = owner.player
	level = owner.level
	return_camera = owner.camera
	hud_layer = owner.get_node("HUDLayer")
	viewmodel = owner.viewmodel
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "TakedownCamera"
	cinematic_camera.fov = 58.0
	cinematic_camera.current = false
	add_child(cinematic_camera)

func candidate() -> Variant:
	if not player or not level or player.carrying:
		return null
	var best: Variant = null
	var best_distance := MAX_RANGE
	for item in level.enemies:
		var enemy = item
		if enemy == null or not enemy.is_alive() or enemy.state == 3 or enemy.state == 5:
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance > best_distance:
			continue
		var to_player := (player.global_position - enemy.global_position).normalized()
		var enemy_forward := -enemy.global_basis.z
		if enemy_forward.dot(to_player) > -0.25:
			continue
		best = enemy
		best_distance = distance
	return best

func can_start() -> bool:
	return not active and GameState.simulation_active() and candidate() != null

func start() -> bool:
	if not can_start():
		return false
	target = candidate()
	if target == null:
		return false
	active = true
	elapsed = 0.0
	kill_applied = false
	player_was_processing = player.is_physics_processing()
	level_was_processing = level.is_physics_processing()
	enemy_processing.clear()
	player.set_physics_process(false)
	level.set_physics_process(false)
	for item in level.enemies:
		var enemy = item
		if enemy:
			enemy_processing.append({"enemy": enemy, "enabled": enemy.is_physics_processing()})
			enemy.set_physics_process(false)
	start_transform = return_camera.global_transform
	target_focus = target.global_position + Vector3(0, 0.85, 0)
	var midpoint := (player.global_position + target.global_position) * 0.5
	var end_position := midpoint + Vector3(0, 2.0, 0) + player.global_basis.x * 1.7 + player.global_basis.z * 2.7
	var end_basis := Basis.looking_at(target_focus - end_position, Vector3.UP)
	finish_transform = Transform3D(end_basis, end_position)
	cinematic_camera.global_transform = start_transform
	return_camera.current = false
	cinematic_camera.current = true
	hud_layer.visible = false
	if viewmodel:
		viewmodel.visible = false
	return true

func advance(delta: float) -> void:
	if not active:
		return
	elapsed += maxf(delta, 0.0)
	var blend := smoothstep(0.0, CAMERA_MOVE_SECONDS, elapsed)
	cinematic_camera.global_transform = start_transform.interpolate_with(finish_transform, blend)
	cinematic_camera.look_at(target_focus, Vector3.UP)
	if elapsed >= KILL_AT_SECONDS and not kill_applied:
		kill_applied = true
		if is_instance_valid(target) and target.is_alive():
			var distance := player.global_position.distance_to(target.global_position)
			level.target_killed.emit(target, distance)
			target.die()
	if elapsed >= FINISH_SECONDS:
		finish()

func cancel() -> void:
	if active:
		finish()

func finish() -> void:
	if not active:
		return
	active = false
	if player and is_instance_valid(player):
		player.set_physics_process(player_was_processing)
	if level and is_instance_valid(level):
		level.set_physics_process(level_was_processing)
	for entry in enemy_processing:
		var enemy = entry.enemy
		if is_instance_valid(enemy):
			enemy.set_physics_process(bool(entry.enabled))
	enemy_processing.clear()
	cinematic_camera.current = false
	if return_camera and is_instance_valid(return_camera):
		return_camera.current = true
	if hud_layer and is_instance_valid(hud_layer):
		hud_layer.visible = true
	if viewmodel and is_instance_valid(viewmodel):
		viewmodel.visible = true
	target = null
	if mission and is_instance_valid(mission):
		mission.update_hud()

func _exit_tree() -> void:
	if active:
		finish()
