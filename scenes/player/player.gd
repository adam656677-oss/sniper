class_name Player
extends CharacterBody3D

# First-person player body: movement, look and stance. Weapons live in WeaponRig.

enum Stance { STAND, CROUCH, PRONE }

const GRAVITY := 20.0
const FALL_RESET_Y := -15.0
const LOOK_SENSITIVITY := 0.002
const SCOPED_SENSITIVITY := 0.0007
const PITCH_LIMIT := 1.4
const STANCE_HEIGHT := {Stance.STAND: 1.8, Stance.CROUCH: 1.2, Stance.PRONE: 0.6}
const STANCE_EYE_HEIGHT := {Stance.STAND: 0.65, Stance.CROUCH: 0.35, Stance.PRONE: 0.05}
const STANCE_SPEED := {Stance.STAND: 5.0, Stance.CROUCH: 2.5, Stance.PRONE: 1.0}
const STANCE_SWAY := {Stance.STAND: 1.0, Stance.CROUCH: 0.6, Stance.PRONE: 0.3}
const STANCE_EXPOSURE := {Stance.STAND: 1.0, Stance.CROUCH: 0.7, Stance.PRONE: 0.4}
const MAX_HEALTH := 100.0
const REGEN_DELAY := 5.0
const REGEN_PER_SECOND := 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collider: CollisionShape3D = $Collision
var spawn_point := Vector3(0, 1, 3)
var stance := Stance.STAND
var health := MAX_HEALTH
var since_damage := REGEN_DELAY
var still_seconds := 0.0

func look(relative: Vector2) -> void:
	var sensitivity := SCOPED_SENSITIVITY if camera.fov < 30.0 else LOOK_SENSITIVITY
	rotate_y(-relative.x * sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)

func set_stance(value: Stance) -> bool:
	if not GameState.simulation_active() or not STANCE_HEIGHT.has(value):
		return false
	stance = value
	var capsule := collider.shape as CapsuleShape3D
	if capsule:
		capsule.height = STANCE_HEIGHT[value]
	head.position.y = STANCE_EYE_HEIGHT[value]
	return true

func toggle_stance(value: Stance) -> bool:
	return set_stance(Stance.STAND if stance == value else value)

func move_speed() -> float:
	return STANCE_SPEED[stance]

func sway_multiplier() -> float:
	return STANCE_SWAY[stance]

# How visible this stance is to enemy perception, 0..1.
func exposure() -> float:
	return STANCE_EXPOSURE[stance]

func take_damage(amount: float) -> void:
	if not GameState.simulation_active() or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	since_damage = 0.0
	if health == 0.0:
		GameState.fail_mission()

func advance_health(delta: float) -> void:
	since_damage += delta
	if since_damage >= REGEN_DELAY and health < MAX_HEALTH:
		health = minf(MAX_HEALTH, health + REGEN_PER_SECOND * delta)

func respawn() -> void:
	position = spawn_point
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and GameState.simulation_active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)

func _physics_process(delta: float) -> void:
	if not GameState.simulation_active():
		return
	var input := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input.z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var direction := basis * input.normalized()
	velocity.x = direction.x * move_speed()
	velocity.z = direction.z * move_speed()
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	still_seconds = still_seconds + delta if Vector2(velocity.x, velocity.z).length() < 0.1 else 0.0
	advance_health(delta)
	if position.y < FALL_RESET_Y:
		respawn()
