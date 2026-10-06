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
	OnboardingTutorial.auto_start = false
	await _test_piece_slot_centering()
	await _test_single_game_screen_scenario()
	if _failures.is_empty():
		print("M2_2_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_piece_slot_centering() -> void:
	var slot := load("res://scenes/game/piece_slot.tscn").instantiate() as PieceSlot
	root.add_child(slot)
	await process_frame
	var definitions: Array[PieceDefinition] = [
		load("res://resources/pieces/small_l.tres"),
		load("res://resources/pieces/line_3_vertical.tres"),
		load("res://resources/pieces/square_2.tres"),
	]
	var visual_cell_sizes: Array[float] = []
	for definition in definitions:
		slot.set_definition(definition)
		await process_frame
		var bounds := slot.get_piece_visual_bounds()
		_expect(bounds.has_area(), "%s preview should have bounds" % definition.id)
		_expect(bounds.get_center().is_equal_approx(slot.piece_canvas.size * 0.5), "%s preview should be centered on both axes" % definition.id)
		visual_cell_sizes.append((slot._piece_cells[0] as Control).size.x)
	_expect(is_equal_approx(visual_cell_sizes[0], visual_cell_sizes[1]) and is_equal_approx(visual_cell_sizes[1], visual_cell_sizes[2]), "Sample pieces should use one visual scale")
	slot.set_definition(null)
	_expect(slot.modulate.a < 0.9 and not (slot._piece_cells[0] as Control).visible, "Used slot should clear its old preview")
	slot.queue_free()
	await process_frame


func _test_single_game_screen_scenario() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition

	# Fixture: an unfinished artifact at (1, 1) under a soil row, independent of Expedition 1 data.
	var fragment := ArtifactFragmentDefinition.new()
	fragment.id = &"row_one"
	fragment.cells.assign([Vector2i(1, 1)])
	var fixture := ExpeditionDefinition.new()
	fixture.id = &"m2_2_fixture"
	fixture.title_ru = "Тест M2.2"
	fixture.artifact_name_ru = "Тест"
	for x in 8:
		fixture.normal_soil_cells.append(Vector2i(x, 1))
	fixture.artifact_fragments = [fragment] as Array[ArtifactFragmentDefinition]
	session.expedition_definition = fixture
	session.restart_expedition()
	var hint_set: Array[PieceDefinition] = [single, single, null]
	tray.load_set(hint_set)
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	for row in [0, 1]:
		for x in 7:
			session.board_model.place(single_shape, Vector2i(x, row), Color.DARK_GREEN)
	var hint := session.find_best_hint()
	_expect(not hint.is_empty(), "Hint should return a move")
	var hinted_piece := tray.get_definition(hint.slot_index)
	_expect(session.board_model.can_place(hinted_piece.cells, hint.origin), "Hint move must always be legal")
	_expect(hint.origin == Vector2i(7, 1), "Hint should prefer the line that advances an unfinished artifact target")

	session.help_config.debug_unlimited_hints = true
	var free_before := session.help_state.free_hints_remaining
	var rewarded_before := session.help_state.rewarded_hints_remaining
	var reward_events := {"count": 0}
	session.reward_service.reward_granted.connect(func(_id: int, _type: int) -> void: reward_events.count += 1)
	_expect(session.is_debug_unlimited_hints_enabled(), "Unlimited Hint should activate only in this debug run")
	_expect(session.request_hint(), "Unlimited debug Hint should be usable")
	_expect(session.help_state.free_hints_remaining == free_before and session.help_state.rewarded_hints_remaining == rewarded_before, "Unlimited Hint must not spend allowances")
	_expect(reward_events.count == 0, "Unlimited Hint must not call the reward flow")

	var artifact_cell := board.get_cell_view(Vector2i(1, 1))
	artifact_cell.set_excavation_state(2, true, false)
	_expect(artifact_cell.burial_depth_2.visible and not artifact_cell.burial_depth_1.visible, "Depth 2 artifact shows the deep burial art")
	artifact_cell.set_excavation_state(1, true, false)
	_expect(artifact_cell.burial_depth_1.visible and not artifact_cell.burial_depth_2.visible, "Depth 1 artifact shows the shallow burial art")
	artifact_cell.set_excavation_state(0, true, true)
	_expect(not artifact_cell.artifact_target_border.visible, "Completed fragment should drop the unfinished-target border")

	session.action_feedback.clear()
	session.board_model.reset()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if Vector2i(x, y) != Vector2i(7, 7):
				session.board_model.place(single_shape, Vector2i(x, y), Color.DARK_GREEN)
	var blocked_piece_set: Array[PieceDefinition] = [square, single, null]
	tray.load_set(blocked_piece_set)
	session._on_drag_started(0, square, Vector2.ZERO, false)
	_expect(session.action_feedback.message_label.text == "Нет места для этой фигуры", "A selected blocked piece should explain why drag did not start")
	_expect(not session.is_no_moves_state(), "A blocked selected piece must not replace Rescue while another active piece fits")

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame
