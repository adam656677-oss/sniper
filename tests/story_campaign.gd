extends SceneTree

var failures := 0
var story: Node

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func beats_text(beats: Array) -> String:
	var text := ""
	for beat in beats:
		text += String(beat.text) + "\n"
	return text

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	story = root.get_node("StoryCampaign")
	story.start_new_campaign()
	check(story.active and story.active_chapter == "prologue", "New campaign begins at the prologue")
	check(story.can_continue() and story.continue_scene_path() == "res://scenes/ui/story_prologue.tscn", "New campaign can resume the prologue")
	check(story.PROLOGUE_BEATS.size() >= 3, "Prologue intro sets up the evening over several beats")
	check(not beats_text(story.PROLOGUE_BEATS).contains("VARN ACCORD") and not beats_text(story.PROLOGUE_BEATS).contains("terrorist"), "Prologue intro stops before the attack the player is about to play")
	check(story.AFTERMATH_BEATS.size() >= 3 and beats_text(story.AFTERMATH_BEATS).contains("VARN ACCORD") and beats_text(story.AFTERMATH_BEATS).contains("Lena"), "Prologue aftermath carries Lena's loss, the framing and the first lead")
	var prologue_scene: PackedScene = load("res://scenes/ui/story_prologue.tscn")
	check(prologue_scene != null, "Prologue scene resource loads")
	if prologue_scene == null:
		quit(1)
		return
	var prologue = prologue_scene.instantiate()
	root.add_child(prologue)
	await process_frame
	check(prologue.body_label.text.contains("MERIDIAN CORRIDOR") and prologue.next_button.text == "Continue", "Prologue scene renders its opening story beat")
	var home_scene: PackedScene = load("res://scenes/ui/prologue_home.tscn")
	check(home_scene != null, "Playable home prologue scene resource loads")
	if home_scene != null:
		var home = home_scene.instantiate()
		root.add_child(home)
		await process_frame
		check(home.player != null and home.camera != null, "Playable prologue creates a first-person player and camera")
		home.auto_transition = false
		check(home.interactables.size() == 3, "Playable prologue exposes three story discoveries")
		check(home.attack_lights.size() == 2 and home.fade_rect != null, "Prologue builds exterior headlights and a cinematic fade")
		check(home.interact_with("photo") and home.interact_with("lena") and home.interact_with("ledger"), "Player can inspect the photo, talk to Lena and recover her data key")
		check(home.attack_started and story.has_evidence("black_ledger_fragment_00"), "Three discoveries trigger the home attack and recover ledger evidence")
		story.set_flag("prologue_intro_seen", true)
		check(story.continue_scene_path() == "res://scenes/ui/prologue_home.tscn", "Continue Story resumes the playable home sequence after the intro")
		home.queue_free()
		await process_frame
		story.start_new_campaign()
		story.save_campaign()
		root.get_node("StoryDialogue").clear_queue()
	prologue._advance()
	check(prologue.beat_index == 1 and story.prologue_beat == 1, "Prologue advances and persists the current beat")
	prologue.queue_free()
	await process_frame
	story.set_prologue_beat(3)
	check(story.prologue_beat == 3, "Prologue position is checkpointed")
	check(story.complete_prologue(), "Prologue completion advances campaign")
	check(story.is_chapter_complete("prologue") and story.is_chapter_unlocked("kestrel_pass"), "Completing prologue unlocks Kestrel Pass")
	check(story.active_chapter == "kestrel_pass" and story.continue_scene_path() == "res://kestrel_mission.tscn", "Continue Story launches the next playable chapter")
	var briefing_dialogue = root.get_node("StoryDialogue")
	briefing_dialogue.clear_queue()
	story.set_flag("prologue_escape_unseen", true)
	story.on_mission_started("res://kestrel_mission.tscn")
	check(briefing_dialogue.line_label.text.contains("died in that fire"), "Kestrel briefing acknowledges an unseen prologue escape")
	briefing_dialogue.clear_queue()
	story.seen_dialogue.erase("kestrel_briefing")
	story.set_flag("prologue_escape_unseen", false)
	story.on_mission_started("res://kestrel_mission.tscn")
	check(briefing_dialogue.line_label.text.contains("know you got out"), "Kestrel briefing acknowledges that Elias was seen escaping")
	briefing_dialogue.clear_queue()
	check(story.radio_once("test_radio", "MARA", "Radio check."), "First radio beat is accepted")
	check(not story.radio_once("test_radio", "MARA", "Radio check."), "Radio beat does not replay after it has been seen")
	var dialogue = root.get_node("StoryDialogue")
	check(dialogue.panel.visible and dialogue.line_label.text == "Radio check.", "Radio event appears in the shared dialogue overlay")
	var advance_event := InputEventAction.new()
	advance_event.action = "ui_accept"
	advance_event.pressed = true
	Input.parse_input_event(advance_event)
	await process_frame
	check(not dialogue.panel.visible, "Keyboard input advances and dismisses radio dialogue")
	check(story.add_evidence("ledger_01") and not story.add_evidence("ledger_01"), "Evidence is unique")
	check(story.has_evidence("ledger_01"), "Collected evidence is queryable")
	check(story.evidence_lines().back().contains("ledger_01"), "Evidence dossier includes recovered entries")
	check(story.record_mission_completed("res://kestrel_mission.tscn"), "Completing active Kestrel chapter advances story")
	check(story.is_chapter_complete("kestrel_pass") and story.active_chapter == "echo_ridge", "Kestrel completion unlocks Echo Ridge")
	check(story.continue_scene_path() == "res://main.tscn", "Echo Ridge chapter maps to its existing playable scene")
	check(not story.record_mission_completed("res://compound_mission.tscn"), "Out-of-order mission cannot advance the story")
	check(story.record_mission_completed("res://main.tscn") and story.active_chapter == "compound", "Echo Ridge completion advances to the compound")
	check(story.choose_ending("release") and story.ending == "release", "Ending decision is stored")
	check(story.save_campaign(), "Campaign state saves to disk")
	var saved_chapter: String = story.active_chapter
	story.active_chapter = "prologue"
	check(story.load_campaign() and story.active_chapter == saved_chapter, "Campaign state reloads from disk")
	story.start_new_campaign()
	check(story.active_chapter == "prologue" and story.evidence.is_empty(), "Starting a new campaign resets prior story progress")
	story.save_campaign()
	dialogue.clear_queue()
	print("STORY CAMPAIGN TESTS PASSED") if failures == 0 else print("STORY CAMPAIGN TESTS FAILED")
	quit(0 if failures == 0 else 1)
