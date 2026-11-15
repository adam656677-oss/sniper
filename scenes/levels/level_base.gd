class_name LevelBase
extends Node3D

# Common level contract used by the mission root. Concrete levels extend this
# and override objective_text, is_complete and interact.

const INTERACT_DISTANCE := 3.0

signal target_killed(body: Node3D, distance: float)

@export var spawn_point := Vector3(0, 1, 3)
@export var clear_color := Color(0.45, 0.62, 0.74)
@export var wind := Vector3(2.0, 0.0, 0.0) # Air-mass velocity in m/s, world frame.

var targets: Array[StaticBody3D] = []
var enemies: Array = []
var coordinator: AlertCoordinator
var player: Node3D

func _ready() -> void:
	RenderingServer.set_default_clear_color(clear_color)
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

func register_enemy(enemy: Node) -> void:
	if enemy in enemies:
		return
	enemies.append(enemy)
	enemy.level = self
	enemy.coordinator = coordinator
	coordinator.register(enemy)
	enemy.died.connect(on_enemy_died)

func on_enemy_died(enemy: Node) -> void:
	enemies.erase(enemy)
	coordinator.unregister(enemy)
	coordinator.report_death(enemy)

# Override to add hostiles when the coordinator reaches lockdown.
func spawn_reinforcements(_position: Vector3) -> void:
	pass

func report_noise(position: Vector3, radius: float, loudness: float = 1.0) -> void:
	coordinator.report_noise(position, radius, null, loudness)

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

func _physics_process(delta: float) -> void:
	if GameState.simulation_active():
		coordinator.advance(delta)

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
	return "Eliminate all targets"

func is_complete() -> bool:
	return false

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
