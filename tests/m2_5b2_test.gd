extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_5b2_progress.cfg"
const CARD_ROOT := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"

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
	_delete_test_progress()
	await _test_hint_is_board_local_with_three_and_one_piece()
	await _test_top_and_bottom_hint_bounds()
	await _test_expedition_six_return_keeps_cards_visible()
	await _test_supported_title_width()
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_5B2_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_hint_is_board_local_with_three_and_one_piece() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := session.board_view
	var tray := session.piece_tray
	var hint := session.find_best_hint()
	var expected_targets := session._predict_artifact_hit_cells(
		tray.get_definition(hint.slot_index),
		hint.origin
	)
	_expect(tray.get_active_slot_indices().size() == 3, "Hint fixture should start with all three tray pieces")
	_expect(session.request_hint(), "Hint should activate with all three tray pieces")
	await process_frame
	_expect(not session.drag_preview.visible, "Hint must not reuse the global DragPiecePreview")
	_expect(_visible_tray_hint_count(tray) == 1, "Hint should highlight exactly one PieceSlot")
	_expect(_visible_board_hint_count(board) == hint.cells.size(), "Hint should render every suggested cell inside BoardView")
	_expect(board.clip_contents, "BoardView must clip transient hint visuals to its own rectangle")
	_expect(_all_hint_cells_inside_board(board), "Hint cells must stay inside BoardView bounds")
	_expect(not _hint_cells_overlap_hud(game, board), "Board-local Hint cells must not overlap HUD controls")
	for target in expected_targets:
		_expect(board.get_cell_view(target).artifact_target_prediction.visible, "Useful artifact target emphasis should remain visible")

	session._clear_hint_feedback()
	tray.consume_slot(0)
	tray.consume_slot(1)
	_expect(tray.get_active_slot_indices().size() == 1, "One-piece Hint fixture should leave one active slot")
	_expect(session.request_hint(), "Hint should activate with only one tray piece remaining")
	await process_frame
	_expect(_visible_tray_hint_count(tray) == 1, "One remaining piece should be highlighted in its tray slot")
	_expect(_visible_board_hint_count(board) > 0, "One remaining piece should still receive a board-local suggestion")
	_expect(not session.drag_preview.visible, "One-piece Hint must not create a global drag ghost")
	_expect(not _hint_cells_overlap_hud(game, board), "One-piece Hint must remain clear of HUD controls")
	game.queue_free()
	await process_frame


func _test_top_and_bottom_hint_bounds() -> void:
	var board := load("res://scenes/game/board_view.tscn").instantiate() as BoardView
	root.add_child(board)
	await process_frame
	board.show_hint_cells([Vector2i(0, 0), Vector2i(7, 7)])
	_expect(board.get_cell_view(Vector2i(0, 0)).hint_ghost.visible, "Top-edge Hint should use the board-local ghost layer")
	_expect(board.get_cell_view(Vector2i(7, 7)).hint_ghost.visible, "Bottom-edge Hint should use the board-local ghost layer")
	_expect(_all_hint_cells_inside_board(board), "Top and bottom Hint previews must remain clipped to the board")
	board.clear_hint_cells()
	_expect(_visible_board_hint_count(board) == 0, "Board Hint cleanup should clear edge previews")
	board.queue_free()
	await process_frame


func _test_expedition_six_return_keeps_cards_visible() -> void:
	for expedition_id in [&"expedition_01", &"expedition_02", &"expedition_03", &"expedition_04", &"expedition_05", &"expedition_06"]:
		_expect(ProgressStore.mark_expedition_completed(expedition_id) == OK, "Completed expedition state should save")
	var game := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	game.call("_open_next_expedition")
	await process_frame
	await process_frame
	var selector := current_scene as Control
	_expect(selector != null and selector.name == "ChapterDetailOne", "Expedition 6 Next should return to Chapter I detail")
	if selector != null:
		var scroll := selector.get_node("ContentCenter/PortraitContent/ExpeditionScroll") as ScrollContainer
		var grid := selector.get_node("ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid") as HFlowContainer
		_expect(scroll.visible and scroll.size.x > 0.0 and scroll.size.y > 0.0, "Expedition ScrollContainer should retain visible area")
		_expect(grid.visible and grid.size.x > 0.0 and grid.size.y > 0.0, "Expedition HFlowContainer should retain content size")
		for index in 6:
			var button := selector.get_node(CARD_ROOT + "Expedition%02d" % (index + 1)) as Button
			_expect(button.visible and button.is_visible_in_tree(), "Completed onboarding card should remain visible")
			_expect(button.text.ends_with("✓ Пройдено"), "Returned card should show completed state")
			_expect(button.get_global_rect().intersects(scroll.get_global_rect()), "Returned card should be inside the visible scroll viewport")
	selector.queue_free()
	current_scene = null
	await process_frame


func _test_supported_title_width() -> void:
	var game := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var title := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/HeaderText/ExpeditionTitle") as Label
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var text_width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 720, "Supported logical portrait width should remain 720")
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "Responsive check assumes the configured canvas_items stretch")
	_expect(text_width <= title.size.x, "Golden Mask expedition title should fit the supported logical width")
	_expect(title.get_line_count() == 1, "Golden Mask expedition title should remain a single readable line")
	game.queue_free()
	await process_frame


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


func _all_hint_cells_inside_board(board: BoardView) -> bool:
	var board_rect := board.get_global_rect()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := board.get_cell_view(Vector2i(x, y))
			if not cell.hint_ghost.visible:
				continue
			var rect := cell.hint_ghost.get_global_rect()
			if rect.position.x < board_rect.position.x - 0.5 or rect.position.y < board_rect.position.y - 0.5:
				return false
			if rect.end.x > board_rect.end.x + 0.5 or rect.end.y > board_rect.end.y + 0.5:
				return false
	return true


func _hint_cells_overlap_hud(game: Control, board: BoardView) -> bool:
	var hud_paths := [
		"ContentCenter/PortraitContent/MainLayout/Header/PauseButton",
		"ContentCenter/PortraitContent/MainLayout/Header/HeaderText/ExpeditionTitle",
		"ContentCenter/PortraitContent/MainLayout/Header/HeaderText/FragmentProgress",
		"ContentCenter/PortraitContent/MainLayout/ObjectiveText",
		"ContentCenter/PortraitContent/MainLayout/ObjectiveSecondary",
		"ContentCenter/PortraitContent/MainLayout/Actions/UndoButton",
		"ContentCenter/PortraitContent/MainLayout/Actions/HintButton",
		"ContentCenter/PortraitContent/MainLayout/Stats/MovesLabel",
		"ContentCenter/PortraitContent/MainLayout/Stats/ScoreLabel",
	]
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := board.get_cell_view(Vector2i(x, y))
			if not cell.hint_ghost.visible:
				continue
			var hint_rect := cell.hint_ghost.get_global_rect()
			for path in hud_paths:
				var hud := game.get_node(path) as Control
				if hint_rect.intersects(hud.get_global_rect()):
					return true
	return false


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
