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


func _expedition(
	normal_cells: Array,
	strong_cells: Array,
	fragments: Array
) -> ExpeditionDefinition:
	var definition := ExpeditionDefinition.new()
	definition.id = &"m2_3b_test"
	definition.title_ru = "Тест M2.3B"
	definition.debug_name = "M2.3B Test"
	definition.artifact_id = &"test_artifact"
	definition.artifact_name_ru = "Тестовая находка"
	definition.normal_soil_cells.assign(normal_cells)
	definition.strong_soil_cells.assign(strong_cells)
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
	_expect(session != null and tray != null, "GameScreen should instantiate the Hint test dependencies")
	if session == null or tray == null:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	_single = load("res://resources/pieces/single.tres") as PieceDefinition

	_test_artifact_progress_beats_irrelevant_line(session, tray)
	_test_fragment_completion_beats_general_excavation(session, tray)
	_test_immediate_victory_is_absolute(session, tray)
	_test_catastrophic_playability_is_avoided(session, tray)
	_test_intersection_applies_two_hits_and_rules_stay_valid(session, tray)

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame
	if _failures.is_empty():
		print("M2_3B_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_artifact_progress_beats_irrelevant_line(session: GameSession, tray: PieceTray) -> void:
	var target_fragment := _fragment(&"target", [Vector2i(3, 1), Vector2i(4, 2)])
	_setup(
		session,
		tray,
		[Vector2i(3, 1), Vector2i(4, 2)],
		[],
		[target_fragment],
		[_single, null, null],
		_two_almost_full_rows()
	)
	var hint := session.find_best_hint()
	_expect(hint.origin == Vector2i(7, 1), "A: artifact-progress line should beat an equally available irrelevant line")
	_expect(hint.artifact_hits == 1 and hint.completed_fragments == 0, "A: chosen move should apply one artifact hit without completing the fragment")
	_expect(hint.line_count == 1, "A: chosen artifact move should evaluate its cleared row")


func _test_fragment_completion_beats_general_excavation(session: GameSession, tray: PieceTray) -> void:
	var general_soil: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		general_soil.append(Vector2i(x, 0))
	general_soil.append_array([Vector2i(3, 1), Vector2i(4, 2)])
	var completed_fragment := _fragment(&"complete_now", [Vector2i(3, 1)])
	var remaining_fragment := _fragment(&"later", [Vector2i(4, 2)])
	_setup(
		session,
		tray,
		general_soil,
		[],
		[completed_fragment, remaining_fragment],
		[_single, null, null],
		_two_almost_full_rows()
	)
	var hint := session.find_best_hint()
	_expect(hint.origin == Vector2i(7, 1), "B: completing a fragment should beat excavating an unrelated soil row")
	_expect(hint.completed_fragments == 1, "B: candidate simulation should detect the newly completed fragment")
	_expect(not hint.completes_expedition, "B: completing one of two fragments must not be mistaken for victory")


func _test_immediate_victory_is_absolute(session: GameSession, tray: PieceTray) -> void:
	var general_soil: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		general_soil.append(Vector2i(x, 0))
	general_soil.append(Vector2i(3, 1))
	var last_fragment := _fragment(&"last", [Vector2i(3, 1)])
	_setup(
		session,
		tray,
		general_soil,
		[],
		[last_fragment],
		[_single, null, null],
		_two_almost_full_rows()
	)
	var hint := session.find_best_hint()
	_expect(hint.origin == Vector2i(7, 1), "C: immediate expedition-winning move should be selected")
	_expect(hint.completes_expedition and hint.completed_fragments == 1, "C: Hint result should explicitly report victory")
	_expect(hint.score_components.victory == session.help_config.hint_expedition_victory_bonus, "C: victory component should use the named configured bonus")


func _test_catastrophic_playability_is_avoided(session: GameSession, tray: PieceTray) -> void:
	var domino := load("res://resources/pieces/domino_vertical.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var fragment := _fragment(&"small_progress", [Vector2i(3, 0), Vector2i(4, 2)])
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
	var occupied: Array[Vector2i] = []
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				occupied.append(cell)
	_setup(
		session,
		tray,
		[Vector2i(3, 0), Vector2i(4, 2)],
		[],
		[fragment],
		[domino, square, null],
		occupied
	)
	var catastrophic := session._evaluate_hint_candidate(0, domino, Vector2i(0, 0))
	var hint := session.find_best_hint()
	_expect(catastrophic.artifact_hits == 1, "D: precondition should offer a small artifact gain; got %s" % catastrophic)
	_expect(catastrophic.blocked_remaining_pieces == 1, "D: precondition should strand the remaining square; got %s" % catastrophic)
	_expect(hint.blocked_remaining_pieces == 0, "D: Hint should preserve a legal move for the remaining piece")
	_expect(not (hint.slot_index == 0 and hint.origin == Vector2i(0, 0)), "D: negligible progress must not force the catastrophic candidate")


func _test_intersection_applies_two_hits_and_rules_stay_valid(session: GameSession, tray: PieceTray) -> void:
	var fragment := _fragment(&"intersection", [Vector2i.ZERO])
	var occupied: Array[Vector2i] = []
	for x in range(1, BoardModel.WIDTH):
		occupied.append(Vector2i(x, 0))
	for y in range(1, BoardModel.HEIGHT):
		occupied.append(Vector2i(0, y))
	_setup(
		session,
		tray,
		[],
		[Vector2i.ZERO],
		[fragment],
		[_single, null, null],
		occupied
	)
	var quality := session._evaluate_hint_candidate(0, _single, Vector2i.ZERO)
	var hint := session.find_best_hint()
	_expect(quality.line_count == 2, "E: row and column should both be detected")
	_expect(quality.excavation_hits == 2 and quality.artifact_hits == 2, "E: strong-soil intersection should receive two actual excavation hits")
	_expect(quality.completed_fragments == 1 and quality.completes_expedition, "E: double hit should complete the strong artifact target")
	_expect(hint.origin == Vector2i.ZERO, "E: Hint should choose the legal double-line victory")
	_expect(session.board_model.can_place(_single.cells, Vector2i.ZERO), "E: valid placement rule should remain accepted")
	_expect(not session.board_model.can_place(_single.cells, Vector2i(1, 0)), "E: occupied overlap should remain invalid")
	_expect(not session.board_model.can_place(_single.cells, Vector2i(-1, 0)), "E: out-of-bounds placement should remain invalid")


func _setup(
	session: GameSession,
	tray: PieceTray,
	normal_cells: Array,
	strong_cells: Array,
	fragments: Array,
	pieces: Array,
	occupied: Array[Vector2i]
) -> void:
	session.expedition_definition = _expedition(normal_cells, strong_cells, fragments)
	_expect(session.restart_expedition(), "Scenario expedition should validate and restart")
	var typed_pieces: Array[PieceDefinition] = []
	typed_pieces.assign(pieces)
	tray.load_set(typed_pieces)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	for cell in occupied:
		session.board_model.place(single_shape, cell, Color.DARK_GREEN)


func _two_almost_full_rows() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in [0, 1]:
		for x in range(7):
			cells.append(Vector2i(x, y))
	return cells
