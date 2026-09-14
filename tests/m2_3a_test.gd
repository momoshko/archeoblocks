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
	current_scene = game
	await process_frame
	await process_frame

	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var feedback := game.get_node("FeedbackUI/ActionFeedback") as ActionFeedback
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var singles: Array[PieceDefinition] = [single, single, single]
	tray.load_set(singles)
	session.help_config.hint_display_seconds = 0.25

	await _test_repeated_hint_replaces_presentation(game, session, board, tray, feedback)
	await _test_hint_cancels_stale_drag(session, tray)
	await _test_mouse_touch_and_refill(session, board, tray)
	_test_hint_overlays_ignore_input(board, tray, feedback)

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame

	if _failures.is_empty():
		print("M2_3A_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_repeated_hint_replaces_presentation(
	game: Control,
	session: GameSession,
	board: BoardView,
	tray: PieceTray,
	feedback: ActionFeedback
) -> void:
	var node_count_before := game.find_children("*", "", true, false).size()
	for invocation in 20:
		_expect(session.request_hint(), "Hint invocation %d should succeed in unlimited debug mode" % (invocation + 1))
	await process_frame

	_expect(session.is_debug_unlimited_hints_enabled(), "Unlimited Hint debug mode should remain enabled")
	_expect(session.help_state.free_hints_remaining == session.help_config.free_hints, "Unlimited Hint should not consume free allowances")
	_expect(session.is_hint_presentation_active(), "Exactly one current Hint presentation should remain active")
	_expect(feedback.queued_message_count() == 0, "Repeated Hint text should not accumulate in ActionFeedback")
	_expect(game.find_children("*", "", true, false).size() == node_count_before, "Repeated Hint should not create surviving overlay nodes")
	_expect(_visible_tray_hint_count(tray) == 1, "Repeated Hint should leave one highlighted tray slot")
	_expect(_visible_board_hint_count(board) == 1, "A single-cell Hint should leave one highlighted board cell")

	await create_timer(0.15).timeout
	_expect(session.request_hint(), "A new Hint should replace an active presentation")
	await create_timer(0.15).timeout
	_expect(session.is_hint_presentation_active(), "Old Hint cleanup must not clear the replacement presentation")
	_expect(_visible_tray_hint_count(tray) == 1, "Replacement Hint should retain one tray highlight")
	await create_timer(0.15).timeout
	_expect(not session.is_hint_presentation_active(), "Replacement Hint should clean itself up once")
	_expect(_visible_tray_hint_count(tray) == 0, "Tray Hint highlight should be cleared after timeout")
	_expect(_visible_board_hint_count(board) == 0, "Board Hint highlight should be cleared after timeout")


func _test_hint_cancels_stale_drag(session: GameSession, tray: PieceTray) -> void:
	var slot := tray.get_child(0) as PieceSlot
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = slot.get_global_rect().get_center()
	press.global_position = press.position
	slot._gui_input(press)
	_expect(slot._dragging, "Precondition: PieceSlot should have an active mouse drag")
	_expect(session._active_slot == 0, "Precondition: GameSession should track the active slot")

	_expect(session.request_hint(), "Hint should be accepted while an old drag is active")
	_expect(not slot._dragging, "Hint should cancel the PieceSlot drag state")
	_expect(session._active_slot == -1 and session._active_definition == null, "Hint should clear GameSession drag references")
	_expect(slot.mouse_filter == Control.MOUSE_FILTER_STOP, "Cancelling a drag for Hint must leave the piece selectable")
	await create_timer(0.3).timeout


func _test_mouse_touch_and_refill(session: GameSession, board: BoardView, tray: PieceTray) -> void:
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
	_expect(session.moves == 1, "Mouse drag should still place after repeated Hint")

	var touch_slot := tray.get_child(1) as PieceSlot
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 7
	touch_press.pressed = true
	touch_press.position = touch_slot.get_global_rect().get_center()
	touch_slot._gui_input(touch_press)
	var touch_target := board.get_cell_global_center(Vector2i(2, 0)) + Vector2(0.0, session.touch_drag_lift)
	var touch_motion := InputEventScreenDrag.new()
	touch_motion.index = 7
	touch_motion.position = touch_target
	touch_slot._input(touch_motion)
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 7
	touch_release.pressed = false
	touch_release.position = touch_target
	touch_slot._input(touch_release)
	_expect(session.moves == 2, "Touch drag should still place after repeated Hint")

	_expect(session.try_place_piece(2, Vector2i(4, 0)), "Third piece should place normally after repeated Hint")
	_expect(session.moves == 3, "All three successful placements should be counted")
	_expect(not tray.all_empty(), "Tray should refill after the third piece")
	_expect(tray.get_active_slot_indices().size() == 3, "Refilled tray should expose three selectable pieces")


func _test_hint_overlays_ignore_input(board: BoardView, tray: PieceTray, feedback: ActionFeedback) -> void:
	for slot_node in tray.get_children():
		if slot_node is PieceSlot:
			var slot := slot_node as PieceSlot
			_expect(slot.mouse_filter == Control.MOUSE_FILTER_STOP, "Available PieceSlot should keep MOUSE_FILTER_STOP")
			_expect(slot.hint_highlight.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Tray Hint overlay must ignore pointer input")
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := board.get_cell_view(Vector2i(x, y))
			_expect(cell.selection_highlight.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Board Hint overlay must ignore pointer input")
			_expect(cell.hint_ghost.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Board Hint ghost must ignore pointer input")
	_expect(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ActionFeedback root must ignore pointer input")


func _visible_tray_hint_count(tray: PieceTray) -> int:
	var count := 0
	for child in tray.get_children():
		if child is PieceSlot and child.hint_highlight.visible:
			count += 1
	return count


func _visible_board_hint_count(board: BoardView) -> int:
	var count := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if board.get_cell_view(Vector2i(x, y)).hint_ghost.visible:
				count += 1
	return count
