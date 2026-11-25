extends SceneTree

var failures := 0
var state: Node
var saves: Node
var settings: Node
var requested: Array = []

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func press(button: Button) -> void:
	button.pressed.emit()

func run_tests() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveSystem")
	settings = root.get_node("Settings")
	settings.reset()
	saves.delete_save(saves.CHECKPOINT_SLOT)
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.scene_changer = func(path): requested.append(path)
	check(menu.screen == menu.Screen.HOME and menu.home.visible and not menu.missions.visible, "Menu opens on the home screen")
	check(menu.theme != null and menu.get_node_or_null("TacticalBackdrop") != null, "Main menu loads the shared tactical theme and shader backdrop")
	check(menu.continue_button.disabled, "Continue is disabled without a checkpoint")
	check(menu.build_label().begins_with("v0.4.0 ("), "The menu shows the version and build")
	check(menu.continue_checkpoint() == "" and requested.is_empty(), "Continue without a checkpoint changes nothing")
	menu.show_screen(menu.Screen.MISSIONS)
	var buttons: Array = []
	for child in menu.missions.get_children():
		if child is Button:
			buttons.append(child)
	check(buttons.size() == 5 and buttons[0].text == "Shooting range" and buttons[1].text == "Kestrel Pass" and buttons[4].text == "Back", "Mission list shows every mission and a back button")
	press(buttons[1])
	check(requested == ["res://kestrel_mission.tscn"], "Choosing Kestrel Pass requests its campaign scene")
	requested.clear()
	press(buttons[3])
	check(requested == ["res://compound_mission.tscn"], "Choosing the compound still requests its original scene")
	check(menu.start_mission(99) == "", "Out-of-range missions are ignored")
	menu.show_screen(menu.Screen.SETTINGS)
	check(menu.settings_screen.visible and not menu.home.visible, "Settings screen replaces the home screen")
	var panel = menu.settings_screen
	panel.sliders["controls/sensitivity"].value = 3.0
	panel.difficulty.selected = 0
	panel.checks["gameplay/killcam"].button_pressed = false
	panel.apply_from_controls()
	check(settings.get_value("controls", "sensitivity") == 3.0 and state.difficulty == state.Difficulty.EASY and not settings.get_value("gameplay", "killcam"), "Applying the settings screen writes and applies values")
	panel.reset_to_defaults()
	check(panel.sliders["controls/sensitivity"].value == 1.0 and state.difficulty == state.Difficulty.NORMAL, "Defaults button restores the controls")
	panel.closed.emit()
	check(menu.screen == menu.Screen.HOME, "Closing settings returns home")
	menu.queue_free()
	await process_frame
	# A mission: pause menu and results.
	var game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var pause = game.get_node("HUDLayer/PauseMenu")
	var results = game.results
	check(not pause.visible and not results.visible, "Menus start hidden in a mission")
	check(pause.theme != null and results.theme != null, "Pause and results screens share the tactical interface theme")
	state.set_paused(true)
	await physics_frame
	await physics_frame
	check(pause.visible, "Pausing shows the pause menu")
	press(pause.panel.get_child(1))
	await physics_frame
	await physics_frame
	check(not state.paused and not pause.visible, "Resume unpauses and hides the menu")
	game.stats.shots = 10
	game.stats.hits = 6
	game.stats.kills = 2
	game.stats.longest_kill = 340.0
	var objectives = game.level.mission_log
	objectives.complete("eliminate")
	saves.delete_save(saves.CHECKPOINT_SLOT)
	objectives.activate("exfil")
	objectives.complete("exfil")
	await physics_frame
	await physics_frame
	check(state.finished and results.visible, "Finishing a mission shows the results")
	check(objectives.status("undetected") == objectives.Status.COMPLETE and objectives.status("silent") == objectives.Status.COMPLETE, "Open secondary objectives complete with the mission")
	var expected := 2 * 100 + 340 + 60 + 250 * 2 + 150 * 2
	check(results.score_for(game.stats, objectives, false) == expected, "Score adds kills, range, accuracy and objectives")
	check(results.score_for(game.stats, objectives, true) == 0, "Failed missions score zero")
	check(results.text.text.contains("Score: %d" % expected) and results.text.text.contains("Ghost"), "Results list the score and stealth rating")
	check(not saves.has_save(saves.CHECKPOINT_SLOT), "Finishing clears the checkpoint")
	game.queue_free()
	await process_frame
	game = load("res://compound_mission.tscn").instantiate()
	root.add_child(game)
	await process_frame
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.scene_changer = func(path): requested.append(path)
	game.level.mission_log.complete("silent")
	menu.show_screen(menu.Screen.HOME)
	check(not menu.continue_button.disabled, "Continue enables once a checkpoint exists")
	check(menu.continue_checkpoint() == "res://compound_mission.tscn" and not saves.pending.is_empty(), "Continue stages the checkpoint and requests its scene")
	saves.pending = {}
	saves.delete_save(saves.CHECKPOINT_SLOT)
	game.queue_free()
	menu.queue_free()
	await process_frame
	if failures == 0:
		print("MENU TESTS PASSED")
	quit(0 if failures == 0 else 1)
