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
	await _test_hint_models_both_durabilities()
	await _test_hint_and_no_moves_use_obstacle_occupancy()
	if _failures.is_empty():
		print("M2_8_HINT_NO_MOVES_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_hint_models_both_durabilities() -> void:
	var game := load("res://scenes/screens/game_screen_ch2_03.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var pieces: Array[PieceDefinition] = [single, null, null]
	session.piece_tray.load_set(pieces)
	session.board_model.reset()
	session.obstacle_model.reset()
	var stone_cell := Vector2i(6, 3)
	var placement_cell := Vector2i(7, 3)
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	for x in range(7):
		if x != stone_cell.x:
			session.board_model.place(one_cell, Vector2i(x, 3), Color.DARK_GREEN)

	session.obstacle_model.set_obstacle(stone_cell, 2)
	var reinforced := session._evaluate_hint_candidate(0, single, placement_cell)
	_expect(reinforced.obstacle_hits == 1 and reinforced.obstacles_destroyed == 0, "Hint should model a 2-to-1 reinforced Stone hit")
	_expect(reinforced.score_components.obstacle_damage == session.help_config.hint_obstacle_damage_weight, "Reinforced damage should use the existing obstacle-damage weight")

	session.obstacle_model.reset()
	session.obstacle_model.set_obstacle(stone_cell, 1)
	var cracked := session._evaluate_hint_candidate(0, single, placement_cell)
	_expect(cracked.obstacle_hits == 1 and cracked.obstacles_destroyed == 1, "Hint should model durability-1 Stone destruction")
	_expect(cracked.score_components.obstacles_destroyed == session.help_config.hint_obstacle_destroyed_weight, "Stone destruction should use the existing destruction weight")
	game.queue_free()
	await process_frame


func _test_hint_and_no_moves_use_obstacle_occupancy() -> void:
	var game := load("res://scenes/screens/game_screen_ch2_08.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var hint := session.find_best_hint()
	_expect(not hint.is_empty(), "Chapter II finale should have a legal one-step Hint")
	for cell in hint.cells:
		_expect(not session.obstacle_model.has_obstacle(cell), "Hint must never overlap normal or reinforced Stone")

	var domino := load("res://resources/pieces/domino_horizontal.tres") as PieceDefinition
	var board := BoardModel.new()
	var obstacles := ObstacleModel.new()
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	var open_pair := [Vector2i(6, 7), Vector2i(7, 7)]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not open_pair.has(cell):
				board.place(single_shape, cell, Color.DARK_GREEN)
	obstacles.set_obstacle(Vector2i(6, 7), 2)
	var remaining: Array[PieceDefinition] = [domino]
	_expect(session._is_no_moves_state(board, remaining, obstacles), "NO_MOVES should treat reinforced Stone as occupied")
	obstacles.reset()
	_expect(not session._is_no_moves_state(board, remaining, obstacles), "Removing the obstacle should restore the only legal move")
	game.queue_free()
	await process_frame
