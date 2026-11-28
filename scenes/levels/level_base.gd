class_name LevelBase
extends Node3D

# Common level contract used by the mission root. Concrete levels extend this
# and override objective_text, is_complete and interact.

const INTERACT_DISTANCE := 3.0

signal target_killed(body: Node3D, distance: float)

@export var spawn_point := Vector3(0, 1, 3)
@export var clear_color := Color(0.45, 0.62, 0.74)
@export var wind := Vector3(2.0, 0.0, 0.0) # Base air-mass velocity in m/s, world frame.
@export_enum("Dawn", "Noon", "Dusk", "Night") var time_of_day := 1
@export_enum("Clear", "Windy", "Rain", "Dust") var weather := 0

const Atmosphere = preload("res://scenes/levels/atmosphere.gd")
var clock := 0.0

var targets: Array[StaticBody3D] = []
var enemies: Array = []
var coordinator: AlertCoordinator
var player: Node3D
var mission: Node
var mission_log: MissionLog
var triggers: Array[TriggerZone] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(clear_color)
	ensure_environment()
	coordinator = AlertCoordinator.new()
	coordinator.name = "AlertCoordinator"
	add_child(coordinator)
	coordinator.reinforcements_requested.connect(spawn_reinforcements)
	if has_node("Targets"):
		for child in $Targets.get_children():
			if child is StaticBody3D:
				register_target(child)
	if has_node("Enemies"):
		for child in $Enemies.get_children():
			if child is CharacterBody3D and child.has_method("tick"):
				register_enemy(child)
	mission_log = MissionLog.new()
	mission_log.name = "MissionLog"
	add_child(mission_log)
	setup_objectives()

# Sky, ambient light, tonemapping and distance haze shared by every level, plus
# sun shadows. A level that has its own WorldEnvironment keeps it.
func ensure_environment() -> void:
	var time_preset: Dictionary = Atmosphere.TIME[time_of_day]
	var weather_preset: Dictionary = Atmosphere.WEATHER[weather]
	if has_node("Sun"):
		var sun: DirectionalLight3D = $Sun
		sun.shadow_enabled = true
		sun.light_energy = float(time_preset.sun_energy)
		sun.light_color = time_preset.sun_color
		sun.rotation_degrees = Vector3(float(time_preset.sun_pitch), -30.0, 0.0)
		sun.directional_shadow_max_distance = 250.0
	for child in get_children():
		if child is WorldEnvironment:
			return
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = time_preset.sky_top
	sky_material.sky_horizon_color = time_preset.horizon
	sky_material.ground_horizon_color = Color(0.6, 0.6, 0.55)
	sky_material.ground_bottom_color = Color(0.25, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = float(time_preset.ambient)
	environment.ambient_light_sky_contribution = 0.3
	environment.ambient_light_color = Color(0.55, 0.6, 0.68)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = time_preset.horizon.lerp(Color(0.7, 0.68, 0.6) if weather == Atmosphere.Weather.DUST else Color(0.7, 0.76, 0.82), 0.5)
	environment.fog_density = float(weather_preset.fog)
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)

# Concrete levels declare their objectives here.
func setup_objectives() -> void:
	pass

func add_trigger(trigger_name: String, center: Vector3, size: Vector3) -> TriggerZone:
	var zone := TriggerZone.new()
	zone.name = trigger_name
	zone.size = size
	add_child(zone)
	zone.global_position = center
	triggers.append(zone)
	return zone

func register_enemy(enemy: Node) -> void:
	if enemy in enemies:
		return
	enemies.append(enemy)
	enemy.level = self
	enemy.coordinator = coordinator
	coordinator.register(enemy)
	enemy.died.connect(on_enemy_died)
	if enemy.has_signal("fired_at_player"):
		enemy.fired_at_player.connect(_on_enemy_fired_at_player)

func _on_enemy_fired_at_player(enemy: Enemy, _hit: bool) -> void:
	if is_instance_valid(enemy):
		AudioDirector.play_event("enemy_report", enemy.global_position, -3.0, randf_range(0.96, 1.04))

func on_enemy_died(enemy: Node) -> void:
	enemies.erase(enemy)
	coordinator.unregister(enemy)
	coordinator.report_death(enemy)

func find_enemy(enemy_name: String) -> Node:
	for enemy in enemies:
		if enemy.name == enemy_name:
			return enemy
	if has_node("Enemies/" + enemy_name):
		return get_node("Enemies/" + enemy_name)
	return null

# Remove without objective progress or alert escalation; used when restoring a save.
func remove_enemy_silently(enemy: Node) -> void:
	enemies.erase(enemy)
	coordinator.unregister(enemy)
	enemy.queue_free()

func remove_target_silently(body: Node) -> void:
	targets.erase(body)
	body.queue_free()

# Re-evaluate trigger enablement after a restore. Levels override when they gate zones.
func restore_triggers() -> void:
	pass

# Override to add hostiles when the coordinator reaches lockdown.
func spawn_reinforcements(_position: Vector3) -> void:
	pass

func report_noise(position: Vector3, radius: float, loudness: float = 1.0) -> void:
	coordinator.report_noise(position, radius * hearing_factor(), null, loudness)

# One flat navigation polygon at ground level. Enough for the prototype arenas;
# baked meshes replace this with the terrain work.
func build_flat_navmesh(center: Vector3, size: Vector2) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "FlatNavigation"
	var mesh := NavigationMesh.new()
	var half := size * 0.5
	mesh.vertices = PackedVector3Array([
		center + Vector3(-half.x, 0, -half.y), center + Vector3(half.x, 0, -half.y),
		center + Vector3(half.x, 0, half.y), center + Vector3(-half.x, 0, half.y)
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	add_child(region)
	return region

# Fraction of normal enemy sight range under current light and weather.
func visibility_factor() -> float:
	return Atmosphere.visibility(time_of_day, weather)

func hearing_factor() -> float:
	return Atmosphere.hearing(weather)

func current_wind() -> Vector3:
	return Atmosphere.wind_at(wind, weather, clock)

func conditions_text() -> String:
	return "%s, %s" % [tr(["Dawn", "Noon", "Dusk", "Night"][time_of_day]), tr(["clear", "windy", "rain", "dust"][weather])]

func _physics_process(delta: float) -> void:
	if GameState.simulation_active():
		clock += delta
		coordinator.advance(delta)
		if player:
			for zone in triggers:
				zone.check(player.global_position)

func register_target(body: StaticBody3D) -> void:
	targets.append(body)
	if body.has_signal("died") and not body.died.is_connected(on_target_died):
		body.died.connect(on_target_died)

func on_target_died(body: Node3D) -> void:
	if body in targets:
		targets.erase(body)
		body.queue_free()

func on_body_hit(body: Node3D, shape_index: int = -1, damage: float = 0.0, distance: float = 0.0) -> void:
	if body == null:
		return
	if body.has_method("take_hit"):
		var was_alive: bool = body.is_alive()
		body.take_hit(shape_index, damage)
		if was_alive and not body.is_alive():
			target_killed.emit(body, distance)
	elif body in targets:
		on_target_died(body)
		target_killed.emit(body, distance)

# Called when the player presses interact at a world position.
func interact(_point: Vector3) -> void:
	pass

func objective_text() -> String:
	var active := mission_log.first_active_primary()
	if active.is_empty():
		return tr("All objectives complete") if mission_log.all_primary_complete() else tr("Stand by")
	return mission_log.line(active)

func is_complete() -> bool:
	return mission_log.all_primary_complete()

func is_failed() -> bool:
	return mission_log.any_primary_failed()

# Quick saves and checkpoints. Challenges refuse them so a round budget or a
# clock cannot be reloaded.
func allows_saves() -> bool:
	return true

# HUD banner once the mission is over; {tokens} are filled with the current bindings.
func end_banner(failed: bool) -> String:
	return tr("MISSION FAILED - {restart} to restart") if failed else tr("MISSION COMPLETE - {restart} to restart")

# Records the finished mission locally and returns what changed for the results
# screen. Challenges keep their own leaderboard instead.
func record_progress(mission_id: String, stats: Dictionary) -> Dictionary:
	return Progression.record(mission_id, stats, mission_log, GameState.failed)

# Code-built box for tests and quick prototyping. Level geometry itself lives in the scene file.
func spawn_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collision.shape = bounds
	body.add_child(collision)
	add_child(body)
	return body
