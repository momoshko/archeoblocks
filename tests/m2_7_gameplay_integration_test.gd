extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_7_gameplay_progress.cfg"

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
	_delete_progress()
	var game := load("res://scenes/screens/game_screen_stone_prototype.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := session.board_view
	var stone_cell := Vector2i(6, 3)
	var stone_view := board.get_cell_view(stone_cell)
	_expect(session.obstacle_model.occupied_count() == 4, "Restart should load all four initial Stones")
	_expect(stone_view.stone_obstacle.visible, "Stone should have a scene-authored board visual")
	_expect(stone_view.artifact_target_border.visible, "Artifact target below Stone should remain visibly marked")
	_expect(stone_view.artifact_target_border.z_index > stone_view.stone_obstacle.z_index, "Artifact marker should render above Stone")
	game.call("_open_pause")
	_expect((game.get_node("ModalUI/PausePopup") as Control).visible, "Pause modal should open above prototype gameplay")
	game.call("_close_pause")
	_expect(not session.try_place_piece(2, stone_cell), "Gameplay placement should reject the single block on Stone")
	board.show_placement_preview([stone_cell], false, Color.RED)
	_expect(stone_view.invalid_preview.visible, "Normal drag preview should show the existing invalid treatment over Stone")
	board.clear_placement_preview()

	_expect(session.try_place_piece(0, Vector2i(0, 3)), "First Line 3 should place before the Stone")
	_expect(session.try_place_piece(1, Vector2i(3, 3)), "Second Line 3 should continue the Stone row")
	_expect(session.try_place_piece(2, Vector2i(7, 3)), "Single should complete the row while Stone supplies its filled cell")
	await create_timer(board.clear_feedback_duration + board.stone_hit_feedback_duration + 0.2).timeout
	_expect(not session.obstacle_model.has_obstacle(stone_cell), "Completed row should destroy Stone")
	_expect(session.excavation_model.get_soil_depth(stone_cell) == 1, "Single Stone hit should not excavate underlying soil")
	_expect(not stone_view.stone_obstacle.visible, "Destroyed Stone visual should be removed after feedback")
	_expect(session.has_turn_snapshot(), "Stone-destroying move should remain undoable")
	_expect(session.request_undo(), "One-turn Undo should accept the Stone-destroying move")
	_expect(session.obstacle_model.get_durability(stone_cell) == 1, "Undo should restore previous Stone durability")
	_expect(stone_view.stone_obstacle.visible, "Undo should restore the Stone visual")
	_expect(session.excavation_model.get_soil_depth(stone_cell) == 1, "Undo should restore underlying excavation state")

	session.restart_expedition()
	_expect(session.obstacle_model.occupied_count() == 4, "Restart should restore the complete initial Stone layout")
	_expect(session.board_model.occupied_count() == 0, "Restart should clear temporary player Blocks")
	for fragment_id in [&"shrine_relief_a", &"shrine_relief_b"]:
		for cell in session.excavation_model.get_fragment_cells(fragment_id):
			session.excavation_model.dig(cell, 99)
		session.excavation_model.collect_newly_completed_fragments()
	_expect(session.excavation_model.all_fragments_complete(), "Fixture should complete the artifact while unrelated Stones remain")
	session._finish_victory()
	_expect(session.result_popup.visible, "Artifact completion should allow normal Victory while Stones remain")
	_expect(session.obstacle_model.occupied_count() == 4, "Victory must not require clearing unrelated Stones")
	_expect((game.get_node("ModalUI") as CanvasLayer).layer > stone_view.stone_obstacle.z_index, "ModalUI should remain above Stone visuals")

	game.queue_free()
	await process_frame
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_7_GAMEPLAY_INTEGRATION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
