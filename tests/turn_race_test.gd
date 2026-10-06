extends SceneTree

# Regression: Undo, Hint and Restart pressed while a turn is still animating
# must not let the suspended turn mutate the restored or restarted state.

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _expedition() -> ExpeditionDefinition:
	var fragment := ArtifactFragmentDefinition.new()
	fragment.id = &"a"
	fragment.cells.assign([Vector2i(7, 0)])
	var other := ArtifactFragmentDefinition.new()
	other.id = &"b"
	other.cells.assign([Vector2i(0, 7)])
	var definition := ExpeditionDefinition.new()
	definition.id = &"turn_race_test"
	definition.title_ru = "Тест гонки"
	definition.artifact_name_ru = "Тест"
	definition.normal_soil_cells.assign([Vector2i(7, 0), Vector2i(0, 7)])
	definition.artifact_fragments = [fragment, other] as Array[ArtifactFragmentDefinition]
	return definition


func _new_game() -> Control:
	var game := load("res://scenes/screens/game_screen_02.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	return game


func _prepare_line(session: GameSession, tray: PieceTray, board: BoardView) -> void:
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	session.expedition_definition = _expedition()
	session.restart_expedition()
	tray.load_set([single, single, single] as Array[PieceDefinition])
	var shape: Array[Vector2i] = [Vector2i.ZERO]
	var filled: Array[Vector2i] = []
	for x in 7:
		session.board_model.place(shape, Vector2i(x, 0), Color.DARK_GREEN)
		filled.append(Vector2i(x, 0))
	board.set_cells_occupied(filled, Color.DARK_GREEN)


func _run() -> void:
	var game := await _new_game()
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var wait := board.clear_feedback_duration + 1.6

	# A: Undo and Hint are refused while the line-clear animation runs.
	_prepare_line(session, tray, board)
	_expect(session.try_place_piece(1, Vector2i(3, 3)), "A: first move places")
	await create_timer(wait).timeout
	_expect(session.has_turn_snapshot(), "A: first move leaves an undo snapshot")
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "A: line move places")
	_expect(session.is_turn_resolving(), "A: turn is resolving during the animation")
	_expect(session.undo_button.disabled, "A: Undo button is disabled while the turn resolves")
	_expect(session.hint_button.disabled, "A: Hint button is disabled while the turn resolves")
	_expect(not session.request_undo(), "A: Undo is refused while the turn resolves")
	_expect(not session.request_hint(), "A: Hint is refused while the turn resolves")
	await create_timer(wait).timeout
	_expect(not session.is_turn_resolving(), "A: turn finishes")
	_expect(session.moves == 2, "A: both moves counted once")
	_expect(session.excavation_model.is_fragment_collected(&"a"), "A: line excavates the fragment")
	_expect(not tray.is_slot_available(0) and not tray.is_slot_available(1), "A: used slots are consumed")
	_expect(not session.undo_button.disabled, "A: Undo is available again after the turn")

	# B: Restart in the middle of the animation leaves a clean new attempt.
	_prepare_line(session, tray, board)
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "B: line move places")
	_expect(session.is_turn_resolving(), "B: turn is resolving")
	session.restart_expedition()
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	tray.load_set([single, single, single] as Array[PieceDefinition])
	await create_timer(wait).timeout
	_expect(session.board_model.occupied_count() == 0, "B: suspended turn must not touch the restarted board")
	_expect(session.moves == 0 and session.score == 0, "B: restarted counters stay at zero")
	_expect(session.excavation_model.get_soil_depth(Vector2i(7, 0)) == 1, "B: restarted soil stays intact")
	_expect(tray.is_slot_available(0) and tray.is_slot_available(1) and tray.is_slot_available(2), "B: restarted tray keeps all pieces")
	_expect(not session.is_turn_resolving(), "B: restarted session is interactive")

	root.remove_child(game)
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TURN_RACE_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
