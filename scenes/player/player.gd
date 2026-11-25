class_name Player
extends CharacterBody3D

# First-person player body: movement, look and stance. Weapons live in WeaponRig.

enum Stance { STAND, CROUCH, PRONE }

const GRAVITY := 20.0
const FALL_RESET_Y := -15.0
const LOOK_SENSITIVITY := 0.002
const SCOPED_SENSITIVITY := 0.0007
const PITCH_LIMIT := 1.4
const STICK_LOOK_SPEED := 2.6 # radians per second at full deflection and sensitivity 1
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
var suppression := 0.0
var footstep_clock := 0.0
var carrying: Node3D = null
const SUPPRESSION_DECAY := 0.25
const CARRY_SPEED := 2.0

func look(relative: Vector2) -> void:
	var sensitivity := (SCOPED_SENSITIVITY if camera.fov < 30.0 else LOOK_SENSITIVITY) * Settings.sensitivity()
	var vertical := -relative.y if Settings.invert_y() else relative.y
	rotate_y(-relative.x * sensitivity)
	head.rotation.x = clampf(head.rotation.x - vertical * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)

# Right-stick look, applied per physics step. Scoped aim is slower, as with the mouse.
func stick_look(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick == Vector2.ZERO:
		return
	var scale := STICK_LOOK_SPEED * Settings.sensitivity() * (0.35 if camera.fov < 30.0 else 1.0) * delta
	var vertical := -stick.y if Settings.invert_y() else stick.y
	rotate_y(-stick.x * scale)
	head.rotation.x = clampf(head.rotation.x - vertical * scale, -PITCH_LIMIT, PITCH_LIMIT)

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
	return minf(STANCE_SPEED[stance], CARRY_SPEED) if carrying else STANCE_SPEED[stance]

func suppress(amount: float) -> void:
	if GameState.simulation_active():
		suppression = clampf(suppression + amount, 0.0, 1.0)

func sway_multiplier() -> float:
	return STANCE_SWAY[stance] * (1.0 + suppression * 2.0)

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

func footstep_interval() -> float:
	match stance:
		Stance.CROUCH:
			return 0.72
		Stance.PRONE:
			return 1.05
	return 0.48

func advance_footsteps(delta: float) -> void:
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length() < 0.35:
		footstep_clock = 0.0
		return
	footstep_clock += maxf(delta, 0.0)
	if footstep_clock >= footstep_interval():
		footstep_clock = fmod(footstep_clock, footstep_interval())
		var volume_offset := -7.0 if stance == Stance.STAND else (-10.0 if stance == Stance.CROUCH else -14.0)
		AudioDirector.play_event("footstep", global_position + Vector3(0, -0.65, 0), volume_offset, randf_range(0.94, 1.06))

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
	stick_look(delta)
	var input := Vector3.ZERO
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input.x = move.x
	input.z = move.y
	var direction := basis * input.normalized()
	velocity.x = direction.x * move_speed()
	velocity.z = direction.z * move_speed()
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	advance_footsteps(delta)
	still_seconds = still_seconds + delta if Vector2(velocity.x, velocity.z).length() < 0.1 else 0.0
	advance_health(delta)
	suppression = maxf(0.0, suppression - SUPPRESSION_DECAY * delta)
	if carrying and is_instance_valid(carrying):
		carrying.global_position = global_position + basis.z * 0.8 + Vector3(0, -0.3, 0)
	if position.y < FALL_RESET_Y:
		respawn()
