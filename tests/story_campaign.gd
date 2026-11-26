extends SceneTree

var failures := 0
var story: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	story = root.get_node("StoryCampaign")
	story.start_new_campaign()
	check(story.active and story.active_chapter == "prologue", "New campaign begins at the prologue")
	check(story.can_continue() and story.continue_scene_path() == "res://scenes/ui/story_prologue.tscn", "New campaign can resume the prologue")
	check(story.PROLOGUE_BEATS.size() >= 8, "Prologue has a multi-beat narrative sequence")
	var prologue = load("res://scenes/ui/story_prologue.tscn").instantiate()
	root.add_child(prologue)
	await process_frame
	check(prologue.body_label.text.contains("MERIDIAN CORRIDOR") and prologue.next_button.text == "Continue", "Prologue scene renders its opening story beat")
	prologue._advance()
	check(prologue.beat_index == 1 and story.prologue_beat == 1, "Prologue advances and persists the current beat")
	prologue.queue_free()
	await process_frame
	story.set_prologue_beat(3)
	check(story.prologue_beat == 3, "Prologue position is checkpointed")
	check(story.complete_prologue(), "Prologue completion advances campaign")
	check(story.is_chapter_complete("prologue") and story.is_chapter_unlocked("kestrel_pass"), "Completing prologue unlocks Kestrel Pass")
	check(story.active_chapter == "kestrel_pass" and story.continue_scene_path() == "res://kestrel_mission.tscn", "Continue Story launches the next playable chapter")
	check(story.radio_once("test_radio", "MARA", "Radio check."), "First radio beat is accepted")
	check(not story.radio_once("test_radio", "MARA", "Radio check."), "Radio beat does not replay after it has been seen")
	var dialogue = root.get_node("StoryDialogue")
	check(dialogue.panel.visible and dialogue.line_label.text == "Radio check.", "Radio event appears in the shared dialogue overlay")
	dialogue.advance()
	check(story.add_evidence("ledger_01") and not story.add_evidence("ledger_01"), "Evidence is unique")
	check(story.has_evidence("ledger_01"), "Collected evidence is queryable")
	check(story.evidence_lines().any(func(line: String): return line.contains("ledger_01")), "Evidence dossier includes recovered entries")
	check(story.record_mission_completed("res://kestrel_mission.tscn"), "Completing active Kestrel chapter advances story")
	check(story.is_chapter_complete("kestrel_pass") and story.active_chapter == "echo_ridge", "Kestrel completion unlocks Echo Ridge")
	check(story.continue_scene_path() == "res://main.tscn", "Echo Ridge chapter maps to its existing playable scene")
	check(not story.record_mission_completed("res://compound_mission.tscn"), "Out-of-order mission cannot advance the story")
	check(story.record_mission_completed("res://main.tscn") and story.active_chapter == "compound", "Echo Ridge completion advances to the compound")
	check(story.choose_ending("release") and story.ending == "release", "Ending decision is stored")
	check(story.save_campaign(), "Campaign state saves to disk")
	var saved_chapter := story.active_chapter
	story.active_chapter = "prologue"
	check(story.load_campaign() and story.active_chapter == saved_chapter, "Campaign state reloads from disk")
	story.start_new_campaign()
	check(story.active_chapter == "prologue" and story.evidence.is_empty(), "Starting a new campaign resets prior story progress")
	story.save_campaign()
	dialogue.clear_queue()
	print("STORY CAMPAIGN TESTS PASSED") if failures == 0 else print("STORY CAMPAIGN TESTS FAILED")
	quit(0 if failures == 0 else 1)
