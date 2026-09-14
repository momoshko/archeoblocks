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
	var game := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tray := session.piece_tray
	var board := session.board_view
	var feedback := session.action_feedback
	var hint := session.find_best_hint()
	_expect(not hint.is_empty(), "Finale fixture should have a legal Hint")
	var definition := tray.get_definition(hint.slot_index)
	var expected_texture := BlockTextureResolver.texture_for_color(
		board.get_cell_view(hint.cells[0]).block_texture_set,
		definition.cosmetic_color
	)
	_expect(session.request_hint(), "Hint should activate")
	await process_frame
	_expect(not feedback.visible, "Normal Hint activation must not show the redundant ActionFeedback banner")
	_expect(feedback.queued_message_count() == 0, "Normal Hint activation must not queue redundant text feedback")
	_expect(feedback.message_label.text != "ПОДСКАЗКА", "Hint-specific text should not enter the ActionFeedback presentation path")
	_expect(_visible_tray_hint_count(tray) == 1, "Hint should identify exactly one PieceSlot")
	_expect(_visible_ghost_count(board) == definition.cells.size(), "Board ghost should preserve the exact piece shape")
	for cell_position in hint.cells:
		var cell := board.get_cell_view(cell_position)
		_expect(cell.hint_ghost.visible, "Each suggested piece cell should show a ghost block")
		_expect(cell.hint_ghost.texture == expected_texture, "Hint ghost should use the selected piece color texture")
		_expect(cell.hint_ghost.modulate.a >= 0.45 and cell.hint_ghost.modulate.a <= 0.60, "Hint ghost alpha should stay in the readable translucent range")
		_expect(not cell.valid_preview.visible, "Automatic Hint must not show valid-placement checkmarks")
		_expect(not cell.invalid_preview.visible, "Automatic Hint must not show invalid-placement overlays")
		_expect(cell.hint_ghost.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hint ghost must not intercept input")
	_expect(board.clip_contents, "Hint ghost should remain clipped to BoardView")
	var affected_targets := session._predict_artifact_hit_cells(definition, hint.origin)
	for target in affected_targets:
		var target_view := board.get_cell_view(target)
		_expect(target_view.artifact_target_prediction.visible, "Useful artifact target emphasis should remain visible")
		_expect(target_view.artifact_target_border.z_index > target_view.hint_ghost.z_index, "Artifact marker must render above the Hint ghost")

	for invocation in 20:
		_expect(session.request_hint(), "Repeated Hint %d should safely replace the current presentation" % (invocation + 1))
	await process_frame
	_expect(_visible_tray_hint_count(tray) == 1, "Repeated Hint should not stack tray highlights")
	_expect(_visible_ghost_count(board) == definition.cells.size(), "Repeated Hint should not stack board ghosts")
	session._clear_hint_feedback()
	_expect(_visible_ghost_count(board) == 0, "Hint cleanup should remove every ghost cell")
	_expect(_visible_tray_hint_count(tray) == 0, "Hint cleanup should remove the PieceSlot highlight")
	_expect(tray.get_active_slot_indices().size() == 3, "Hint lifecycle should leave tray input state intact")
	feedback.show_message("ТЕСТОВОЕ СООБЩЕНИЕ")
	_expect(feedback.visible and feedback.message_label.text == "ТЕСТОВОЕ СООБЩЕНИЕ", "Non-Hint ActionFeedback messages should remain functional")

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("M2_6_HINT_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _visible_tray_hint_count(tray: PieceTray) -> int:
	var count := 0
	for child in tray.get_children():
		if child is PieceSlot and child.hint_highlight.visible:
			count += 1
	return count


func _visible_ghost_count(board: BoardView) -> int:
	var count := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if board.get_cell_view(Vector2i(x, y)).hint_ghost.visible:
				count += 1
	return count
