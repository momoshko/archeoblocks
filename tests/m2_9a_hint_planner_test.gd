extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	_expect(session.help_config.hint_planning_depth == 5, "Planner depth should be data-driven and default to five")
	_expect(session.help_config.hint_beam_width == 12, "Profiled planner beam width should be data-driven and default to twelve")

	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var domino := load("res://resources/pieces/domino_horizontal.tres") as PieceDefinition
	var open_tray: Array[PieceDefinition] = [single, single, single]
	session.piece_tray.restore_state(open_tray)
	var before_board := session.board_model.capture_state()
	var before_sequence := session.piece_sequence.capture_position()
	var first := session.find_best_hint()
	var second := session.find_best_hint()
	print(
		"M2_9A_PLANNER_TIMING synthetic_open_ms=%.2f repeat_ms=%.2f explored=%d"
		% [first.planning_time_ms, second.planning_time_ms, first.explored_states]
	)
	_expect(not first.is_empty(), "Open board should produce a planned Hint")
	_expect(first.safety_class == "PLAN_SURVIVES", "Reachable planning horizon should receive PLAN_SURVIVES")
	_expect(first.current_tray_possible, "Planner should prove the remaining current tray can be placed sequentially")
	_expect(first.planning_depth_reached == session.help_config.hint_planning_depth, "Planner should report the reached bounded horizon")
	_expect(first.slot_index == second.slot_index and first.origin == second.origin, "Identical state should produce a deterministic recommendation")
	_expect(not first.cache_hit and second.cache_hit, "Repeated evaluation of an unchanged state should reuse the cached recommendation")
	_expect(session.board_model.capture_state() == before_board, "Planning must not mutate the live board")
	_expect(session.piece_sequence.capture_position() == before_sequence, "Planning must not consume the live PieceSequence")

	var state := session._capture_hint_search_state()
	var same_state := state.duplicate(true)
	_expect(session._hint_search_state_key(state) == session._hint_search_state_key(same_state), "Equivalent states should deduplicate to the same key")
	var reordered_tray: Array[PieceDefinition] = [domino, single, single]
	same_state.tray_state = reordered_tray
	_expect(session._hint_search_state_key(state) != session._hint_search_state_key(same_state), "State key should preserve exact tray-slot identities")
	same_state = state.duplicate(true)
	same_state.root_threat_cell = Vector2i(3, 4)
	_expect(session._hint_search_state_key(state) != session._hint_search_state_key(same_state), "State key should preserve pending Root growth")
	_test_current_tray_competition_and_greedy_trap(session, domino)

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("M2_9A_HINT_PLANNER_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_current_tray_competition_and_greedy_trap(
	session: GameSession,
	domino: PieceDefinition
) -> void:
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var shared_square: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	]
	var isolated: Array[Vector2i] = [
		Vector2i(4, 0), Vector2i(6, 1), Vector2i(2, 2), Vector2i(5, 3),
		Vector2i(0, 4), Vector2i(3, 5), Vector2i(1, 6), Vector2i(7, 7),
	]
	var impossible_state := session._capture_hint_search_state()
	var impossible_gaps: Array[Vector2i] = []
	impossible_gaps.append_array(shared_square)
	impossible_gaps.append_array(isolated)
	impossible_state.board_state = _board_with_gaps(impossible_gaps).capture_state()
	var remaining_tray: Array[PieceDefinition] = [null, domino, square]
	impossible_state.tray_state = remaining_tray
	impossible_state.sequence_position = 2
	impossible_state.refill_generation = 0
	impossible_state.no_moves = false
	var impossible_stats := {"explored": 0}
	var impossible := session.hint_planner._can_complete_current_tray(
		session, impossible_state, 1, {}, impossible_stats
	)
	_expect(not impossible, "Competing pieces that only share one 2x2 region must fail sequential tray feasibility")

	var feasible_state := impossible_state.duplicate(true)
	var separate_domino: Array[Vector2i] = [Vector2i(6, 4), Vector2i(7, 4)]
	var feasible_gaps: Array[Vector2i] = []
	feasible_gaps.append_array(impossible_gaps)
	feasible_gaps.append_array(separate_domino)
	feasible_state.board_state = _board_with_gaps(feasible_gaps).capture_state()
	var feasible_stats := {"explored": 0}
	var feasible := session.hint_planner._can_complete_current_tray(
		session, feasible_state, 1, {}, feasible_stats
	)
	_expect(feasible, "Separate square and domino regions should allow the current tray in a legal order")

	var greedy_dead_end := {
		"completes_expedition": false,
		"plan_survives": false,
		"survives": true,
		"current_tray_possible": impossible,
		"best_continuation_value": 900000,
		"value": 900000,
		"slot_index": 0,
		"origin": Vector2i.ZERO,
	}
	var planned_lower_score := {
		"completes_expedition": false,
		"plan_survives": true,
		"survives": true,
		"current_tray_possible": feasible,
		"best_continuation_value": 1,
		"value": 1,
		"slot_index": 1,
		"origin": Vector2i.ONE,
	}
	_expect(
		session.hint_planner._candidate_better(planned_lower_score, greedy_dead_end),
		"Known greedy-trap ordering must choose a viable planned branch over larger immediate artifact score"
	)


func _board_with_gaps(gaps: Array[Vector2i]) -> BoardModel:
	var board := BoardModel.new()
	var single_cell: Array[Vector2i] = [Vector2i.ZERO]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				board.place(single_cell, cell, Color.WHITE)
	return board
