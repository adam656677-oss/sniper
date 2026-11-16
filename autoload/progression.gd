extends Node

# Local records per mission and achievements, persisted to user://progress.cfg.
# record() is called once when a mission ends and returns what changed.

const PATH := "user://progress.cfg"
const MissionCatalog = preload("res://scenes/ui/mission_catalog.gd")
const ResultsScoring = preload("res://scenes/ui/results_screen.gd")

const ACHIEVEMENTS := {
	"first_blood": {"title": "First blood", "detail": "Make your first kill."},
	"long_shot_500": {"title": "Reach out", "detail": "Kill at 500 m or more."},
	"long_shot_1000": {"title": "One kilometre", "detail": "Hit something 1000 m away."},
	"marksman": {"title": "Marksman", "detail": "Finish a mission with 80% accuracy over five or more shots."},
	"ghost": {"title": "Ghost", "detail": "Finish the compound without being detected."},
	"silent": {"title": "Quiet professional", "detail": "Finish the compound using only suppressed fire."},
	"graduate": {"title": "Graduate", "detail": "Finish every tutorial step on the range."},
	"range_master": {"title": "Range master", "detail": "Ring every plate on the range."},
}

signal unlocked(id: String)

var records: Dictionary = {} # mission id -> {best_score, best_time, longest_shot, completions}
var achievements: Dictionary = {} # id -> unlock timestamp

func _ready() -> void:
	load_progress()

func reset() -> void:
	records = {}
	achievements = {}

func has_achievement(id: String) -> bool:
	return achievements.has(id)

func unlock(id: String) -> bool:
	if not ACHIEVEMENTS.has(id) or achievements.has(id):
		return false
	achievements[id] = Time.get_datetime_string_from_system()
	unlocked.emit(id)
	return true

func mission_id_for(scene_path: String) -> String:
	var index := MissionCatalog.index_for_scene(scene_path)
	return String(MissionCatalog.get_mission(index).get("id", scene_path.get_file().get_basename()))

# Returns {"new_best": bool, "unlocked": Array[String]}.
func record(mission_id: String, stats: Dictionary, log: Node, failed: bool) -> Dictionary:
	var result := {"new_best": false, "unlocked": [] as Array[String]}
	var shots := int(stats.get("shots", 0))
	var accuracy := 0.0 if shots == 0 else float(stats.get("hits", 0)) / float(shots)
	var longest := float(stats.get("longest_kill", 0.0))
	var completed: Callable = func(id: String) -> bool: return log.status(id) == log.Status.COMPLETE
	var checks := {
		"first_blood": int(stats.get("kills", 0)) > 0,
		"long_shot_500": longest >= 500.0,
		"long_shot_1000": longest >= 1000.0 or completed.call("long_shot"),
		"marksman": not failed and shots >= 5 and accuracy >= 0.8,
		"ghost": not failed and mission_id == "compound" and completed.call("undetected"),
		"silent": not failed and mission_id == "compound" and completed.call("silent"),
		"graduate": completed.call("t_holdover"),
		"range_master": completed.call("plates"),
	}
	for id in checks:
		if checks[id] and unlock(id):
			result.unlocked.append(id)
	if not failed:
		var entry: Dictionary = records.get(mission_id, {"best_score": 0, "best_time": 0.0, "longest_shot": 0.0, "completions": 0})
		var score := ResultsScoring.score_for(stats, log, false)
		var elapsed := float(stats.get("elapsed", 0.0))
		if score > int(entry.best_score):
			entry.best_score = score
			result.new_best = true
		if float(entry.best_time) <= 0.0 or elapsed < float(entry.best_time):
			entry.best_time = elapsed
		entry.longest_shot = maxf(float(entry.longest_shot), longest)
		entry.completions = int(entry.completions) + 1
		records[mission_id] = entry
	save_progress()
	return result

func save_progress() -> bool:
	var config := ConfigFile.new()
	for mission_id in records:
		for key in records[mission_id]:
			config.set_value("record_" + mission_id, key, records[mission_id][key])
	for id in achievements:
		config.set_value("achievements", id, achievements[id])
	return config.save(PATH) == OK

func load_progress() -> bool:
	reset()
	var config := ConfigFile.new()
	if not FileAccess.file_exists(PATH) or config.load(PATH) != OK:
		return false
	for section in config.get_sections():
		if section.begins_with("record_"):
			var entry := {}
			for key in ["best_score", "best_time", "longest_shot", "completions"]:
				entry[key] = config.get_value(section, key, 0)
			records[section.trim_prefix("record_")] = entry
		elif section == "achievements":
			for id in config.get_section_keys(section):
				if ACHIEVEMENTS.has(id):
					achievements[id] = String(config.get_value(section, id))
	return true

func summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for i in range(MissionCatalog.count()):
		var mission: Dictionary = MissionCatalog.get_mission(i)
		var entry: Dictionary = records.get(mission.id, {})
		if entry.is_empty():
			lines.append("%s: %s" % [tr(String(mission.title)), tr("not completed")])
		else:
			lines.append("%s: %s %d  |  %s %d:%02d  |  %s %.0f m" % [tr(String(mission.title)), tr("best"), int(entry.best_score), tr("fastest"), int(entry.best_time) / 60, int(entry.best_time) % 60, tr("longest"), float(entry.longest_shot)])
	lines.append("")
	lines.append(tr("Achievements") + " %d / %d" % [achievements.size(), ACHIEVEMENTS.size()])
	for id in ACHIEVEMENTS:
		lines.append("%s %s: %s" % ["[x]" if achievements.has(id) else "[ ]", tr(String(ACHIEVEMENTS[id].title)), tr(String(ACHIEVEMENTS[id].detail))])
	return lines
