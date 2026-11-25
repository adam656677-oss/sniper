extends SceneTree

var failures := 0
var state: Node

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	state = root.get_node("GameState")
	var scene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	var weapon = game.weapon
	weapon.ammo = 0
	check(weapon.begin_reload(), "Reload starts")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(state.paused, "Focus loss pauses")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss releases mouse")
	var remaining: float = weapon.reload_remaining
	weapon.advance_weapon(10.0)
	check(weapon.reload_remaining == remaining, "Focus loss freezes reload")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(state.paused, "Focus return does not silently resume")
	state.set_paused(false)
	check(not state.paused, "Explicit resume works")
	weapon.advance_weapon(3.0)
	check(weapon.ammo == 5 and weapon.reserve_ammo == 15, "Resume completes reload without ammo duplication")
	state.finish_mission()
	var original_fov: float = game.camera.fov
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	game._unhandled_input(click)
	check(game.camera.fov == original_fov, "Completed mission blocks scope input")
	click.button_index = MOUSE_BUTTON_LEFT
	game._unhandled_input(click)
	check(weapon.ammo == 5, "Completed mission blocks shots")
	state.set_paused(false)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Completed mission keeps mouse released")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("FOCUS TESTS PASSED")
	quit(0 if failures == 0 else 1)
