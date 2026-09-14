extends SceneTree

var _failures: Array[String] = []
var _checks := 0
var _single: PieceDefinition


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


func _expedition(normal_cells: Array, fragments: Array) -> ExpeditionDefinition:
	var definition := ExpeditionDefinition.new()
	definition.id = &"m2_3c_test"
	definition.title_ru = "Тест M2.3C"
	definition.debug_name = "M2.3C Test"
	definition.artifact_id = &"test_artifact"
	definition.artifact_name_ru = "Тестовая находка"
	definition.normal_soil_cells.assign(normal_cells)
	var typed_fragments: Array[ArtifactFragmentDefinition] = []
	typed_fragments.assign(fragments)
	definition.artifact_fragments = typed_fragments
	return definition


func _run() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	_expect(session != null and tray != null, "GameScreen should instantiate Hint safety dependencies")
	if session == null or tray == null:
		await _finish(game)
		return
	_single = load("res://resources/pieces/single.tres") as PieceDefinition

	_test_surviving_move_beats_higher_scoring_loss(session, tray)
	_test_best_loss_is_allowed_when_every_candidate_loses(session, tray)
	_test_victory_beats_post_move_dead_end(session, tray)
	_test_last_piece_uses_real_refill(session, tray)
	_test_artifact_preference_remains_when_both_survive(session, tray)
	await _finish(game)


func _finish(game: Control) -> void:
	if is_instance_valid(game) and game.get_parent() == root:
		root.remove_child(game)
		game.queue_free()
	current_scene = null
	await process_frame
	if _failures.is_empty():
		print("M2_3C_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_surviving_move_beats_higher_scoring_loss(session: GameSession, tray: PieceTray) -> void:
	var domino := load("res://resources/pieces/domino_vertical.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var completed := _fragment(&"complete_now", [Vector2i(3, 0)])
	var remaining := _fragment(&"later", [Vector2i(4, 2)])
	_setup(
		session,
		tray,
		[Vector2i(3, 0), Vector2i(4, 2)],
		[completed, remaining],
		[domino, square, null],
		_dense_board_cells()
	)
	var losing_candidate := session._evaluate_hint_candidate(0, domino, Vector2i.ZERO)
	var hint := session.find_best_hint()
	_expect(losing_candidate.completed_fragments == 1, "A: losing candidate should complete a fragment")
	_expect(losing_candidate.immediate_loss and not losing_candidate.survives, "A: completed immediate transition should classify the candidate as a loss")
	_expect(hint.survives and not hint.immediate_loss, "A: Hint should choose a candidate where play continues")
	_expect(losing_candidate.value > hint.value, "A: safety class must override the larger artifact-oriented numeric score")


func _test_best_loss_is_allowed_when_every_candidate_loses(session: GameSession, tray: PieceTray) -> void:
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var fragment := _fragment(&"unreached", [Vector2i(4, 4)])
	_setup(
		session,
		tray,
		[Vector2i(4, 4)],
		[fragment],
		[square, square, null],
		_dense_board_cells(
			[Vector2i(0, 0)],
			[Vector2i(7, 0), Vector2i(0, 7), Vector2i(1, 7)]
		)
	)
	var legal_candidates := 0
	var surviving_candidates := 0
	for slot_index in tray.get_active_slot_indices():
		for y in BoardModel.HEIGHT:
			for x in BoardModel.WIDTH:
				var origin := Vector2i(x, y)
				if not session.board_model.can_place(square.cells, origin):
					continue
				legal_candidates += 1
				if session._evaluate_hint_candidate(slot_index, square, origin).survives:
					surviving_candidates += 1
	var hint := session.find_best_hint()
	_expect(legal_candidates > 0 and surviving_candidates == 0, "B: every legal scenario candidate should immediately lose")
	_expect(hint.immediate_loss and not hint.completes_expedition, "B: Hint may return the best scored loss when no surviving candidate exists")


func _test_victory_beats_post_move_dead_end(session: GameSession, tray: PieceTray) -> void:
	var domino := load("res://resources/pieces/domino_vertical.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var last_fragment := _fragment(&"last", [Vector2i(3, 0)])
	_setup(
		session,
		tray,
		[Vector2i(3, 0)],
		[last_fragment],
		[domino, square, null],
		_dense_board_cells()
	)
	var winning_candidate := session._evaluate_hint_candidate(0, domino, Vector2i.ZERO)
	var hint := session.find_best_hint()
	_expect(winning_candidate.completes_expedition, "C: candidate should complete the expedition")
	_expect(not winning_candidate.survives and not winning_candidate.immediate_loss, "C: victory may have no next placement but must not be classified as loss")
	_expect(hint.completes_expedition and hint.slot_index == 0 and hint.origin == Vector2i.ZERO, "C: immediate victory should outrank surviving ordinary candidates")


func _test_last_piece_uses_real_refill(session: GameSession, tray: PieceTray) -> void:
	var fragment := _fragment(&"future", [Vector2i(7, 7)])
	_setup(
		session,
		tray,
		[Vector2i(7, 7)],
		[fragment],
		[_single, null, null],
		[]
	)
	var sequence_position := session.piece_sequence.capture_position()
	var expected_refill := session.piece_sequence.peek_next_set()
	var quality := session._evaluate_hint_candidate(0, _single, Vector2i(3, 3))
	_expect(quality.used_refill and quality.post_move_piece_count == 3, "D: final tray piece should evaluate the immediate three-piece refill")
	_expect(quality.survives and not quality.immediate_loss, "D: survival should be based on legal placements in the refill")
	_expect(session.piece_sequence.capture_position() == sequence_position, "D: evaluating Hint must not consume the real sequence")
	_expect(session.try_place_piece(0, Vector2i(3, 3)), "D: final test piece should place")
	_expect(_tray_ids(tray) == _definition_ids(expected_refill), "D: actual refill should match the set used by candidate classification")


func _test_artifact_preference_remains_when_both_survive(session: GameSession, tray: PieceTray) -> void:
	var fragment := _fragment(&"target", [Vector2i(3, 1), Vector2i(4, 2)])
	_setup(
		session,
		tray,
		[Vector2i(3, 1), Vector2i(4, 2)],
		[fragment],
		[_single, _single, null],
		_two_almost_full_rows()
	)
	var irrelevant := session._evaluate_hint_candidate(0, _single, Vector2i(7, 0))
	var artifact := session._evaluate_hint_candidate(0, _single, Vector2i(7, 1))
	var hint := session.find_best_hint()
	_expect(irrelevant.survives and artifact.survives, "E: both comparison candidates should survive")
	_expect(hint.origin == Vector2i(7, 1) and hint.artifact_hits == 1, "E: M2.3B artifact preference should remain within the surviving class")


func _setup(
	session: GameSession,
	tray: PieceTray,
	normal_cells: Array,
	fragments: Array,
	pieces: Array,
	occupied: Array[Vector2i]
) -> void:
	session.expedition_definition = _expedition(normal_cells, fragments)
	_expect(session.restart_expedition(), "Scenario expedition should validate and restart")
	var typed_pieces: Array[PieceDefinition] = []
	typed_pieces.assign(pieces)
	tray.load_set(typed_pieces)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	for cell in occupied:
		session.board_model.place(single_shape, cell, Color.DARK_GREEN)


func _dense_board_cells(
	removed_gaps: Array[Vector2i] = [],
	added_gaps: Array[Vector2i] = []
) -> Array[Vector2i]:
	var gaps: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(7, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(7, 2),
		Vector2i(2, 3), Vector2i(7, 3),
		Vector2i(3, 4), Vector2i(7, 4),
		Vector2i(4, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(6, 7), Vector2i(7, 7),
	]
	for gap in removed_gaps:
		gaps.erase(gap)
	for gap in added_gaps:
		if not gaps.has(gap):
			gaps.append(gap)
	var occupied: Array[Vector2i] = []
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				occupied.append(cell)
	return occupied


func _two_almost_full_rows() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in [0, 1]:
		for x in range(7):
			cells.append(Vector2i(x, y))
	return cells


func _definition_ids(definitions: Array[PieceDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in definitions:
		ids.append(definition.id)
	return ids


func _tray_ids(tray: PieceTray) -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot_index in tray.get_active_slot_indices():
		ids.append(tray.get_definition(slot_index).id)
	return ids
