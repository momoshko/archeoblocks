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


func _expedition(
	normal_cells: Array,
	strong_cells: Array,
	fragments: Array[ArtifactFragmentDefinition]
) -> ExpeditionDefinition:
	var definition := ExpeditionDefinition.new()
	definition.id = &"test_expedition"
	definition.title_ru = "Тестовая экспедиция"
	definition.debug_name = "Test Expedition"
	definition.artifact_id = &"test_artifact"
	definition.artifact_name_ru = "Тестовая находка"
	definition.normal_soil_cells.assign(normal_cells)
	definition.strong_soil_cells.assign(strong_cells)
	definition.artifact_fragments = fragments
	return definition


func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in ExcavationModel.HEIGHT:
		for x in ExcavationModel.WIDTH:
			cells.append(Vector2i(x, y))
	return cells


func _run() -> void:
	_test_soil_depths()
	_test_line_hit_maps()
	_test_fragment_completion()
	_test_invalid_definition()
	_test_excavation_does_not_block_placement()
	await _test_cell_view_states()
	await _test_victory_precedence_and_restart()
	await _test_loss_popup()
	if _failures.is_empty():
		print("M2_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_soil_depths() -> void:
	var cell := Vector2i(0, 0)
	var fragment := _fragment(&"fragment", [cell])
	var fragments: Array[ArtifactFragmentDefinition] = [fragment]
	var model := ExcavationModel.new()
	_expect(model.load_expedition(_expedition([cell], [], fragments)).is_empty(), "Valid normal-soil expedition should load")
	_expect(model.get_soil_depth(cell) == 1, "Normal soil should start at depth 1")
	model.dig(cell)
	_expect(model.get_soil_depth(cell) == 0, "Normal soil should dig from 1 to 0")
	model.dig(cell, 4)
	_expect(model.get_soil_depth(cell) == 0, "Soil depth should never go below 0")

	_expect(model.load_expedition(_expedition([cell], [cell], fragments)).is_empty(), "Valid strong-soil expedition should load")
	_expect(model.get_soil_depth(cell) == 2, "Strong soil should start at depth 2")
	model.dig(cell)
	_expect(model.get_soil_depth(cell) == 1, "Strong soil should dig from 2 to 1")
	model.dig(cell)
	_expect(model.get_soil_depth(cell) == 0, "Strong soil should dig from 1 to 0")


func _test_line_hit_maps() -> void:
	var row: Array[int] = [2]
	var column: Array[int] = [3]
	var no_lines: Array[int] = []
	var row_hits := ExcavationModel.build_line_hit_map(row, no_lines)
	_expect(row_hits.size() == 8, "A row clear should target all 8 cells")
	for x in 8:
		_expect(row_hits[Vector2i(x, 2)] == 1, "Each row cell should receive exactly one hit")

	var column_hits := ExcavationModel.build_line_hit_map(no_lines, column)
	_expect(column_hits.size() == 8, "A column clear should target all 8 cells")
	for y in 8:
		_expect(column_hits[Vector2i(3, y)] == 1, "Each column cell should receive exactly one hit")

	var cross_hits := ExcavationModel.build_line_hit_map(row, column)
	_expect(cross_hits[Vector2i(3, 2)] == 2, "Row/column intersection should receive two hits")
	_expect(cross_hits.size() == 15, "A row/column hit map should preserve one intersection cell with count 2")

	var rows: Array[int] = [1, 6]
	var columns: Array[int] = [2, 5]
	var multi_hits := ExcavationModel.build_line_hit_map(rows, columns)
	_expect(multi_hits[Vector2i(2, 1)] == 2, "Every multi-line intersection should receive two hits")
	_expect(multi_hits[Vector2i(5, 6)] == 2, "Second multi-line intersection should receive two hits")
	_expect(multi_hits[Vector2i(0, 1)] == 1, "Non-intersection row cell should receive one hit")

	var all := _all_cells()
	var fragment := _fragment(&"sample", [Vector2i(0, 0)])
	var fragments: Array[ArtifactFragmentDefinition] = [fragment]
	var model := ExcavationModel.new()
	model.load_expedition(_expedition(all, [], fragments))
	var changed := model.apply_hit_map(row_hits)
	_expect(changed.size() == 8, "Applying a row hit map should dig every row cell")
	for x in 8:
		_expect(model.get_soil_depth(Vector2i(x, 2)) == 0, "Row clear should remove one normal-soil layer")
	_expect(model.get_soil_depth(Vector2i(0, 3)) == 1, "Row clear should not dig another row")
	model.load_expedition(_expedition(all, [], fragments))
	model.apply_hit_map(column_hits)
	for y in 8:
		_expect(model.get_soil_depth(Vector2i(3, y)) == 0, "Column clear should remove one normal-soil layer")


func _test_fragment_completion() -> void:
	var a_cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var b_cells: Array[Vector2i] = [Vector2i(5, 5)]
	var fragments: Array[ArtifactFragmentDefinition] = [
		_fragment(&"a", a_cells),
		_fragment(&"b", b_cells)
	]
	var normal := a_cells.duplicate()
	normal.append_array(b_cells)
	var model := ExcavationModel.new()
	model.load_expedition(_expedition(normal, [], fragments))
	model.dig(a_cells[0])
	_expect(not model.fragment_is_complete(&"a"), "Fragment should wait for all of its cells")
	_expect(model.collect_newly_completed_fragments().is_empty(), "Incomplete fragment should not trigger")
	model.dig(a_cells[1])
	_expect(model.fragment_is_complete(&"a"), "Fragment should complete after all cells are uncovered")
	_expect(model.collect_newly_completed_fragments() == [&"a"], "Completed fragment should trigger once")
	_expect(model.collect_newly_completed_fragments().is_empty(), "Collected fragment should not trigger twice")
	_expect(not model.all_fragments_complete(), "One remaining fragment should prevent victory")
	model.dig(b_cells[0])
	_expect(model.collect_newly_completed_fragments() == [&"b"], "Second fragment should collect")
	_expect(model.all_fragments_complete(), "All collected fragments should produce victory state")


func _test_invalid_definition() -> void:
	var duplicate_a := _fragment(&"same", [Vector2i(1, 1)])
	var duplicate_b := _fragment(&"same", [Vector2i(1, 1)])
	var fragments: Array[ArtifactFragmentDefinition] = [duplicate_a, duplicate_b]
	var invalid := _expedition([Vector2i(9, 0)], [Vector2i(-1, 0)], fragments)
	var errors := invalid.validate()
	_expect(not errors.is_empty(), "Invalid ExpeditionDefinition should report validation errors")
	var model := ExcavationModel.new()
	_expect(not model.load_expedition(invalid).is_empty(), "ExcavationModel should reject invalid expedition data")


func _test_excavation_does_not_block_placement() -> void:
	var cell := Vector2i(2, 2)
	var fragments: Array[ArtifactFragmentDefinition] = [_fragment(&"buried", [cell])]
	var excavation := ExcavationModel.new()
	excavation.load_expedition(_expedition([cell], [cell], fragments))
	var board := BoardModel.new()
	var single: Array[Vector2i] = [Vector2i.ZERO]
	_expect(excavation.get_soil_depth(cell) == 2, "Test cell should contain strong soil")
	_expect(board.can_place(single, cell), "Soil and artifact ownership must not block piece placement")


func _test_cell_view_states() -> void:
	var cell := load("res://scenes/game/cell_view.tscn").instantiate() as CellView
	root.add_child(cell)
	await process_frame
	cell.reset_visual_state()
	cell.set_excavation_state(2, true)
	_expect(cell.strong_soil_visual.visible and not cell.soil_visual.visible, "CellView should show StrongSoilVisual at depth 2")
	_expect(cell.artifact_hint.visible, "ArtifactHint should remain visible under soil")
	cell.set_excavation_state(1, true)
	_expect(cell.soil_visual.visible and not cell.strong_soil_visual.visible, "CellView should switch to normal SoilVisual at depth 1")
	cell.set_occupied(Color.GREEN)
	_expect(cell.soil_visual.visible and cell.block_visual.visible, "BlockVisual should coexist above soil")
	cell.set_excavation_state(0, true)
	_expect(not cell.soil_visual.visible and not cell.strong_soil_visual.visible, "Excavated CellView should hide soil")
	_expect(is_equal_approx(cell.artifact_hint.modulate.a, cell.artifact_excavated_alpha), "Excavated artifact hint should become fully readable")
	cell.queue_free()
	await process_frame


func _test_victory_precedence_and_restart() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var popup := game.get_node("ResultPopup") as ResultPopup
	var artifact_cell := Vector2i(7, 0)
	var fragments: Array[ArtifactFragmentDefinition] = [_fragment(&"victory_fragment", [artifact_cell])]
	session.expedition_definition = _expedition([artifact_cell], [], fragments)
	_expect(session.restart_expedition(), "Valid test expedition should restart")
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var test_set: Array[PieceDefinition] = [single, square, square]
	tray.load_set(test_set)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	var occupied: Array[Vector2i] = []
	for x in 7:
		var top_cell := Vector2i(x, 0)
		session.board_model.place(single_shape, top_cell, &"prefill")
		occupied.append(top_cell)
	for y in range(1, 8):
		for x in 8:
			var is_gap := (x % 2) == (0 if y % 2 == 1 else 1)
			if not is_gap:
				var cell := Vector2i(x, y)
				session.board_model.place(single_shape, cell, &"prefill")
				occupied.append(cell)
	board.set_cells_occupied(occupied, Color.DARK_GREEN)
	_expect(session.try_place_piece(0, artifact_cell), "Victory placement should succeed")
	await create_timer(board.clear_feedback_duration + 0.4).timeout
	_expect(session.excavation_model.all_fragments_complete(), "Final excavation should complete the artifact")
	_expect(popup.visible and popup.title_label.text == "ЭКСПЕДИЦИЯ ЗАВЕРШЕНА!", "Victory should open the editor-authored result popup")
	_expect(not session.is_no_moves_state(), "Victory must take precedence over the otherwise blocked square pieces")

	popup.retry_button.pressed.emit()
	await process_frame
	_expect(session.board_model.occupied_count() == 0, "Restart should clear BoardModel")
	_expect(session.excavation_model.get_soil_depth(artifact_cell) == 1, "Restart should restore soil depth")
	_expect(session.excavation_model.collected_fragment_count() == 0, "Restart should reset fragment collection")
	_expect(session.moves == 0, "Restart should reset Moves")
	_expect(not popup.visible and not session.is_no_moves_state(), "Restart should close popup and clear terminal state")
	_expect(tray.get_definition(0).id == &"small_l", "Restart should reset the deterministic tray sequence")
	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _test_loss_popup() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var popup := game.get_node("ResultPopup") as ResultPopup
	var single: Array[Vector2i] = [Vector2i.ZERO]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			session.board_model.place(single, Vector2i(x, y), &"filled")
	session.refresh_no_moves_state()
	_expect(session.is_no_moves_state(), "Filled board should enter NO_MOVES")
	_expect(popup.visible and popup.title_label.text == "РАСКОПКИ ЗАШЛИ В ТУПИК", "NO_MOVES should open rescue mode in ResultPopup")
	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame
