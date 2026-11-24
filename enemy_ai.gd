extends CharacterBody3D
class_name EchoRidgeEnemy

signal state_changed(previous_state: int, new_state: int)
signal player_detected(target: Node3D)
signal attack_requested(target: Node3D)
signal eliminated

enum State { IDLE, PATROL, INVESTIGATE, ENGAGE, DEAD }

@export_group("Perception")
@export var detection_range: float = 24.0
@export_range(10.0, 180.0, 1.0) var field_of_view_degrees: float = 110.0
@export var eye_height: float = 1.55
@export var target_group: StringName = &"player"

@export_group("Movement")
@export var move_speed: float = 2.8
@export var patrol_points: Array[Vector3] = []
@export var waypoint_tolerance: float = 0.7
@export var gravity: float = 18.0

@export_group("Combat")
@export var maximum_health: float = 100.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

var current_health: float
var current_state: State = State.IDLE
var target: Node3D
var investigate_position: Vector3
var waypoint_index: int = 0
var attack_timer: float = 0.0
var _has_investigation_target: bool = false

func _ready() -> void:
	current_health = maximum_health
	add_to_group("enemies")
	if not patrol_points.is_empty():
		_change_state(State.PATROL)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	_resolve_target()

	if is_instance_valid(target) and _can_see_target(target):
		if current_state != State.ENGAGE:
			player_detected.emit(target)
		_change_state(State.ENGAGE)

	match current_state:
		State.IDLE:
			_stop_horizontal()
		State.PATROL:
			_update_patrol()
		State.INVESTIGATE:
			_update_investigation()
		State.ENGAGE:
			_update_engagement(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _resolve_target() -> void:
	if is_instance_valid(target):
		return
	var candidate := get_tree().get_first_node_in_group(target_group)
	if candidate is Node3D and candidate != self:
		target = candidate as Node3D

func _can_see_target(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var eye := global_position + Vector3.UP * eye_height
	var aim_point := candidate.global_position + Vector3.UP
	var offset := aim_point - eye
	var distance := offset.length()
	if distance > detection_range or distance <= 0.01:
		return false
	var forward := -global_basis.z
	if forward.dot(offset.normalized()) < cos(deg_to_rad(field_of_view_degrees * 0.5)):
		return false

	var query := PhysicsRayQueryParameters3D.create(eye, aim_point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == candidate

func _update_patrol() -> void:
	if patrol_points.is_empty():
		_stop_horizontal()
		_change_state(State.IDLE)
		return
	var destination := patrol_points[waypoint_index]
	if global_position.distance_to(destination) <= waypoint_tolerance:
		waypoint_index = (waypoint_index + 1) % patrol_points.size()
		destination = patrol_points[waypoint_index]
	_move_toward(destination, move_speed)

func _update_investigation() -> void:
	if not _has_investigation_target:
		_change_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
		return
	if global_position.distance_to(investigate_position) <= waypoint_tolerance:
		_has_investigation_target = false
		_change_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
		return
	_move_toward(investigate_position, move_speed * 1.15)

func _update_engagement(delta: float) -> void:
	if not is_instance_valid(target):
		_change_state(State.INVESTIGATE if _has_investigation_target else (State.PATROL if not patrol_points.is_empty() else State.IDLE))
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > detection_range * 1.35:
		investigate_position = target.global_position
		_has_investigation_target = true
		target = null
		_change_state(State.INVESTIGATE)
		return
	if distance > attack_range:
		_move_toward(target.global_position, move_speed * 1.2)
	else:
		_stop_horizontal()
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			attack_requested.emit(target)

func _move_toward(destination: Vector3, speed: float) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		_stop_horizontal()
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	look_at(global_position + direction, Vector3.UP)

func _stop_horizontal() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 8.0 * get_physics_process_delta_time())
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 8.0 * get_physics_process_delta_time())

func investigate_position_at(world_position: Vector3) -> void:
	if current_state == State.DEAD:
		return
	investigate_position = world_position
	_has_investigation_target = true
	if current_state != State.ENGAGE:
		_change_state(State.INVESTIGATE)

func receive_damage(amount: float, source_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == State.DEAD or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	if current_health <= 0.0:
		_change_state(State.DEAD)
		velocity = Vector3.ZERO
		eliminated.emit()
		queue_free()
		return
	if source_position != Vector3.ZERO:
		investigate_position = source_position
		_has_investigation_target = true
		if current_state != State.ENGAGE:
			_change_state(State.INVESTIGATE)

func _change_state(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous := current_state
	current_state = next_state
	state_changed.emit(previous, current_state)
