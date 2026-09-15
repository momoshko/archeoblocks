extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_10a_web_parity_progress.cfg"
const DETAIL_GRID := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"

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
	await _test_export_safe_chapter_two_launch()
	await _test_hint_then_mouse_and_touch_drag()
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_10A_WEB_PARITY_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_export_safe_chapter_two_launch() -> void:
	var chapter_one := load("res://resources/chapters/ancient_courtyard.tres") as ChapterDefinition
	for expedition in chapter_one.expeditions:
		_expect(ProgressStore.mark_expedition_completed(expedition.id) == OK, "Chapter I test progress should save")
	_expect(ProgressStore.completed_expeditions().size() == 6, "Saved Chapter I progress should be immediately readable")

	var detail := load("res://scenes/screens/chapter_detail_02.tscn").instantiate() as Control
	root.add_child(detail)
	current_scene = detail
	await process_frame
	_expect(detail.expedition_scenes.size() == 8, "Chapter II must retain all PackedScene references")
	for expedition_scene in detail.expedition_scenes:
		_expect(expedition_scene != null, "Every Chapter II expedition must have an export-safe PackedScene")
	var first_button := detail.get_node(DETAIL_GRID + "Expedition01") as Button
	_expect(not first_button.disabled and first_button.text.ends_with("Открыто"), "Chapter II 2-1 must be actionable whenever it reads Open")
	_expect(first_button.pressed.get_connections().size() == 1, "Chapter II 2-1 must have one launch action")
	first_button.pressed.emit()
	await process_frame
	await process_frame
	var session := current_scene.get_node_or_null("GameSession") as GameSession if current_scene != null else null
	_expect(session != null, "Pressing Chapter II 2-1 must change to a gameplay scene")
	_expect(session != null and session.expedition_definition.id == &"ruined_shrine_01", "Chapter II 2-1 must load the intended expedition")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _test_hint_then_mouse_and_touch_drag() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var singles: Array[PieceDefinition] = [single, single, single]
	tray.restore_state(singles)
	session.help_config = session.help_config.duplicate()
	session.help_config.debug_unlimited_hints = true
	session.help_config.hint_planning_depth = 1

	_expect(session.request_hint(), "Hint should activate before mouse drag")
	_expect(not session._input_blocked and not session._busy and not session._reward_request_pending, "Informational Hint must not lock gameplay input")
	_mouse_place(tray.get_child(1) as PieceSlot, board, session, Vector2i(0, 0))
	_expect(session.moves == 1, "A different piece must place by mouse immediately after Hint")
	_expect(not session.is_hint_presentation_active(), "Starting a real mouse drag must clear Hint presentation")

	_expect(session.request_hint(), "Repeated Hint should activate before touch drag")
	_touch_place(tray.get_child(2) as PieceSlot, board, session, Vector2i(2, 0))
	_expect(session.moves == 2, "An available piece must place by touch immediately after repeated Hint")
	_expect(not session.is_hint_presentation_active(), "Starting a real touch drag must clear Hint presentation")
	for slot_index in tray.get_active_slot_indices():
		_expect((tray.get_child(slot_index) as PieceSlot).mouse_filter == Control.MOUSE_FILTER_STOP, "Available slots must keep accepting pointer input")

	root.remove_child(game)
	game.queue_free()
	current_scene = null
	await process_frame


func _mouse_place(slot: PieceSlot, board: BoardView, session: GameSession, cell: Vector2i) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = slot.get_global_rect().get_center()
	press.global_position = press.position
	slot._gui_input(press)
	var target := board.get_cell_global_center(cell) + Vector2(0.0, session.mouse_drag_lift)
	var motion := InputEventMouseMotion.new()
	motion.position = target
	slot._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target
	slot._input(release)


func _touch_place(slot: PieceSlot, board: BoardView, session: GameSession, cell: Vector2i) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 9
	press.pressed = true
	press.position = slot.get_global_rect().get_center()
	slot._gui_input(press)
	var target := board.get_cell_global_center(cell) + Vector2(0.0, session.touch_drag_lift)
	var motion := InputEventScreenDrag.new()
	motion.index = 9
	motion.position = target
	slot._input(motion)
	var release := InputEventScreenTouch.new()
	release.index = 9
	release.pressed = false
	release.position = target
	slot._input(release)


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
