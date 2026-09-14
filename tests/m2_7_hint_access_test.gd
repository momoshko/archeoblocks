extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_7_hint_progress.cfg"
const PROTOTYPE_RESOURCE := "res://resources/expeditions/ruined_shrine_prototype_01.tres"

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
	await _test_prototype_access()
	await _test_hint_obstacle_simulation()
	await _test_immediate_loss_safety_with_stone()
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_7_HINT_ACCESS_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_prototype_access() -> void:
	var selector := load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	var button := selector.get_node("ContentCenter/PortraitContent/Layout/ChapterList/ChapterTwoButton") as Button
	_expect(button.visible and button.disabled, "Chapter II should remain locked before Chapter I completion")
	var chapter := selector.chapter_one_definition as ChapterDefinition
	for expedition in chapter.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	selector.refresh_progress()
	_expect(not button.disabled and button.text.contains("Разрушенное святилище"), "Chapter II root card should unlock after Chapter I reaches 6/6")
	selector.queue_free()
	await process_frame


func _test_hint_obstacle_simulation() -> void:
	var game := load("res://scenes/screens/game_screen_stone_prototype.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var hint := session.find_best_hint()
	_expect(not hint.is_empty(), "Prototype should provide a legal Hint")
	for cell in hint.cells:
		_expect(not session.obstacle_model.has_obstacle(cell), "Hint must never suggest overlap with Stone")

	var small_t := load("res://resources/pieces/small_t.tres") as PieceDefinition
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var pieces: Array[PieceDefinition] = [small_t, single, single]
	session.piece_tray.load_set(pieces)
	session.board_model.reset()
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	for x in [0, 1, 2, 3, 4, 7]:
		session.board_model.place(one_cell, Vector2i(x, 3), Color.DARK_GREEN)
	for y in [0, 1, 4, 5, 6, 7]:
		session.board_model.place(one_cell, Vector2i(6, y), Color.DARK_GREEN)
	var quality := session._evaluate_hint_candidate(0, small_t, Vector2i(4, 2))
	_expect(quality.obstacle_hits == 1 and quality.obstacles_destroyed == 1, "Hint simulation should predict Stone destruction")
	_expect(quality.artifact_hits == 1 and quality.excavation_hits >= 1, "Hint simulation should pass the second intersection hit into the artifact soil")
	_expect(quality.score_components.obstacle_damage == session.help_config.hint_obstacle_damage_weight, "Hint should expose the tunable obstacle-damage component")
	_expect(quality.score_components.obstacles_destroyed == session.help_config.hint_obstacle_destroyed_weight, "Hint should expose the tunable Stone-destruction component")
	var invalid_quality := session._evaluate_hint_candidate(1, single, Vector2i(6, 3))
	_expect(invalid_quality.get("invalid", false), "Direct candidate simulation should reject overlap with Stone")
	var horizontal_domino := load("res://resources/pieces/domino_horizontal.tres") as PieceDefinition
	session.board_model.reset()
	session.obstacle_model.reset()
	var open_pair := [Vector2i(6, 7), Vector2i(7, 7)]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not open_pair.has(cell):
				session.board_model.place(one_cell, cell, Color.DARK_GREEN)
	session.obstacle_model.set_obstacle(Vector2i(6, 7), 1)
	var remaining: Array[PieceDefinition] = [horizontal_domino]
	_expect(session._is_no_moves_state(session.board_model, remaining, session.obstacle_model), "NO_MOVES should count Stone as occupied placement space")
	var no_moves_tray: Array[PieceDefinition] = [horizontal_domino, null, null]
	session.piece_tray.load_set(no_moves_tray)
	session.evaluate_play_state()
	_expect(session.is_no_moves_state() and session.result_popup.visible, "Stone-constrained NO_MOVES should use the normal rescue/loss flow")
	session.obstacle_model.reset()
	_expect(not session._is_no_moves_state(session.board_model, remaining, session.obstacle_model), "Removing Stone should restore the legal adjacent placement")
	game.queue_free()
	await process_frame


func _test_immediate_loss_safety_with_stone() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var domino := load("res://resources/pieces/domino_vertical.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var definition := _safety_expedition()
	session.expedition_definition = definition
	_expect(session.restart_expedition(), "Obstacle safety fixture should restart")
	var pieces: Array[PieceDefinition] = [domino, square, null]
	session.piece_tray.load_set(pieces)
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	for cell in _dense_board_cells():
		session.board_model.place(one_cell, cell, Color.DARK_GREEN)
	var comparison_found := false
	for stone_cell in _dense_board_gaps():
		session.obstacle_model.reset()
		session.obstacle_model.set_obstacle(stone_cell, 1)
		var has_loss := false
		var has_survivor := false
		for slot_index in session.piece_tray.get_active_slot_indices():
			var piece := session.piece_tray.get_definition(slot_index)
			for y in BoardModel.HEIGHT:
				for x in BoardModel.WIDTH:
					var origin := Vector2i(x, y)
					if not session.obstacle_model.can_place(session.board_model, piece.cells, origin):
						continue
					var quality := session._evaluate_hint_candidate(slot_index, piece, origin)
					has_loss = has_loss or bool(quality.immediate_loss)
					has_survivor = has_survivor or bool(quality.survives)
		if has_loss and has_survivor:
			comparison_found = true
			break
	var hint := session.find_best_hint()
	_expect(comparison_found and session.obstacle_model.occupied_count() == 1, "Safety fixture should contain both survival classes with real Stone occupancy")
	_expect(hint.survives and not hint.immediate_loss, "Explicit survival class should beat every immediate-loss candidate with obstacles")
	game.queue_free()
	await process_frame


func _safety_expedition() -> ExpeditionDefinition:
	var definition := ExpeditionDefinition.new()
	definition.id = &"m2_7_safety"
	definition.title_ru = "Stone safety"
	definition.artifact_id = &"test"
	definition.artifact_name_ru = "Test"
	definition.normal_soil_cells.assign([Vector2i(3, 0), Vector2i(4, 2)])
	var first := ArtifactFragmentDefinition.new()
	first.id = &"first"
	first.cells.assign([Vector2i(3, 0)])
	var second := ArtifactFragmentDefinition.new()
	second.id = &"second"
	second.cells.assign([Vector2i(4, 2)])
	definition.artifact_fragments.assign([first, second])
	var stone := StoneObstacleDefinition.new()
	stone.cell = Vector2i(6, 7)
	stone.durability = 1
	definition.stone_obstacles.assign([stone])
	return definition


func _dense_board_cells() -> Array[Vector2i]:
	var gaps := _dense_board_gaps()
	var occupied: Array[Vector2i] = []
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not gaps.has(cell):
				occupied.append(cell)
	return occupied


func _dense_board_gaps() -> Array[Vector2i]:
	return [
		Vector2i(0, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(7, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(7, 2),
		Vector2i(2, 3), Vector2i(7, 3),
		Vector2i(3, 4), Vector2i(7, 4),
		Vector2i(4, 5), Vector2i(7, 5),
		Vector2i(5, 6), Vector2i(7, 6),
		Vector2i(6, 7), Vector2i(7, 7),
	]


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
