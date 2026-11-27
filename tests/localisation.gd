extends SceneTree

# Every player-facing string must be a key in translations/strings.csv, and the
# imported translation must return it for the exact string the game hands to
# tr() at runtime. Mirrors tools/extract_strings.py (checked below); run that
# script to add new strings.
#
# Matches are source text, so GDScript escapes are undone before lookup: a beat
# written "2041.\nA quiet home" reaches tr() with a real newline. The importer
# keeps keys verbatim (unescape_keys=false), so such a key is stored in the CSV
# as a quoted field holding a real line break, never as backslash-n.

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
	# Story text, written as raw strings identical to the Python list. These
	# accept escaped quotes inside the literal. Dialogue ids (the first
	# radio_once argument) are never displayed and are not captured.
	r'"(?:speaker|text)": "((?:[^"\\]|\\.)+)"',
	r'radio_once\(\s*"[^"]*"\s*,\s*"((?:[^"\\]|\\.)+)"',
	r'radio_once\(\s*"[^"]*"\s*,\s*"(?:[^"\\]|\\.)*"\s*,\s*"((?:[^"\\]|\\.)+)"',
	r'\.get\("(?:title|brief)", "((?:[^"\\]|\\.)+)"\)',
	r'add_(?:check|slider)_to\([^,\n]+, "([^"]+)"',
	r'"detail": "((?:[^"\\]|\\.)+)"',
	r'"name": "((?:[^"\\]|\\.)+)", "slot"',
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

# Failure messages show line breaks as \n so each entry stays on one line.
func shown(text: String) -> String:
	return text.replace("\n", "\\n")

func python_patterns() -> Array:
	var patterns := []
	var source := FileAccess.get_file_as_string("res://tools/extract_strings.py")
	var block := RegEx.create_from_string(r"(?s)\nPATTERNS = \[(.*?)\n\]").search(source)
	if block == null:
		return patterns
	for line in RegEx.create_from_string(r"(?m)^\s*r'(.*)',\s*$").search_all(block.get_string(1)):
		patterns.append(line.get_string(1))
	return patterns

func _initialize() -> void:
	var keys := csv_keys()
	check(keys.size() > 50, "Translation table loads with %d strings" % keys.size())
	check(python_patterns() == PATTERNS, "tools/extract_strings.py uses the same patterns as this suite")
	var files: Array[String] = ["res://mission.gd", "res://scope_overlay.gd", "res://gunsmith.gd"]
	gd_files("res://scenes", files)
	gd_files("res://autoload", files)
	var missing: Array[String] = []
	var runtime_strings := {}
	var scanned := 0
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for pattern in PATTERNS:
			var regex := RegEx.create_from_string(pattern)
			for result in regex.search_all(text):
				var found := result.get_string(1).c_unescape()
				scanned += 1
				if found.strip_edges().is_empty() or runtime_strings.has(found):
					continue
				runtime_strings[found] = path.get_file()
				if not keys.has(found):
					missing.append("%s: %s" % [path.get_file(), shown(found)])
	check(scanned > 50, "Scanned %d player-facing strings" % scanned)
	check(missing.is_empty(), "Every player-facing string is in the table" + ("" if missing.is_empty() else ": " + ", ".join(missing)))
	var empty: Array[String] = []
	for key in keys:
		if String(keys[key]).is_empty():
			empty.append(key)
	check(empty.is_empty(), "Every string has English text")
	var translation = load("res://translations/strings.en.translation")
	var untranslated: Array[String] = []
	var unserved: Array[String] = []
	if translation:
		for key in keys:
			if translation.get_message(key) != keys[key]:
				untranslated.append(shown(key))
		# get_message() returns "" for a missing key, unlike tr(), which falls
		# back to its input and so cannot fail for English on its own.
		for found in runtime_strings:
			if translation.get_message(found) != found:
				unserved.append("%s: %s" % [runtime_strings[found], shown(found)])
	check(translation != null and untranslated.is_empty(), "The imported English translation carries every string" + ("" if untranslated.is_empty() else ": " + ", ".join(untranslated)))
	check(translation != null and unserved.is_empty(), "The imported translation returns every source string as tr() receives it at runtime" + ("" if unserved.is_empty() else ": " + ", ".join(unserved)))
	check(translation != null and translation.get_message("Missions") == "Missions", "Translation lookup returns the English text")
	# The beats as the game really holds them, read from the StoryCampaign
	# autoload rather than the source text, so this does not rely on the
	# unescaping above. english is the translation tr() consults for English.
	var story := root.get_node_or_null("StoryCampaign")
	var english = TranslationServer.get_translation_object("en")
	var opening := String(story.PROLOGUE_BEATS[0].text) if story else ""
	check(opening.contains("\n") and not opening.contains("\\n"), "The opening story beat reaches tr() with a real newline")
	var beats_unserved: Array[String] = []
	if story and english:
		for beat in story.PROLOGUE_BEATS + story.AFTERMATH_BEATS:
			for field in ["speaker", "text"]:
				var value := String(beat[field])
				if english.get_message(value) != value:
					beats_unserved.append(shown(value))
	check(story != null and english != null and beats_unserved.is_empty() and story.tr(opening) == opening, "tr() of every prologue and aftermath beat's runtime text returns its English text from the loaded translation" + ("" if beats_unserved.is_empty() else ": " + ", ".join(beats_unserved)))
	if failures == 0:
		print("LOCALISATION TESTS PASSED")
	quit(0 if failures == 0 else 1)
