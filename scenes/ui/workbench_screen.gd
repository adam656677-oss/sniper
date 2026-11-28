class_name WorkbenchScreen
extends VBoxContainer

# Gunsmith workbench: choose the rifle for the primary slot, then one option
# button per slot for that rifle's family and for the handguns.

signal closed

const Gunsmith = preload("res://gunsmith.gd")
const HANDGUNS := "sidearm"

var rifle_option: OptionButton
var rifle_ids: Array = []
var selectors: Dictionary = {} # family -> {slot: OptionButton}
var family_blocks: Dictionary = {} # family -> VBoxContainer
var summary: Label

func _ready() -> void:
	var title := Label.new()
	title.text = "WORKBENCH"
	add_child(title)
	var rifle_row := HBoxContainer.new()
	add_child(rifle_row)
	var rifle_label := Label.new()
	rifle_label.text = tr("Rifle")
	rifle_row.add_child(rifle_label)
	rifle_option = OptionButton.new()
	rifle_ids = Loadout.rifle_ids()
	for rifle_id in rifle_ids:
		rifle_option.add_item(rifle_name(rifle_id))
	rifle_option.item_selected.connect(func(_index: int): show_rifle_parts())
	rifle_row.add_child(rifle_option)
	for rifle_id in rifle_ids:
		add_family_block(rifle_id, rifle_name(rifle_id))
	add_family_block(HANDGUNS, tr("Handguns (all pistols)"))
	summary = Label.new()
	add_child(summary)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	for pair in [[tr("Apply"), apply_from_controls], [tr("Upgraded preset"), apply_presets], [tr("Back"), func(): closed.emit()]]:
		var button := Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		buttons.add_child(button)
	load_into_controls()

func rifle_name(rifle_id: String) -> String:
	return tr(Loadout.rifle_base(rifle_id).display_name)

func add_family_block(family: String, heading: String) -> void:
	var block := VBoxContainer.new()
	add_child(block)
	family_blocks[family] = block
	var label := Label.new()
	label.text = heading
	block.add_child(label)
	selectors[family] = {}
	for slot in Loadout.SLOTS:
		var parts: Array[String] = Loadout.compatible_parts(family, slot)
		if parts.is_empty():
			continue
		var row := HBoxContainer.new()
		block.add_child(row)
		var slot_label := Label.new()
		slot_label.text = tr(slot.capitalize())
		row.add_child(slot_label)
		var option := OptionButton.new()
		option.add_item(tr("Stock"))
		for part_id in parts:
			option.add_item(tr(Gunsmith.part_name(part_id)))
		option.set_meta("parts", parts)
		row.add_child(option)
		selectors[family][slot] = option

# The rifle chosen in the controls (not yet applied).
func selected_rifle() -> String:
	return String(rifle_ids[clampi(rifle_option.selected, 0, rifle_ids.size() - 1)])

func show_rifle_parts() -> void:
	var chosen := selected_rifle()
	for rifle_id in rifle_ids:
		family_blocks[rifle_id].visible = rifle_id == chosen

func load_into_controls() -> void:
	rifle_option.selected = maxi(rifle_ids.find(Loadout.rifle), 0)
	for family in selectors:
		var parts := Loadout.parts_for(family)
		for slot in selectors[family]:
			var option: OptionButton = selectors[family][slot]
			var available: Array = option.get_meta("parts")
			option.selected = 0
			if parts.has(slot) and parts[slot] in available:
				option.selected = available.find(parts[slot]) + 1
	show_rifle_parts()
	refresh_summary()

func apply_from_controls() -> void:
	Loadout.select_rifle(selected_rifle())
	for family in selectors:
		for slot in selectors[family]:
			var option: OptionButton = selectors[family][slot]
			var available: Array = option.get_meta("parts")
			Loadout.install(family, slot, "" if option.selected <= 0 else String(available[option.selected - 1]))
	Loadout.save_loadout()
	refresh_summary()

func apply_presets() -> void:
	Loadout.select_rifle(selected_rifle())
	for family in selectors:
		var preset: Dictionary = Gunsmith.upgraded_preset(family)
		Loadout.clear(family)
		for slot in preset:
			Loadout.install(family, slot, preset[slot])
	Loadout.save_loadout()
	load_into_controls()

func part_list(parts: Dictionary, slots: Array) -> String:
	var names: Array[String] = []
	for slot in slots:
		if parts.has(slot):
			names.append(tr(Gunsmith.part_name(parts[slot])))
	return tr("Stock") if names.is_empty() else ", ".join(names)

# The applied loadout: rifle ballistics, optic magnification and reticle reach, other parts.
func refresh_summary() -> void:
	var rifle: WeaponProfile = Loadout.apply_to(Loadout.rifle_base())
	var parts := Loadout.parts_for(rifle.family)
	var optic := tr(Gunsmith.part_name(parts.optic)) if parts.has("optic") else tr("Stock")
	var lines: Array[String] = [
		tr("Rifle: %s (%d m/s, %d rounds)") % [tr(rifle.display_name), int(rifle.muzzle_velocity), rifle.capacity],
		tr("Optic: %s (%dx to %dx, holds to %d m)") % [optic, int(rifle.zoom_min), int(rifle.zoom_max), int(minf(rifle.reticle_max, rifle.max_range))],
		tr("Parts: %s") % part_list(parts, ["spring", "stock"]),
		tr("Handguns: %s") % part_list(Loadout.parts_for(HANDGUNS), Loadout.SLOTS)
	]
	summary.text = "\n".join(lines)
