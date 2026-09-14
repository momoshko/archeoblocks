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
	await _test_board_scene_geometry()
	await _test_representative_game_screens()
	if _failures.is_empty():
		print("M2_8A_BOARD_GEOMETRY_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_board_scene_geometry() -> void:
	var board := load("res://scenes/game/board_view.tscn").instantiate() as BoardView
	root.add_child(board)
	await process_frame
	await process_frame
	_assert_centered(board, "standalone BoardView")
	var first := board.get_cell_view(Vector2i.ZERO)
	var last := board.get_cell_view(Vector2i(7, 7))
	var board_center := board.get_global_rect().get_center()
	var cells_center := (first.get_global_rect().get_center() + last.get_global_rect().get_center()) * 0.5
	_expect(cells_center.distance_to(board_center) <= 0.75, "Opposite cell centers should be symmetric around the board frame center")
	_expect(board.global_position_to_cell(first.get_global_rect().get_center()) == Vector2i.ZERO, "Centered geometry should preserve pointer mapping for the first cell")
	_expect(board.global_position_to_cell(last.get_global_rect().get_center()) == Vector2i(7, 7), "Centered geometry should preserve pointer mapping for the last cell")
	board.show_hint_cells([Vector2i(3, 4)])
	board.show_placement_preview([Vector2i(3, 4)], true, Color.GREEN)
	board.set_stone_obstacle(Vector2i(3, 4), 2)
	var cell := board.get_cell_view(Vector2i(3, 4))
	_expect(_rect_matches(cell.hint_ghost.get_global_rect(), cell.get_global_rect()), "Hint ghost should use the centered cell rect")
	_expect(_rect_matches(cell.valid_preview.get_global_rect(), cell.get_global_rect()), "Placement preview should use the centered cell rect")
	_expect(_rect_matches(cell.stone_obstacle.get_global_rect(), cell.get_global_rect()), "Stone should use the centered cell rect")
	_expect(cell.artifact_target_border.get_global_rect().get_center().distance_to(cell.get_global_rect().get_center()) <= 0.5, "Artifact marker should remain centered on its CellView")
	board.queue_free()
	await process_frame


func _test_representative_game_screens() -> void:
	for scene_path in ["res://scenes/screens/game_screen.tscn", "res://scenes/screens/game_screen_ch2_03.tscn"]:
		var game := load(scene_path).instantiate() as Control
		root.add_child(game)
		await process_frame
		await process_frame
		var board := game.get_node("GameSession").board_view as BoardView
		_assert_centered(board, scene_path)
		var hint := (game.get_node("GameSession") as GameSession).find_best_hint()
		_expect(not hint.is_empty(), "Representative game should retain a legal Hint after board centering")
		for hinted_cell in hint.cells:
			var cell := board.get_cell_view(hinted_cell)
			_expect(cell != null and cell.get_global_rect().intersects(board.get_global_rect()), "Hint cell should remain inside the centered board content")
		game.queue_free()
		await process_frame


func _assert_centered(board: BoardView, context: String) -> void:
	var grid := board.grid
	var board_rect := board.get_global_rect()
	var grid_rect := grid.get_global_rect()
	var left := grid_rect.position.x - board_rect.position.x
	var right := board_rect.end.x - grid_rect.end.x
	var top := grid_rect.position.y - board_rect.position.y
	var bottom := board_rect.end.y - grid_rect.end.y
	_expect(absf(left - right) <= 1.0, "%s should have balanced left/right padding" % context)
	_expect(absf(top - bottom) <= 1.0, "%s should have balanced top/bottom padding" % context)
	var cell_size := board.get_cell_draw_size()
	var step := board.get_cell_step()
	var expected_size := Vector2(
		cell_size.x * BoardView.BOARD_WIDTH + (step.x - cell_size.x) * (BoardView.BOARD_WIDTH - 1),
		cell_size.y * BoardView.BOARD_HEIGHT + (step.y - cell_size.y) * (BoardView.BOARD_HEIGHT - 1)
	)
	_expect(grid.size.distance_to(expected_size) <= 0.75, "%s grid size should derive from cells and spacing" % context)


func _rect_matches(first: Rect2, second: Rect2) -> bool:
	return first.position.distance_to(second.position) <= 0.5 and first.size.distance_to(second.size) <= 0.5
