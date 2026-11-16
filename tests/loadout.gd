extends SceneTree

var failures := 0
var loadout: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	loadout = root.get_node("Loadout")
	loadout.installed = {}
	loadout.save_loadout()
	var base = load("res://scenes/weapons/profiles/ridgeline_recon.tres")
	var stock = loadout.apply_to(base)
	check(stock.aim_fov == 25.0 and stock.capacity == 5 and stock != base, "Stock loadout copies the base profile unchanged")
	check(loadout.install("recon", "optic", "precision_scope") and loadout.install("recon", "stock", "stable_stock"), "Compatible parts install")
	check(not loadout.install("recon", "spring", "light_spring"), "Incompatible parts are refused")
	check(not loadout.install("recon", "barrel", "match_barrel") and not loadout.install("nope", "optic", "reflex"), "Unknown slots and families are refused")
	var tuned = loadout.apply_to(base)
	check(tuned.aim_fov == 18.0 and is_equal_approx(tuned.reload_seconds, 2.2 * 1.05) and tuned.capacity == 5 and base.aim_fov == 25.0, "Installed parts change the derived profile and never the base")
	check(loadout.install("recon", "optic", ""), "A slot can be cleared")
	check(loadout.apply_to(base).aim_fov == 25.0, "Clearing a slot restores the base value")
	loadout.install("recon", "optic", "precision_scope")
	check(loadout.save_loadout(), "Loadout saves")
	loadout.installed = {}
	check(loadout.load_loadout() and loadout.parts_for("recon") == {"optic": "precision_scope", "stock": "stable_stock"}, "Loadout loads back")
	var file := FileAccess.open(loadout.PATH, FileAccess.WRITE)
	file.store_string("[recon]\noptic = \"light_spring\"\nbogus = \"reflex\"\n[nope]\noptic = \"reflex\"\n")
	file.close()
	loadout.load_loadout()
	check(loadout.installed.is_empty(), "Invalid stored parts are dropped on load")
	loadout.install("recon", "optic", "precision_scope")
	loadout.install("recon", "spring", "match_barrel")
	loadout.save_loadout()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var rifle = game.weapon.profiles[0]
	check(rifle.aim_fov == 18.0 and rifle.max_range > 1200.0 and rifle.spread == 0.0, "A mission rig carries the installed parts")
	game.weapon.toggle_aim()
	check(game.camera.fov == 18.0, "Aiming uses the installed optic")
	game.queue_free()
	await process_frame
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_screen(menu.Screen.WORKBENCH)
	var bench = menu.workbench
	check(bench.visible and bench.selectors["recon"]["optic"].selected == 1, "Workbench shows the installed optic")
	bench.selectors["recon"]["optic"].selected = 0
	bench.apply_from_controls()
	check(loadout.parts_for("recon").has("optic") == false and loadout.parts_for("recon").has("spring"), "Workbench apply updates and keeps other slots")
	bench.apply_presets()
	check(loadout.parts_for("recon") == {"stock": "stable_stock", "optic": "precision_scope"} and loadout.parts_for("sidearm").optic == "reflex", "Upgraded preset installs per family")
	loadout.installed = {}
	loadout.save_loadout()
	menu.queue_free()
	await process_frame
	if failures == 0:
		print("LOADOUT TESTS PASSED")
	quit(0 if failures == 0 else 1)
