extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _fragment(id: StringName, cells: Array) -> ArtifactFragmentDefinition:
	var fragment := ArtifactFragmentDefinition.new()
	fragment.id = id
	fragment.cells.assign(cells)
	return fragment


func _expedition(normal_cells: Array, strong_cells: Array, fragments: Array[ArtifactFragmentDefinition]) -> ExpeditionDefinition:
	var definition := ExpeditionDefinition.new()
	definition.id = &"m2_1_test"
	definition.title_ru = "Тест M2.1"
	definition.debug_name = "M2.1 Test"
	definition.artifact_id = &"test_artifact"
	definition.artifact_name_ru = "Тестовая находка"
	definition.normal_soil_cells.assign(normal_cells)
	definition.strong_soil_cells.assign(strong_cells)
	definition.artifact_fragments = fragments
	return definition


func _new_game() -> Control:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	return game


func _free_game(game: Control) -> void:
	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _fill_except(session: GameSession, gaps: Array[Vector2i]) -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				session.board_model.place(single, cell, Color.DARK_GREEN)


func _run() -> void:
	_test_config_scoring()
	await _test_no_moves_cases()
	await _test_full_undo_and_reward_guards()
	await _test_hint_heuristic_and_limits()
	await _test_score_integration()
	await _test_pause_restart()
	if _failures.is_empty():
		print("M2_1_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_config_scoring() -> void:
	var config := ScoreConfig.new()
	_expect(config.score_for_lines(1) == 100, "Single line should score 100")
	_expect(config.score_for_lines(2) == 250, "Two simultaneous lines should score 250")
	_expect(config.score_for_lines(3) == 450, "Three simultaneous lines should score 450")
	_expect(config.score_for_lines(4) == 700, "Four simultaneous lines should score 700")
	_expect(config.score_for_lines(5) == 1000, "Line score should extend beyond four lines")


func _test_no_moves_cases() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var popup := game.get_node("ResultPopup") as ResultPopup
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var line := load("res://resources/pieces/line_3_horizontal.tres") as PieceDefinition
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var one_gap: Array[Vector2i] = [Vector2i(7, 7)]

	session.board_model.reset()
	_fill_except(session, one_gap)
	var one_active: Array[PieceDefinition] = [square, null, null]
	tray.load_set(one_active)
	session.evaluate_play_state()
	_expect(session.is_no_moves_state(), "One impossible active piece should enter rescue")
	_expect(popup.visible and popup.title_label.text == "РАСКОПКИ ЗАШЛИ В ТУПИК", "Rescue popup should explain the stuck state")

	session.restart_expedition()
	session.board_model.reset()
	_fill_except(session, one_gap)
	var two_active: Array[PieceDefinition] = [square, line, null]
	tray.load_set(two_active)
	session.evaluate_play_state()
	_expect(session.is_no_moves_state(), "Two impossible active pieces should enter rescue")

	session.restart_expedition()
	session.board_model.reset()
	_fill_except(session, one_gap)
	var one_legal: Array[PieceDefinition] = [square, single, null]
	tray.load_set(one_legal)
	session.evaluate_play_state()
	_expect(not session.is_no_moves_state(), "Gameplay should continue when one of two active pieces fits")

	session.restart_expedition()
	var empty_tray: Array[PieceDefinition] = [null, null, null]
	tray.load_set(empty_tray)
	session.evaluate_play_state()
	_expect(not session.is_no_moves_state(), "All used slots should refill instead of entering rescue")
	_expect(not tray.all_empty(), "All used slots should receive the next piece set")
	await _free_game(game)


func _test_full_undo_and_reward_guards() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var artifact_a := _fragment(&"a", [Vector2i(7, 0)])
	var artifact_b := _fragment(&"b", [Vector2i(0, 7)])
	var fragments: Array[ArtifactFragmentDefinition] = [artifact_a, artifact_b]
	session.expedition_definition = _expedition([Vector2i(7, 0)], [Vector2i(0, 7)], fragments)
	session.restart_expedition()
	var test_tray: Array[PieceDefinition] = [single, null, null]
	tray.load_set(test_tray)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	var prefilled: Array[Vector2i] = []
	for x in 7:
		session.board_model.place(single_shape, Vector2i(x, 0), Color.DARK_GREEN)
		prefilled.append(Vector2i(x, 0))
	board.set_cells_occupied(prefilled, Color.DARK_GREEN)
	var sequence_before := session.piece_sequence.capture_position()
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "Undo setup move should place")
	await create_timer(board.clear_feedback_duration + 0.4).timeout
	_expect(session.score == 320, "Placement, line, excavation and one fragment should be scored without victory")
	_expect(session.excavation_model.is_fragment_collected(&"a"), "Setup move should collect one fragment")
	_expect(session.has_turn_snapshot(), "Successful placement should create a snapshot")
	_fill_except(session, [])
	session.evaluate_play_state()
	_expect(session.is_no_moves_state() and session.result_popup.visible, "Blocked post-turn board should open rescue")
	_expect(session.request_undo(), "Free undo should be available")
	_expect(not session.result_popup.visible and not session.is_no_moves_state(), "Rescue Undo should close popup and restore gameplay")
	_expect(session.board_model.occupied_count() == 7, "Undo should restore BoardModel")
	_expect(session.excavation_model.get_soil_depth(Vector2i(7, 0)) == 1, "Undo should restore excavation depth")
	_expect(not session.excavation_model.is_fragment_collected(&"a"), "Undo should restore fragment state")
	_expect(tray.is_slot_available(0) and not tray.is_slot_available(1), "Undo should restore tray slots")
	_expect(session.piece_sequence.capture_position() == sequence_before, "Undo should restore sequence position")
	_expect(session.moves == 0, "Undo should restore Moves")
	_expect(session.score == 0, "Undo should restore Score")
	_expect(session.help_state.free_undos_remaining == 0, "Free undo should be consumed once")
	_expect(not session.has_turn_snapshot(), "Undo should consume the snapshot")
	_expect(not session.request_undo(), "Second immediate undo should be unavailable")

	_expect(session.try_place_piece(0, Vector2i(7, 0)), "A new placement should be possible after undo")
	await create_timer(board.clear_feedback_duration + 0.4).timeout
	_expect(session.has_turn_snapshot(), "New placement should create a new snapshot")
	var mock := session.reward_service.provider as MockRewardProvider
	mock.should_succeed = false
	var rewarded_before := session.help_state.rewarded_undos_remaining
	_expect(session.request_undo(), "Rewarded undo request should be accepted by debug provider")
	_expect(session.has_turn_snapshot(), "Failed reward must not consume snapshot")
	_expect(session.help_state.rewarded_undos_remaining == rewarded_before, "Failed reward must not grant or consume undo")
	mock.should_succeed = true
	_expect(session.request_undo(), "Successful rewarded undo request should be accepted")
	_expect(not session.has_turn_snapshot(), "Reward callback should perform rewarded undo")
	_expect(session.help_state.rewarded_undos_remaining == 0, "Only one rewarded undo should be available")

	var service := RewardedActionService.new()
	root.add_child(service)
	await process_frame
	var counters := {"grants": 0}
	service.reward_granted.connect(func(_id: int, _type: int) -> void: counters.grants += 1)
	var request_id := service.request_reward(RewardedActionService.RewardType.HINT)
	service.provider.reward_granted.emit(request_id)
	_expect(counters.grants == 1, "Duplicate provider callback should be ignored")
	service.queue_free()
	await _free_game(game)


func _test_hint_heuristic_and_limits() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var fragment := _fragment(&"buried", [Vector2i(7, 1)])
	var fragments: Array[ArtifactFragmentDefinition] = [fragment]
	var soil_row: Array[Vector2i] = []
	for x in 8:
		soil_row.append(Vector2i(x, 1))
	session.expedition_definition = _expedition(soil_row, [Vector2i(7, 1)], fragments)
	session.restart_expedition()
	var hint_tray: Array[PieceDefinition] = [single, single, null]
	tray.load_set(hint_tray)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	for row in [0, 1]:
		for x in 7:
			session.board_model.place(single_shape, Vector2i(x, row), Color.DARK_GREEN)
	var hint := session.find_best_hint()
	_expect(not hint.is_empty(), "Hint should find a legal placement")
	var hinted_piece := tray.get_definition(hint.slot_index)
	_expect(session.board_model.can_place(hinted_piece.cells, hint.origin), "Hint must select only a legal placement")
	_expect(hint.line_count == 1, "Hint should prefer a line-clearing move")
	_expect(hint.origin == Vector2i(7, 1), "Equal line clears should prefer useful excavation")
	_expect(session.request_hint(), "Free hint should work")
	_expect(session.help_state.free_hints_remaining == 0, "Free hint should consume its allowance")
	_expect(session.request_hint(), "First rewarded hint should require and receive callback")
	_expect(session.request_hint(), "Second rewarded hint should require and receive callback")
	_expect(session.help_state.rewarded_hints_remaining == 0, "Rewarded hint limit should be respected")
	_expect(not session.request_hint(), "Hint should stop after all allowances are used")

	session.help_config.idle_hint_seconds = 0.05
	session.restart_expedition()
	await create_timer(0.12).timeout
	_expect(session.is_hint_nudge_active(), "Idle Hint nudge should activate after configured threshold")
	session.reset_idle_hint_timer()
	_expect(not session.is_hint_nudge_active(), "Interaction should reset idle Hint nudge")

	session.board_model.reset()
	_fill_except(session, [])
	session.evaluate_play_state()
	_expect(session.is_no_moves_state() and not session.request_hint(), "Hint should be unavailable in rescue state")
	await _free_game(game)


func _test_score_integration() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var line3 := load("res://resources/pieces/line_3_vertical.tres") as PieceDefinition
	var fragments: Array[ArtifactFragmentDefinition] = [_fragment(&"safe", [Vector2i(7, 7)])]
	session.expedition_definition = _expedition([], [Vector2i(7, 7)], fragments)
	session.restart_expedition()
	var singles: Array[PieceDefinition] = [single, single, single]
	tray.load_set(singles)
	_expect(session.try_place_piece(0, Vector2i(3, 3)), "Plain score placement should work")
	_expect(session.score == 10, "Successful placement should add 10")
	session.restart_expedition()
	tray.load_set(singles)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	for x in 7:
		session.board_model.place(single_shape, Vector2i(x, 0), Color.DARK_GREEN)
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "Single-line score move should work")
	await create_timer(board.clear_feedback_duration + 0.05).timeout
	_expect(session.score == 110, "Placement plus one line should score 110 when no soil is hit")

	session.restart_expedition()
	tray.load_set(singles)
	for x in range(1, 8):
		session.board_model.place(single_shape, Vector2i(x, 0), Color.DARK_GREEN)
	for y in range(1, 8):
		session.board_model.place(single_shape, Vector2i(0, y), Color.DARK_GREEN)
	_expect(session.try_place_piece(0, Vector2i(0, 0)), "Two-line score move should work")
	await create_timer(board.clear_feedback_duration + 0.05).timeout
	_expect(session.score == 260, "Placement plus two simultaneous lines should score 260")

	session.restart_expedition()
	var three_line_tray: Array[PieceDefinition] = [line3, single, single]
	tray.load_set(three_line_tray)
	for y in 3:
		for x in range(1, 8):
			session.board_model.place(single_shape, Vector2i(x, y), Color.DARK_GREEN)
	_expect(session.try_place_piece(0, Vector2i(0, 0)), "Three-line score move should work")
	await create_timer(board.clear_feedback_duration + 0.05).timeout
	_expect(session.score == 460, "Placement plus three simultaneous lines should score 460")

	var victory_cells: Array[Vector2i] = []
	for x in 8:
		victory_cells.append(Vector2i(x, 0))
	var victory_fragments: Array[ArtifactFragmentDefinition] = [_fragment(&"victory", [Vector2i(7, 0)])]
	session.expedition_definition = _expedition(victory_cells, [], victory_fragments)
	session.restart_expedition()
	tray.load_set(singles)
	for x in 7:
		session.board_model.place(single_shape, Vector2i(x, 0), Color.DARK_GREEN)
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "Victory score move should work")
	await create_timer(board.clear_feedback_duration + 0.4).timeout
	_expect(session.score == 890, "Victory should score placement, line, 8 excavation hits, fragment and artifact once")
	_expect(session.coins_earned == 20, "Victory should calculate provisional coins")
	_expect(session.result_popup.score_label.text == "Счёт: 890", "Victory popup should show final score")
	_expect(session.result_popup.coins_label.text == "Монеты: +20", "Victory popup should show earned coins")
	session.restart_expedition()
	_expect(session.score == 0 and session.coins_earned == 0, "Retry should reset score and run coins")
	await _free_game(game)


func _test_pause_restart() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	_expect(session.request_hint(), "Pause restart setup should consume free hint")
	_expect(session.try_place_piece(0, Vector2i(0, 0)), "Pause restart setup move should place")
	var pause_button := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/PauseButton") as Button
	session.excavation_model.dig(Vector2i(1, 1))
	session.excavation_model.dig(Vector2i(2, 1))
	session.excavation_model.collect_newly_completed_fragments()
	_expect(session.excavation_model.collected_fragment_count() > 0, "Pause restart setup should alter excavation and fragments")
	pause_button.pressed.emit()
	var restart_button := game.get_node("PausePopup/PopupCenter/PopupPanel/PopupLayout/RestartButton") as Button
	restart_button.pressed.emit()
	await process_frame
	_expect(session.board_model.occupied_count() == 0, "Pause Restart should reset board")
	_expect(session.excavation_model.get_soil_depth(Vector2i(1, 1)) == 1, "Pause Restart should restore excavation")
	_expect(session.excavation_model.collected_fragment_count() == 0, "Pause Restart should reset fragments")
	_expect(session.moves == 0 and session.score == 0, "Pause Restart should reset moves and score")
	_expect(session.help_state.free_hints_remaining == session.help_config.free_hints, "Pause Restart should reset HelpState")
	_expect(not session.has_turn_snapshot() and not session.is_no_moves_state(), "Pause Restart should clear snapshot and rescue state")
	_expect(tray.get_definition(0).id == &"small_l", "Pause Restart should reset piece sequence")
	_expect(not session.action_feedback.visible, "Pause Restart should clear transient feedback")
	await _free_game(game)
