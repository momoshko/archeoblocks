extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_11_onboarding_progress.cfg"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	_delete_test_progress()
	await _test_guided_first_run()
	await _test_completed_replay_starts_tutorial_and_can_skip()
	await _test_other_expeditions_do_not_start_tutorial()
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_11_ONBOARDING_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_guided_first_run() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	await process_frame

	var session := game.get_node("GameSession") as GameSession
	var tutorial := game.get_node("TutorialUI/OnboardingTutorial") as OnboardingTutorial
	var tray := session.piece_tray
	var slots := tray.get_children()
	_expect(tutorial.visible, "First unfinished expedition should show the onboarding overlay")
	_expect(game.get_node("TutorialUI").layer < game.get_node("ModalUI").layer, "Modal UI must remain above the tutorial")
	_expect(session._tutorial_active and session._tutorial_required_slot == 0, "Tutorial should initially require the first curated piece")
	_expect(
		slots[0].mouse_filter == Control.MOUSE_FILTER_STOP
		and slots[1].mouse_filter == Control.MOUSE_FILTER_IGNORE
		and slots[2].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Only the instructed tray slot should accept input"
	)
	_expect(not session.try_place_piece(1, Vector2i(3, 3)), "A non-instructed piece must not bypass the tutorial gate")
	_expect(not session.try_place_piece(0, Vector2i(1, 3)), "The instructed piece must only place at the highlighted origin")

	tutorial.continue_button.pressed.emit()
	_expect(tutorial.spotlight_border.visible and not tutorial.continue_button.visible, "Continue should advance to the interactive take-piece step")
	_expect(session.try_place_piece(0, Vector2i(0, 3)), "First guided placement should be accepted")
	_expect(session._tutorial_required_slot == 1 and tutorial._placement_index == 1, "Tutorial should advance to the second piece")
	_expect(session.try_place_piece(1, Vector2i(3, 3)), "Second guided placement should be accepted")
	_expect(session._tutorial_required_slot == 2 and tutorial._placement_index == 2, "Tutorial should advance to the final piece")
	_expect(session.try_place_piece(2, Vector2i(6, 3)), "Final guided placement should complete the excavation line")
	await create_timer(session.board_view.clear_feedback_duration + 1.4).timeout
	_expect(not tutorial.visible and not session._tutorial_active, "Tutorial should release all input gates after the artifact is found")
	_expect(session.excavation_model.all_fragments_complete(), "Guided placements should teach line clear into artifact excavation")
	_expect(ProgressStore.is_expedition_completed(&"expedition_01"), "Existing victory flow should persist first-expedition completion")
	await _remove_scene(game)
	current_scene = null


func _test_completed_replay_starts_tutorial_and_can_skip() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tutorial := game.get_node("TutorialUI/OnboardingTutorial") as OnboardingTutorial
	_expect(tutorial.visible and session._tutorial_active, "Play should start Expedition 1 onboarding even after an earlier completion")
	_expect(tutorial.skip_button.visible, "Onboarding should provide an explicit skip button")
	tutorial.skip_button.pressed.emit()
	_expect(not tutorial.visible, "Skip should close the onboarding overlay")
	_expect(not session._tutorial_active and session.piece_tray._required_slot == -1, "Skip should immediately restore ordinary piece input")
	await _remove_scene(game)


func _test_other_expeditions_do_not_start_tutorial() -> void:
	var game := load("res://scenes/screens/game_screen_02.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tutorial := game.get_node("TutorialUI/OnboardingTutorial") as OnboardingTutorial
	_expect(session.expedition_definition.id == &"expedition_02", "Regression fixture should load Expedition 2")
	_expect(not tutorial.visible and not session._tutorial_active, "Expedition 2 must not inherit Expedition 1 tutorial coordinates or input gate")
	_expect(session.piece_tray._required_slot == -1, "Expedition 2 tray should remain unrestricted")
	await _remove_scene(game)


func _remove_scene(node: Node) -> void:
	if is_instance_valid(node) and node.get_parent() == root:
		root.remove_child(node)
		node.queue_free()
	await process_frame


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
