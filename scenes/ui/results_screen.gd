class_name ResultsScreen
extends Control

# End-of-mission summary. Score is fictional balancing.

var mission: Node
var text: Label
var panel: VBoxContainer
var continue_story_button: Button
const ThemeKit = preload("res://scenes/ui/ui_theme.gd")

func _ready() -> void:
	mission = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ThemeKit.apply(self)
	var overlay := ColorRect.new()
	overlay.color = Color(0.008, 0.014, 0.014, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	card.add_child(panel)
	text = Label.new()
	panel.add_child(text)
	button("Retry", func(): get_tree().reload_current_scene())
	continue_story_button = button(tr("Continue Story"), _continue_story)
	button("Mission select", func(): mission.quit_to_menu())
	visible = false

func button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(500, 42)
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

static func score_for(stats: Dictionary, objectives: Node, failed: bool) -> int:
	if failed:
		return 0
	var score := int(stats.kills) * 100
	score += int(round(stats.longest_kill))
	if int(stats.shots) > 0:
		score += int(round(100.0 * float(stats.hits) / float(stats.shots)))
	for objective in objectives.objectives:
		if objective.status == objectives.Status.COMPLETE:
			score += 250 if objective.kind == objectives.Kind.PRIMARY else 150
	score -= int(stats.detections) * 50
	return maxi(score, 0)

func stealth_rating(stats: Dictionary, objectives: Node) -> String:
	if objectives.status("undetected") == objectives.Status.COMPLETE:
		return tr("Ghost")
	if int(stats.detections) == 0:
		return tr("Unseen")
	return tr("Compromised") if int(stats.detections) < 3 else tr("Loud")

func show_results(progress: Dictionary = {}) -> void:
	if progress.has("challenge"):
		show_challenge_results(progress)
		return
	var stats: Dictionary = mission.stats
	var objectives = mission.level.mission_log
	var lines: Array[String] = []
	lines.append(tr("MISSION FAILED") if GameState.failed else tr("MISSION COMPLETE"))
	lines.append(tr("Score: %d") % score_for(stats, objectives, GameState.failed))
	lines.append(tr("Time: %d:%02d") % [int(stats.elapsed) / 60, int(stats.elapsed) % 60])
	lines.append(tr("Shots: %d | Hits: %d | Accuracy: %d%%") % [stats.shots, stats.hits, int(round(mission.accuracy() * 100.0))])
	lines.append(tr("Kills: %d | Longest shot: %.0f m") % [stats.kills, stats.longest_kill])
	lines.append(tr("Stealth: %s (%d detections)") % [stealth_rating(stats, objectives), stats.detections])
	if StoryCampaign.active:
		if StoryCampaign.can_continue():
			lines.append(tr("STORY UPDATED  //  NEXT: %s") % StoryCampaign.chapter_title())
		else:
			lines.append(tr("NEXT CHAPTER IN DEVELOPMENT  //  %s") % StoryCampaign.chapter_title())
		continue_story_button.visible = true
		continue_story_button.disabled = not StoryCampaign.can_continue()
	else:
		continue_story_button.visible = false
	if progress.get("new_best", false):
		lines.append(tr("New best score"))
	for id in progress.get("unlocked", []):
		lines.append(tr("Achievement unlocked:") + " " + tr(String(Progression.ACHIEVEMENTS[id].title)))
	for line in objectives.lines():
		lines.append(line)
	text.text = "\n".join(lines)
	visible = true

static func clock_text(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]

# A long-shot challenge: pass or fail and why, the score and its parts, plates,
# rounds and time against the limits, new bests, and the standing record.
func show_challenge_results(progress: Dictionary) -> void:
	var attempt: Dictionary = progress.challenge
	var parts: Dictionary = attempt.parts
	var stats: Dictionary = mission.stats
	var lines: Array[String] = []
	lines.append(tr("CHALLENGE PASSED") if attempt.passed else tr("CHALLENGE FAILED"))
	lines.append(tr(String(attempt.title)))
	match String(attempt.get("reason", "")):
		"out_of_rounds":
			lines.append(tr("Out of rounds"))
		"out_of_time":
			lines.append(tr("Out of time"))
	lines.append(tr("Score: %d") % int(attempt.score))
	if attempt.passed:
		lines.append(tr("Plates %d + rounds %d + time %d") % [int(parts.distance), int(parts.rounds), int(parts.time)])
	lines.append(tr("Plates rung: %d / %d  |  Rounds used: %d / %d") % [int(attempt.plates_rung), int(attempt.plate_count), int(attempt.rounds_used), int(attempt.rounds)])
	if float(attempt.time_limit) > 0.0:
		lines.append(tr("Time: %s of %s") % [clock_text(float(attempt.time)), clock_text(float(attempt.time_limit))])
	else:
		lines.append(tr("Time: %d:%02d") % [int(attempt.time) / 60, int(attempt.time) % 60])
	lines.append(tr("Shots: %d | Hits: %d | Accuracy: %d%%") % [stats.shots, stats.hits, int(round(mission.accuracy() * 100.0))])
	if progress.get("new_best", false):
		lines.append(tr("New best score"))
	if progress.get("new_fewest_rounds", false):
		lines.append(tr("New fewest rounds"))
	if progress.get("new_fastest", false):
		lines.append(tr("New fastest time"))
	for id in progress.get("unlocked", []):
		lines.append(tr("Achievement unlocked:") + " " + tr(String(Progression.ACHIEVEMENTS[id].title)))
	lines.append(tr("Your record:") + " " + Progression.challenge_record_text(String(attempt.id)))
	text.text = "\n".join(lines)
	continue_story_button.visible = false
	visible = true

func _continue_story() -> void:
	var path := StoryCampaign.continue_scene_path()
	if not path.is_empty():
		get_tree().change_scene_to_file(path)
