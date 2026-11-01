extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var scene = load("res://main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.ammo = 0
	check(game.begin_reload(), "Reload starts")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused, "Focus loss pauses")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss releases mouse")
	var remaining: float = game.reload_remaining
	game.advance_weapon(10.0)
	check(game.reload_remaining == remaining, "Focus loss freezes reload")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.paused, "Focus return does not silently resume")
	game.set_paused(false)
	check(not game.paused, "Explicit resume works")
	game.advance_weapon(3.0)
	check(game.ammo == 5 and game.reserve_ammo == 15, "Resume completes reload without ammo duplication")
	game.finished = true
	var original_fov: float = game.camera.fov
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	game._unhandled_input(click)
	check(game.camera.fov == original_fov, "Completed mission blocks scope input")
	click.button_index = MOUSE_BUTTON_LEFT
	game._unhandled_input(click)
	check(game.ammo == 5, "Completed mission blocks shots")
	game.set_paused(false)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Completed mission keeps mouse released")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("FOCUS TESTS PASSED")
	quit(0 if failures == 0 else 1)
