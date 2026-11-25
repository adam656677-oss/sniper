extends SceneTree

# Every player-facing string must be a key in translations/strings.csv.
# Mirrors tools/extract_strings.py; run that script to add new strings.

const PATTERNS := [
	"(?:button|make_button)\\([^\"\\n]*\"([^\"]+)\"",
	"add_check\\(\"([^\"]+)\"\\)",
	"add_slider\\(\"([^\"]+)\"",
	"make_label\\(\"([^\"]+)\"\\)",
	"add_item\\(\"([^\"]+)\"\\)",
	"\\.text = \"([^\"%]+)\"(?!\\.)",
	"mission_log\\.add\\(\"[^\"]+\", \"([^\"]+)\"",
	"\\[\"t_\\w+\", \"([^\"]+)\"\\]",
	"\"(?:title|brief)\": \"([^\"]+)\"",
	"tr\\(\"([^\"]+)\"\\)",
]
var failures := 0

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func gd_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(path.path_join(file))
	for sub in dir.get_directories():
		gd_files(path.path_join(sub), out)

func csv_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			keys[row[0]] = row[1]
	return keys

func _initialize() -> void:
	var keys := csv_keys()
	check(keys.size() > 50, "Translation table loads with %d strings" % keys.size())
	var files: Array[String] = ["res://mission.gd", "res://scope_overlay.gd"]
	gd_files("res://scenes", files)
	gd_files("res://autoload", files)
	var missing: Array[String] = []
	var scanned := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for pattern in PATTERNS:
			var regex := RegEx.create_from_string(pattern)
			for result in regex.search_all(text):
				var found := result.get_string(1)
				scanned += 1
				if not found.strip_edges().is_empty() and not keys.has(found):
					missing.append("%s: %s" % [path.get_file(), found])
	check(scanned > 50, "Scanned %d player-facing strings" % scanned)
	check(missing.is_empty(), "Every player-facing string is in the table" + ("" if missing.is_empty() else ": " + ", ".join(missing)))
	var empty: Array[String] = []
	for key in keys:
		if String(keys[key]).is_empty():
			empty.append(key)
	check(empty.is_empty(), "Every string has English text")
	var translation = load("res://translations/strings.en.translation")
	var untranslated: Array[String] = []
	if translation:
		for key in keys:
			if translation.get_message(key) != keys[key]:
				untranslated.append(key)
	check(translation != null and untranslated.is_empty(), "The imported English translation carries every string" + ("" if untranslated.is_empty() else ": " + ", ".join(untranslated)))
	check(translation != null and translation.get_message("Missions") == "Missions", "Translation lookup returns the English text")
	if failures == 0:
		print("LOCALISATION TESTS PASSED")
	quit(0 if failures == 0 else 1)
