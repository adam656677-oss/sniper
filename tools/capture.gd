extends SceneTree

# Renders scenes to PNG under a real display (use xvfb-run). Not part of CI.
#   xvfb-run -a godot --path . --script res://tools/capture.gd -- <out_dir>

var out_dir := "user://captures"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED ", name, " ", image.get_size())

func run() -> void:
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await shot("01_main_menu")
	menu.show_screen(menu.Screen.MISSIONS)
	await shot("02_mission_select")
	menu.show_screen(menu.Screen.SETTINGS)
	menu.settings_screen.tabs.current_tab = 5
	await shot("09_settings_keys")
	menu.queue_free()
	await process_frame
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for e in game.level.enemies:
		e.set_physics_process(false)
	game.player.global_position = Vector3(0, 1, -2)
	game.player.rotation.y = 0.0
	await shot("03_compound_hip")
	game.weapon.toggle_aim()
	await shot("04_compound_scoped")
	game.weapon.toggle_aim()
	game.player.global_position = Vector3(5, 1, -14)
	game.player.rotation.y = 0.0
	await process_frame
	game.weapon.select_weapon(1)
	for i in range(6):
		game.weapon.shot_remaining = 0.0
		game.weapon.fire_weapon()
	await shot("10_impacts")
	game.weapon.select_weapon(0)
	game.weapon.toggle_aim()
	game.stealth.toggle_binoculars()
	await shot("05_binoculars")
	game.queue_free()
	await process_frame
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await shot("08_echo_ridge_dawn")
	game.queue_free()
	await process_frame
	game = load("res://range_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await shot("06_range_hip")
	game.weapon.toggle_aim()
	game.scope_view.set_zoom(12.0)
	game.player.head.rotation.x = 0.0
	await shot("07_range_scope_12x")
	game.scope_view.set_zoom(4.0)
	game.weapon.toggle_aim()
	var dummy = load("res://scenes/targets/target_dummy.tscn").instantiate()
	game.level.add_child(dummy)
	dummy.global_position = Vector3(-30, 1, -300)
	game.level.register_target(dummy)
	game.level.wind = Vector3.ZERO
	await physics_frame
	await physics_frame
	game.set_physics_process(false)
	game.weapon.wind = Vector3.ZERO
	var head: Vector3 = dummy.global_position + Vector3(0, 0.85, 0)
	game.camera.global_position = Vector3(head.x, 1.6, head.z + 300.0)
	game.camera.look_at(head + Vector3(0, game.weapon.holdover_at(300.0), 0), Vector3.UP)
	game.weapon.shot_remaining = 0.0
	game.weapon.fire_weapon()
	game.weapon.advance_projectiles(0.3)
	game.killcam.advance_follow(0.0, true)
	game.feedback.draw_tracers(game.weapon.projectiles)
	game.get_node("HUDLayer").visible = false
	await shot("11_bullet_cam")
	game.killcam.skip()
	game.queue_free()
	await process_frame
	quit()
