extends SceneTree

const Ballistics = preload("res://ballistics.gd")
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

func write_config(text: String) -> void:
	var file := FileAccess.open(loadout.PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func option_index(option: OptionButton, part_id: String) -> int:
	var available: Array = option.get_meta("parts")
	return available.find(part_id) + 1

func option_texts(option: OptionButton) -> Array:
	var texts := []
	for i in range(option.item_count):
		texts.append(option.get_item_text(i))
	return texts

# Checklist 5.3: a second rifle chassis, new scopes and their persistence.
func rifle_tests(recon: WeaponProfile) -> void:
	loadout.installed = {}
	loadout.rifle = loadout.DEFAULT_RIFLE
	check(loadout.rifle == "recon" and Array(loadout.rifle_ids()) == ["recon", "heavy_rifle"], "The recon rifle is the default chassis and the heavy rifle is offered")
	var heavy: WeaponProfile = load(loadout.RIFLES["heavy_rifle"])
	check(heavy != null and heavy.family == "heavy_rifle" and heavy.simulated_projectile and heavy.display_name == "Talus heavy rifle", "The heavy rifle profile loads as a projectile rifle with a fictional name")
	check(recon.muzzle_velocity == 820.0 and recon.drag_coefficient == 0.0004 and recon.damage == 90.0 and recon.max_range == 1200.0, "The recon rifle's ballistics are unchanged")
	check(heavy.muzzle_velocity > recon.muzzle_velocity and heavy.drag_coefficient < recon.drag_coefficient and heavy.max_range > recon.max_range, "The heavy rifle is faster, sheds less speed and reaches further")
	check(heavy.damage > recon.damage and heavy.capacity < recon.capacity and heavy.shot_interval > recon.shot_interval and heavy.reload_seconds > recon.reload_seconds and heavy.recoil_degrees > recon.recoil_degrees, "The heavy rifle trades handling for power")
	var recon_air := Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, recon.drag_coefficient)
	var heavy_air := Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, heavy.drag_coefficient)
	var recon_hold := Ballistics.holdover(recon.muzzle_velocity, 1000.0, 100.0, recon_air)
	var heavy_hold := Ballistics.holdover(heavy.muzzle_velocity, 1000.0, 100.0, heavy_air)
	check(heavy_hold > 0.0 and heavy_hold < recon_hold * 0.85, "The heavy rifle needs less holdover at 1000 m (%.2f m against %.2f m)" % [heavy_hold, recon_hold])
	var crosswind := Vector3(0.0, 0.0, 4.0)
	var recon_drift: float = Ballistics.simulate_flat(recon.muzzle_velocity, 0.0, 800.0, Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, recon.drag_coefficient, crosswind)).drift
	var heavy_flight: Dictionary = Ballistics.simulate_flat(heavy.muzzle_velocity, 0.0, 800.0, Ballistics.make_params(Ballistics.DEFAULT_GRAVITY, heavy.drag_coefficient, crosswind))
	check(heavy_flight.drift < recon_drift * 0.7, "The heavy rifle drifts less in a 4 m/s crosswind at 800 m (%.2f m against %.2f m)" % [heavy_flight.drift, recon_drift])
	var heavy_far: Dictionary = Ballistics.simulate_flat(heavy.muzzle_velocity, 0.0, heavy.max_range, heavy_air)
	check(heavy_far.reached and heavy_far.time < float(load("res://scenes/weapons/weapon_rig.gd").PROJECTILE_LIFETIME), "A heavy rifle round reaches its maximum range within the projectile lifetime")
	check(loadout.select_rifle("heavy_rifle") and loadout.rifle == "heavy_rifle", "The heavy rifle can be selected")
	check(not loadout.select_rifle("sidearm") and not loadout.select_rifle("bogus") and loadout.rifle == "heavy_rifle", "Handgun families and unknown chassis are refused")
	check(loadout.install("heavy_rifle", "optic", "long_scope") and loadout.install("recon", "optic", "close_scope"), "The new scopes install on both rifles")
	check(not loadout.install("sidearm", "optic", "long_scope") and not loadout.install("heavy_rifle", "stock", "close_scope"), "The new scopes are refused on handguns and in other slots")
	var tuned: WeaponProfile = loadout.apply_to(heavy)
	check(tuned.zoom_min == 6.0 and tuned.zoom_max == 24.0 and tuned.zoom_step == 3.0 and tuned.reticle_max == 1500.0 and tuned.aim_fov == 14.0, "The long-range scope sets the derived profile's optic")
	check(heavy.zoom_max == 12.0 and heavy.aim_fov != 14.0 and tuned.muzzle_velocity == heavy.muzzle_velocity and tuned.drag_coefficient == heavy.drag_coefficient, "Scopes never change the base profile or its ballistics")
	check(loadout.save_loadout(), "The rifle choice saves")
	loadout.installed = {}
	loadout.rifle = loadout.DEFAULT_RIFLE
	check(loadout.load_loadout() and loadout.rifle == "heavy_rifle" and loadout.parts_for("heavy_rifle") == {"optic": "long_scope"} and loadout.parts_for("recon") == {"optic": "close_scope"}, "The rifle choice and new parts load back")
	write_config("[recon]\noptic=\"precision_scope\"\nstock=\"stable_stock\"\n\n[sidearm]\noptic=\"reflex\"\n")
	check(loadout.load_loadout() and loadout.rifle == "recon" and loadout.parts_for("recon") == {"optic": "precision_scope", "stock": "stable_stock"} and loadout.parts_for("sidearm") == {"optic": "reflex"}, "An old-format loadout without a rifle choice still loads, with the recon rifle")
	write_config("[selection]\nrifle=\"sidearm\"\n\n[recon]\noptic=\"close_scope\"\n")
	check(loadout.load_loadout() and loadout.rifle == "recon" and loadout.parts_for("recon") == {"optic": "close_scope"}, "An invalid stored rifle falls back to the recon rifle")
	# The mission rig carries the chosen rifle and optic.
	loadout.installed = {}
	loadout.select_rifle("heavy_rifle")
	loadout.install("heavy_rifle", "optic", "long_scope")
	loadout.install("heavy_rifle", "spring", "match_barrel")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var weapon = game.weapon
	var primary: WeaponProfile = weapon.profiles[0]
	check(weapon.profiles.size() == 4 and primary.family == "heavy_rifle" and primary.muzzle_velocity == heavy.muzzle_velocity and is_equal_approx(primary.max_range, heavy.max_range * 1.1), "The mission rig carries the selected rifle with its parts")
	check(weapon.profiles[1].family == "sidearm" and weapon.profiles[3].family == "sidearm" and weapon.ammo == heavy.capacity, "Handguns keep their slots and the rifle has its own magazine")
	var scope = game.scope_view
	check(scope.zoom_min == 6.0 and scope.zoom_max == 24.0 and scope.zoom == 6.0, "The scope view takes the installed optic's magnification range")
	scope.set_zoom(100.0)
	check(scope.zoom == 24.0 and not scope.zoom_in(), "The long-range scope reaches 24x")
	weapon.toggle_aim()
	check(game.camera.fov == 14.0, "Aiming uses the long-range scope")
	var marks: Array = game.get_node("ScopeLayer/ScopeOverlay").holdover_marks()
	check(marks.size() == 14 and marks[0].range == 200.0 and marks[-1].range == 1500.0, "The long-range reticle marks holds out to 1500 m")
	weapon.toggle_aim()
	weapon.select_weapon(1)
	scope.follow()
	weapon.select_weapon(0)
	scope.follow()
	check(scope.zoom_max == 24.0 and scope.zoom == 24.0, "Switching to a handgun and back keeps the rifle's optic and zoom")
	game.queue_free()
	await process_frame
	loadout.installed = {}
	loadout.select_rifle("recon")
	loadout.install("recon", "optic", "close_scope")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	scope = game.scope_view
	check(game.weapon.profiles[0].family == "recon" and game.weapon.profiles[0].muzzle_velocity == 820.0, "Selecting the recon rifle again restores it in the rig")
	check(scope.zoom_min == 2.0 and scope.zoom_max == 8.0 and scope.zoom == 2.0, "The close-range scope magnifies 2x to 8x in the mission")
	marks = game.get_node("ScopeLayer/ScopeOverlay").holdover_marks()
	check(marks.size() == 10 and marks[0].range == 150.0 and marks[-1].range == 600.0, "The close-range reticle marks every 50 m out to 600 m")
	game.queue_free()
	await process_frame
	# Workbench: lists the rifles and new scopes, applies and persists the choice.
	loadout.installed = {}
	loadout.rifle = loadout.DEFAULT_RIFLE
	loadout.save_loadout()
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_screen(menu.Screen.WORKBENCH)
	var bench = menu.workbench
	var rifles: OptionButton = bench.rifle_option
	check(option_texts(rifles) == [tr("Ridgeline recon rifle"), tr("Talus heavy rifle")] and rifles.selected == 0, "The workbench lists both rifles and shows the current choice")
	var heavy_optics: OptionButton = bench.selectors["heavy_rifle"]["optic"]
	var listed := option_texts(heavy_optics)
	check(listed.has(tr("Thicket close-range scope")) and listed.has(tr("Farwatch long-range scope")) and listed.has(tr("Precision scope")), "The workbench lists the new scopes by name")
	check(not option_texts(bench.selectors["sidearm"]["optic"]).has(tr("Farwatch long-range scope")), "The workbench does not offer rifle scopes for handguns")
	check(bench.family_blocks["recon"].visible and not bench.family_blocks["heavy_rifle"].visible, "Only the chosen rifle's parts are shown")
	rifles.select(1)
	rifles.item_selected.emit(1)
	check(bench.family_blocks["heavy_rifle"].visible and not bench.family_blocks["recon"].visible, "Choosing the heavy rifle shows its parts")
	heavy_optics.selected = option_index(heavy_optics, "long_scope")
	bench.apply_from_controls()
	check(loadout.rifle == "heavy_rifle" and loadout.parts_for("heavy_rifle") == {"optic": "long_scope"}, "Workbench apply selects the rifle and installs the scope")
	check(bench.summary.text.contains(tr("Talus heavy rifle")) and bench.summary.text.contains(tr("Farwatch long-range scope")), "The workbench summary names the chosen rifle and optic")
	loadout.installed = {}
	loadout.rifle = loadout.DEFAULT_RIFLE
	check(loadout.load_loadout() and loadout.rifle == "heavy_rifle" and loadout.parts_for("heavy_rifle") == {"optic": "long_scope"}, "Workbench apply persists the rifle choice")
	bench.apply_presets()
	check(loadout.rifle == "heavy_rifle" and loadout.parts_for("heavy_rifle") == {"stock": "stable_stock", "optic": "precision_scope"}, "The upgraded preset covers the heavy rifle and keeps the rifle choice")
	menu.show_screen(menu.Screen.HOME)
	loadout.rifle = loadout.DEFAULT_RIFLE
	menu.show_screen(menu.Screen.WORKBENCH)
	check(rifles.selected == 0 and bench.family_blocks["recon"].visible, "Reopening the workbench reflects the current rifle")
	menu.queue_free()
	await process_frame

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
	await rifle_tests(base)
	loadout.installed = {}
	loadout.rifle = loadout.DEFAULT_RIFLE
	loadout.save_loadout()
	if failures == 0:
		print("LOADOUT TESTS PASSED")
	quit(0 if failures == 0 else 1)
