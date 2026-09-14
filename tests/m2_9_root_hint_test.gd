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
	var game := load("res://scenes/screens/game_screen_ch3_prototype_01.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var definition := session.piece_tray.get_definition(0)
	var ordinary := session._evaluate_hint_candidate(0, definition, Vector2i(0, 0))
	_expect(ordinary.root_new_growth and not ordinary.root_growth_prevented, "Hint simulation should include unopposed warned growth")
	_expect(ordinary.score_components.root_new_growth == -session.help_config.hint_root_new_growth_penalty, "New growth should use tunable negative weight")
	var blocks_warning := session._evaluate_hint_candidate(0, definition, Vector2i(2, 1))
	_expect(blocks_warning.root_growth_prevented and not blocks_warning.root_new_growth, "Hint should model a piece blocking the warned cell")
	_expect(blocks_warning.score_components.root_growth_prevented == session.help_config.hint_root_growth_prevented_weight, "Blocked growth should use tunable positive weight")

	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var domino := load("res://resources/pieces/domino_horizontal.tres") as PieceDefinition
	session.board_model.reset()
	session.obstacle_model.reset()
	session.obstacle_model.set_root(Vector2i(1, 1))
	session._update_root_threat()
	var holes: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(2, 1), Vector2i(4, 2), Vector2i(6, 3),
		Vector2i(4, 4), Vector2i(5, 4), Vector2i(1, 5), Vector2i(3, 6), Vector2i(7, 7),
	]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not holes.has(cell) and not session.obstacle_model.has_obstacle(cell):
				session.board_model.place([Vector2i.ZERO], cell, Color.WHITE)
	var tray_state: Array[PieceDefinition] = [single, domino, null]
	session.piece_tray.restore_state(tray_state)
	var losing_progress := session._evaluate_hint_candidate(0, single, Vector2i(4, 4))
	_expect(losing_progress.root_new_growth and losing_progress.immediate_loss, "Candidate should be classified from post-growth NO_MOVES state")
	var safe_hint := session.find_best_hint()
	_expect(not safe_hint.is_empty() and safe_hint.survives, "Hint should choose a surviving candidate when post-growth loss alternative exists")
	_expect(session._hint_candidate_priority(safe_hint) > session._hint_candidate_priority(losing_progress), "Explicit safety priority should outrank post-growth losing score")

	session.restart_expedition()
	session.board_model.reset()
	session.obstacle_model.reset()
	session.obstacle_model.set_root(Vector2i(7, 0))
	for x in 6:
		session.board_model.place([Vector2i.ZERO], Vector2i(x, 0), Color.WHITE)
	session._update_root_threat()
	var cuts_root := session._evaluate_hint_candidate(0, single, Vector2i(6, 0))
	_expect(cuts_root.roots_destroyed == 1 and not cuts_root.root_new_growth, "Hint should model Root destruction and growth suppression")
	_expect(cuts_root.score_components.root_damage == session.help_config.hint_root_damage_weight, "Root damage weight should be explicit")
	_expect(cuts_root.score_components.roots_destroyed == session.help_config.hint_root_destroyed_weight, "Root destruction weight should be explicit")

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("M2_9_ROOT_HINT_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
