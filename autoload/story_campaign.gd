extends Node

# Persistent single-player narrative state. This tracks campaign progress separately
# from mission checkpoints and standalone mission records.

signal state_changed
signal dialogue_requested(speaker: String, line: String)
signal evidence_added(evidence_id: String)

const SAVE_PATH := "user://campaign/story.json"
const SAVE_VERSION := 1

const PROLOGUE_BEATS := [
	{"speaker": "NARRATOR", "text": "MERIDIAN CORRIDOR — 2041.\nA quiet home, far from the city lights. For the first time in years, Elias Vance believes the war is behind him."},
	{"speaker": "LENA VALE", "text": "You said we'd get one normal evening. No radios. No work. Just us."},
	{"speaker": "ELIAS VANCE", "text": "I kept my promise. The phone is off. The world can wait until morning."},
	{"speaker": "LENA VALE", "text": "I wish it could. I found something inside Asterion's system. Names, payments, people who were supposed to have disappeared. They're calling it NIGHTGLASS."},
	{"speaker": "NARRATOR", "text": "Outside, headlights cut through the trees. The power dies. A team moves toward the house with practiced silence."},
	{"speaker": "MARA QUILL — RADIO", "text": "Elias, this is Mara. Get down! That's not a police response. Move, now!"},
	{"speaker": "NARRATOR", "text": "The strike team leaves the house burning. Lena is gone. Elias survives beneath the wreckage, wounded and alone. By sunrise, Asterion has already rewritten the story: Elias Vance is the terrorist responsible."},
	{"speaker": "ELIAS VANCE", "text": "Lena... I'm sorry. I should have seen them coming."},
	{"speaker": "NARRATOR", "text": "A damaged data key is still in his hand. One fragment of Lena's Black Ledger. One name in the operation log: VARN ACCORD."}
]

const CHAPTERS := {
	"prologue": {"title": "The Last Quiet Night", "scene": "res://scenes/ui/story_prologue.tscn", "next": "kestrel_pass"},
	"kestrel_pass": {"title": "Kestrel Pass", "scene": "res://kestrel_mission.tscn", "next": "echo_ridge"},
	"echo_ridge": {"title": "Echo Ridge", "scene": "res://main.tscn", "next": "compound"},
	"compound": {"title": "The Compound", "scene": "res://compound_mission.tscn", "next": "lowwater_bridge"},
	"lowwater_bridge": {"title": "Lowwater Bridge", "scene": "", "next": "glass_hollow"},
	"glass_hollow": {"title": "Glass Hollow", "scene": "", "next": "saltmarsh_station"},
	"saltmarsh_station": {"title": "Saltmarsh Station", "scene": "", "next": "overwatch"},
	"overwatch": {"title": "Overwatch", "scene": "", "next": "high_cairn"},
	"high_cairn": {"title": "High Cairn — The Last Contract", "scene": "", "next": ""}
}

const SCENE_TO_CHAPTER := {
	"res://kestrel_mission.tscn": "kestrel_pass",
	"res://main.tscn": "echo_ridge",
	"res://compound_mission.tscn": "compound"
}

var active := false
var active_chapter := ""
var completed_chapters: Array[String] = []
var unlocked_chapters: Array[String] = []
var evidence: Array[String] = []
var seen_dialogue: Array[String] = []
var flags: Dictionary = {}
var prologue_beat := 0
var ending := ""

func _ready() -> void:
	load_campaign()

func start_new_campaign() -> void:
	active = true
	active_chapter = "prologue"
	completed_chapters.clear()
	unlocked_chapters = ["prologue"]
	evidence.clear()
	seen_dialogue.clear()
	flags.clear()
	prologue_beat = 0
	ending = ""
	save_campaign()
	state_changed.emit()

func can_continue() -> bool:
	return active and not active_chapter.is_empty() and CHAPTERS.has(active_chapter) and not String(CHAPTERS[active_chapter].scene).is_empty()

func continue_scene_path() -> String:
	if not can_continue():
		return ""
	if active_chapter == "prologue" and bool(get_flag("prologue_intro_seen", false)):
		return "res://scenes/ui/prologue_home.tscn"
	return String(CHAPTERS.get(active_chapter, {}).get("scene", ""))

func chapter_title(chapter_id: String = "") -> String:
	var key := active_chapter if chapter_id.is_empty() else chapter_id
	return tr(String(CHAPTERS.get(key, {}).get("title", "Unknown chapter")))

func complete_prologue() -> bool:
	if not active:
		return false
	if not completed_chapters.has("prologue"):
		completed_chapters.append("prologue")
	_unlock_next("prologue")
	prologue_beat = PROLOGUE_BEATS.size() - 1
	save_campaign()
	state_changed.emit()
	return true

func set_prologue_beat(value: int) -> void:
	prologue_beat = clampi(value, 0, PROLOGUE_BEATS.size() - 1)
	save_campaign()

func begin_chapter(chapter_id: String) -> bool:
	if not active or not unlocked_chapters.has(chapter_id) or not CHAPTERS.has(chapter_id):
		return false
	active_chapter = chapter_id
	save_campaign()
	state_changed.emit()
	return true

func record_mission_completed(scene_path: String) -> bool:
	if not active:
		return false
	var chapter_id := String(SCENE_TO_CHAPTER.get(scene_path, ""))
	if chapter_id.is_empty() or chapter_id != active_chapter:
		return false
	if not completed_chapters.has(chapter_id):
		completed_chapters.append(chapter_id)
	_unlock_next(chapter_id)
	save_campaign()
	state_changed.emit()
	return true

func _unlock_next(chapter_id: String) -> void:
	var next_id := String(CHAPTERS.get(chapter_id, {}).get("next", ""))
	if next_id.is_empty():
		active_chapter = ""
		return
	if not unlocked_chapters.has(next_id):
		unlocked_chapters.append(next_id)
	active_chapter = next_id

func is_chapter_unlocked(chapter_id: String) -> bool:
	return unlocked_chapters.has(chapter_id)

func is_chapter_complete(chapter_id: String) -> bool:
	return completed_chapters.has(chapter_id)

func set_flag(flag_id: String, value: Variant = true) -> void:
	if flag_id.strip_edges().is_empty():
		return
	flags[flag_id] = value
	save_campaign()

func get_flag(flag_id: String, fallback: Variant = false) -> Variant:
	return flags.get(flag_id, fallback)

func add_evidence(evidence_id: String) -> bool:
	if evidence_id.strip_edges().is_empty() or evidence.has(evidence_id):
		return false
	evidence.append(evidence_id)
	evidence_added.emit(evidence_id)
	save_campaign()
	return true

func has_evidence(evidence_id: String) -> bool:
	return evidence.has(evidence_id)

func evidence_lines() -> Array[String]:
	var lines: Array[String] = [tr("BLACK LEDGER  //  RECOVERED EVIDENCE")]
	if evidence.is_empty():
		lines.append(tr("No evidence recovered yet. Complete story objectives to find fragments of Lena's archive."))
		return lines
	for evidence_id in evidence:
		match evidence_id:
			"black_ledger_fragment_01":
				lines.append(tr("FILE 01 — THE DEPOT LEDGER"))
				lines.append(tr("A payment trail links the Varn Accord raid team to an Asterion shell account. The authorization mark is partially corrupted, but the NIGHTGLASS program tag is intact."))
			_:
				lines.append(tr("RECOVERED FILE: %s") % evidence_id)
	return lines

func radio_once(dialogue_id: String, speaker: String, line: String) -> bool:
	if not active or dialogue_id.is_empty() or seen_dialogue.has(dialogue_id):
		return false
	seen_dialogue.append(dialogue_id)
	save_campaign()
	dialogue_requested.emit(tr(speaker), tr(line))
	return true

func on_mission_started(scene_path: String) -> void:
	if not active or String(SCENE_TO_CHAPTER.get(scene_path, "")) != active_chapter:
		return
	match active_chapter:
		"kestrel_pass":
			radio_once("kestrel_briefing", "MARA QUILL — RADIO", "Echo, confirm your position. The depot supplied the team that hit your home. Find the records office. We need proof, not another blind shot.")
		"echo_ridge":
			radio_once("echo_ridge_briefing", "IMANI ROOK — RADIO", "I have the first fragment. The names are scrubbed, but the routing mark is intact. Bring me the rest and I can tell you who paid for the raid.")
		"compound":
			radio_once("compound_briefing", "MARA QUILL — RADIO", "The Accord moved its archive to this compound. Rusk's people are guarding it. Stay sharp, Echo. He's closer than you think.")

func on_objective_completed(scene_path: String, objective_id: String) -> void:
	if not active:
		return
	if scene_path == "res://kestrel_mission.tscn":
		match objective_id:
			"commander":
				radio_once("kestrel_commander_down", "MARA QUILL — RADIO", "Commander is down. The office is your next stop. Look for the ledger and anything bearing Rusk's authorization.")
			"ledger":
				add_evidence("black_ledger_fragment_01")
				radio_once("kestrel_ledger_recovered", "IMANI ROOK — RADIO", "I'm reading the fragment now. This isn't a depot manifest. It's a payment trail. One program name keeps appearing: NIGHTGLASS.")
			"radio":
				radio_once("kestrel_radio_disabled", "MARA QUILL — RADIO", "Mast is dark. That buys you a little time. Get to the saddle before they bring in another team.")

func choose_ending(choice: String) -> bool:
	if not ["release", "inquiry", "destroy"].has(choice) or not active:
		return false
	ending = choice
	flags["ending_choice"] = choice
	save_campaign()
	state_changed.emit()
	return true

func save_campaign() -> bool:
	var directory := ProjectSettings.globalize_path("user://campaign")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"active": active,
		"active_chapter": active_chapter,
		"completed_chapters": completed_chapters,
		"unlocked_chapters": unlocked_chapters,
		"evidence": evidence,
		"seen_dialogue": seen_dialogue,
		"flags": flags,
		"prologue_beat": prologue_beat,
		"ending": ending
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func load_campaign() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or int(parsed.get("version", -1)) != SAVE_VERSION:
		return false
	active = bool(parsed.get("active", false))
	active_chapter = String(parsed.get("active_chapter", ""))
	completed_chapters.clear()
	unlocked_chapters.clear()
	evidence.clear()
	seen_dialogue.clear()
	for value in parsed.get("completed_chapters", []):
		completed_chapters.append(String(value))
	for value in parsed.get("unlocked_chapters", []):
		unlocked_chapters.append(String(value))
	for value in parsed.get("evidence", []):
		evidence.append(String(value))
	for value in parsed.get("seen_dialogue", []):
		seen_dialogue.append(String(value))
	var loaded_flags = parsed.get("flags", {})
	flags = loaded_flags if loaded_flags is Dictionary else {}
	prologue_beat = clampi(int(parsed.get("prologue_beat", 0)), 0, PROLOGUE_BEATS.size() - 1)
	ending = String(parsed.get("ending", ""))
	return true
