class_name Player
extends CharacterBody3D

# First-person player body. Movement and look only; weapons live in WeaponRig.

const WALK_SPEED := 5.0
const GRAVITY := 20.0
const FALL_RESET_Y := -15.0
const LOOK_SENSITIVITY := 0.002
const SCOPED_SENSITIVITY := 0.0007
const PITCH_LIMIT := 1.4

@onready var camera: Camera3D = $Camera3D
var spawn_point := Vector3(0, 1, 3)

func look(relative: Vector2) -> void:
	var sensitivity := SCOPED_SENSITIVITY if camera.fov < 30.0 else LOOK_SENSITIVITY
	rotate_y(-relative.x * sensitivity)
	camera.rotation.x = clampf(camera.rotation.x - relative.y * sensitivity, -PITCH_LIMIT, PITCH_LIMIT)

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
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if position.y < FALL_RESET_Y:
		respawn()
