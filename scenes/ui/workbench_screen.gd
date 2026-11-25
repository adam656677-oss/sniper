class_name WorkbenchScreen
extends VBoxContainer

# Gunsmith workbench: one option button per slot for each playable family.

signal closed

const FAMILIES := [["recon", "Ridgeline recon rifle"], ["sidearm", "Whisper sidearm"]]

var selectors: Dictionary = {} # family -> {slot: OptionButton}
var summary: Label

func _ready() -> void:
	var title := Label.new()
	title.text = "WORKBENCH"
	add_child(title)
	for entry in FAMILIES:
		var family: String = entry[0]
		var label := Label.new()
		label.text = entry[1]
		add_child(label)
		selectors[family] = {}
		for slot in Loadout.SLOTS:
			var parts: Array[String] = Loadout.compatible_parts(family, slot)
			if parts.is_empty():
				continue
			var row := HBoxContainer.new()
			add_child(row)
			var slot_label := Label.new()
			slot_label.text = slot.capitalize()
			row.add_child(slot_label)
			var option := OptionButton.new()
			option.add_item("Stock")
			for part_id in parts:
				option.add_item(part_id.replace("_", " ").capitalize())
			option.set_meta("parts", parts)
			row.add_child(option)
			selectors[family][slot] = option
	summary = Label.new()
	add_child(summary)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	for pair in [["Apply", apply_from_controls], ["Upgraded preset", apply_presets], ["Back", func(): closed.emit()]]:
		var button := Button.new()
		button.text = pair[0]
		button.pressed.connect(pair[1])
		buttons.add_child(button)
	load_into_controls()

func load_into_controls() -> void:
	for family in selectors:
		var parts := Loadout.parts_for(family)
		for slot in selectors[family]:
			var option: OptionButton = selectors[family][slot]
			var available: Array = option.get_meta("parts")
			option.selected = 0
			if parts.has(slot) and parts[slot] in available:
				option.selected = available.find(parts[slot]) + 1
	refresh_summary()

func apply_from_controls() -> void:
	for family in selectors:
		for slot in selectors[family]:
			var option: OptionButton = selectors[family][slot]
			var available: Array = option.get_meta("parts")
			Loadout.install(family, slot, "" if option.selected <= 0 else String(available[option.selected - 1]))
	Loadout.save_loadout()
	refresh_summary()

func apply_presets() -> void:
	for family in selectors:
		var preset: Dictionary = Loadout.Gunsmith.upgraded_preset(family)
		Loadout.clear(family)
		for slot in preset:
			Loadout.install(family, slot, preset[slot])
	Loadout.save_loadout()
	load_into_controls()

func refresh_summary() -> void:
	var lines: Array[String] = []
	for entry in FAMILIES:
		var parts := Loadout.parts_for(entry[0])
		lines.append("%s: %s" % [entry[1], "stock" if parts.is_empty() else str(parts)])
	summary.text = "\n".join(lines)
