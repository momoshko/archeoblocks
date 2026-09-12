extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _fill_row(model: BoardModel, y: int) -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	for x in BoardModel.WIDTH:
		model.place(single, Vector2i(x, y), &"test")


func _fill_column(model: BoardModel, x: int) -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	for y in BoardModel.HEIGHT:
		if model.is_empty(Vector2i(x, y)):
			model.place(single, Vector2i(x, y), &"test")


func _run() -> void:
	_test_board_model()
	await _test_tray_and_session()
	await _test_session_line_clear()
	await _test_pointer_input()
	await _test_responsive_input()
	await _test_board_transform()
	if _failures.is_empty():
		print("M1_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_board_model() -> void:
	var single: Array[Vector2i] = [Vector2i.ZERO]
	var domino: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var small_l: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var model := BoardModel.new()

	_expect(model.can_place(small_l, Vector2i(0, 0)), "Empty board should accept a legal piece")
	_expect(not model.can_place(domino, Vector2i(7, 0)), "Out-of-bounds placement should be rejected")
	_expect(not model.can_place(single, Vector2i(-1, 0)), "Negative placement should be rejected")
	model.place(single, Vector2i(0, 0), &"occupied")
	_expect(not model.can_place(single, Vector2i(0, 0)), "Occupied overlap should be rejected")

	model.reset()
	_fill_row(model, 3)
	_expect(model.get_full_rows() == [3], "A horizontal full row should be detected")

	model.reset()
	_fill_column(model, 4)
	_expect(model.get_full_columns() == [4], "A vertical full column should be detected")

	model.reset()
	_fill_row(model, 4)
	_fill_column(model, 5)
	_expect(model.get_full_rows() == [4] and model.get_full_columns() == [5], "Simultaneous row and column should be detected")
	var one_row: Array[int] = [4]
	var one_column: Array[int] = [5]
	var cleared := model.clear_lines(one_row, one_column)
	_expect(cleared.size() == 15 and model.occupied_count() == 0, "Row and column intersection should clear once")

	model.reset()
	_fill_row(model, 1)
	_fill_row(model, 2)
	_expect(model.get_full_rows() == [1, 2], "Multiple full rows should be detected")
	var two_rows: Array[int] = [1, 2]
	var no_columns: Array[int] = []
	model.clear_lines(two_rows, no_columns)
	_expect(model.occupied_count() == 0, "Multiple lines should clear in one action")

	model.reset()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if Vector2i(x, y) != Vector2i(7, 7):
				model.place(single, Vector2i(x, y), &"filled")
	_expect(not model.has_legal_placement(small_l), "No-move detection should reject a piece with no legal origin")


func _test_tray_and_session() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray

	_expect(session.try_place_piece(0, Vector2i(0, 0)), "First tray piece should place")
	_expect(not tray.is_slot_available(0), "Used PieceSlot should become unavailable")
	_expect(tray.is_slot_available(1) and tray.is_slot_available(2), "Unused pieces should remain available")
	_expect(session.try_place_piece(1, Vector2i(3, 0)), "Second tray piece should place in any order")
	_expect(session.try_place_piece(2, Vector2i(0, 4)), "Third tray piece should place")
	_expect(not tray.all_empty(), "Tray should refill after the third piece")
	_expect(tray.get_definition(0).id == &"square_2", "Tray should advance to deterministic set 2")
	_expect(session.moves == 3, "Moves should count successful placements")
	var single: Array[Vector2i] = [Vector2i.ZERO]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if session.board_model.is_empty(Vector2i(x, y)):
				session.board_model.place(single, Vector2i(x, y), &"filled")
	session.refresh_no_moves_state()
	_expect(session.is_no_moves_state(), "GameSession should enter NO_MOVES when no remaining piece fits")

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _test_board_transform() -> void:
	var board := load("res://scenes/game/board_view.tscn").instantiate() as BoardView
	root.add_child(board)
	board.position = Vector2(137.0, 91.0)
	await process_frame
	await process_frame
	var target := Vector2i(3, 4)
	_expect(board.global_position_to_cell(board.get_cell_global_center(target)) == target, "Board coordinate conversion should work after moving BoardView")
	board.position = Vector2(241.0, 166.0)
	await process_frame
	_expect(board.global_position_to_cell(board.get_cell_global_center(target)) == target, "Board coordinate conversion should follow a second transform")
	board.queue_free()


func _test_responsive_input() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var target := Vector2i(6, 2)
	for requested_size in [Vector2i(720, 1280), Vector2i(1920, 1080)]:
		root.size = requested_size
		await process_frame
		await process_frame
		_expect(
			board.global_position_to_cell(board.get_cell_global_center(target)) == target,
			"Board input conversion should survive viewport resize to %s" % requested_size
		)
	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _test_pointer_input() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var mouse_slot := tray.get_child(0) as PieceSlot

	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.position = mouse_slot.get_global_rect().get_center()
	mouse_press.global_position = mouse_press.position
	mouse_slot._gui_input(mouse_press)
	var mouse_target := board.get_cell_global_center(Vector2i(0, 0)) + Vector2(0.0, session.mouse_drag_lift)
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = mouse_target
	mouse_slot._input(mouse_motion)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = mouse_target
	mouse_slot._input(mouse_release)
	_expect(session.moves == 1, "Mouse drag should place a piece")

	var touch_slot := tray.get_child(1) as PieceSlot
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 7
	touch_press.pressed = true
	touch_press.position = touch_slot.get_global_rect().get_center()
	touch_slot._gui_input(touch_press)
	var touch_target := board.get_cell_global_center(Vector2i(4, 3)) + Vector2(0.0, session.touch_drag_lift)
	var touch_motion := InputEventScreenDrag.new()
	touch_motion.index = 7
	touch_motion.position = touch_target
	touch_slot._input(touch_motion)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 7
	touch_release.pressed = false
	touch_release.position = touch_target
	touch_slot._input(touch_release)
	_expect(session.moves == 2, "Touch drag should place a piece with lift")

	var pause_button := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/PauseButton") as Button
	pause_button.pressed.emit()
	var blocked_slot := tray.get_child(2) as PieceSlot
	var blocked_press := InputEventMouseButton.new()
	blocked_press.button_index = MOUSE_BUTTON_LEFT
	blocked_press.pressed = true
	blocked_press.position = blocked_slot.get_global_rect().get_center()
	blocked_slot._gui_input(blocked_press)
	var blocked_release := InputEventMouseButton.new()
	blocked_release.button_index = MOUSE_BUTTON_LEFT
	blocked_release.pressed = false
	blocked_release.position = board.get_cell_global_center(Vector2i(0, 6))
	blocked_slot._input(blocked_release)
	_expect(session.moves == 2, "Pause should block piece placement")

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _test_session_line_clear() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var single_set: Array[PieceDefinition] = [single, single, single]
	tray.load_set(single_set)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	var prefilled: Array[Vector2i] = []
	for x in 7:
		var cell := Vector2i(x, 0)
		session.board_model.place(single_shape, cell, &"prefill")
		prefilled.append(cell)
	board.set_cells_occupied(prefilled, single.cosmetic_color)
	_expect(session.try_place_piece(0, Vector2i(7, 0)), "Completing a row should be a legal session placement")
	await create_timer(board.clear_feedback_duration + 0.05).timeout
	_expect(session.board_model.occupied_count() == 0, "Session should clear the completed row from BoardModel")
	_expect(not board.get_cell_view(Vector2i(7, 0)).block_visual.visible, "Clear feedback should finish with empty CellView visuals")
	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame
