extends SceneTree

# Real-device touch path: the finger goes through Godot's Input pipeline, which
# (with "Emulate Mouse From Touch" on by default) sends an emulated mouse press
# BEFORE the ScreenTouch. The drag must still use the touch lift, so the piece
# is drawn above the finger instead of under it. Mouse input keeps the small lift.
# Undo pressed while a piece is held drops the piece back first (no stale drag).

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _new_game() -> Array:
	var game := load("res://scenes/screens/game_screen_02.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	# Close the objective card so the pointer reaches the tray.
	game.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	var session := game.get_node("GameSession") as GameSession
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	tray.restore_state([single, single, single] as Array[PieceDefinition])
	return [game, session, tray, board]


## Delivers a pointer event the way the engine does on a phone.
## Headless mode has no window event loop, so Input.parse_input_event never
## reaches the GUI; this mirrors core/input/input.cpp (_parse_input_event_impl)
## instead: for the first finger the emulated mouse event (device -1) is
## dispatched BEFORE the touch event itself.
func _send(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		var button := InputEventMouseButton.new()
		button.device = InputEvent.DEVICE_ID_EMULATION
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = event.pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		button.position = event.position
		button.global_position = event.position
		root.push_input(button)
	elif event is InputEventScreenDrag and event.index == 0:
		var motion := InputEventMouseMotion.new()
		motion.device = InputEvent.DEVICE_ID_EMULATION
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = event.position
		motion.global_position = event.position
		motion.relative = event.relative
		root.push_input(motion)
	root.push_input(event)


## Canvas position -> window position (what a real pointer event carries).
func _screen(position: Vector2) -> Vector2:
	return root.get_final_transform() * position


func _run() -> void:
	_expect(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)), "project keeps Godot's default mouse-from-touch emulation")

	# A: finger drag in the engine's real event order.
	var parts := await _new_game()
	var game: Control = parts[0]
	var session: GameSession = parts[1]
	var tray: PieceTray = parts[2]
	var board: BoardView = parts[3]
	var slot := tray.get_child(0) as PieceSlot
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = _screen(slot.get_global_rect().get_center())
	_send(press)
	_expect(session._active_definition != null, "A: touch press starts a drag")
	_expect(session._active_is_touch, "A: drag started by a finger uses the touch lift")
	var target_cell := Vector2i(4, 4)
	var finger := board.get_cell_global_center(target_cell) + Vector2(0.0, session.touch_drag_lift)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _screen(finger)
	drag.relative = drag.position - press.position
	_send(drag)
	_expect(session.is_drag_active(), "A: drag is active while the finger is down")
	_expect(session._active_origin == target_cell, "A: piece is placed %d px above the finger (origin %s)" % [session.touch_drag_lift, session._active_origin])
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = drag.position
	_send(release)
	_expect(session.moves == 1, "A: finger release places the piece")
	_expect(not session.is_drag_active(), "A: drag ends on release")
	_expect(not session.board_model.is_empty(target_cell), "A: piece lands on the cell above the finger")
	root.remove_child(game)
	game.queue_free()
	await process_frame

	# B: a real mouse keeps the small mouse lift.
	parts = await _new_game()
	game = parts[0]
	session = parts[1]
	tray = parts[2]
	board = parts[3]
	slot = tray.get_child(1) as PieceSlot
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	mouse_press.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse_press.position = _screen(slot.get_global_rect().get_center())
	mouse_press.global_position = mouse_press.position
	_send(mouse_press)
	_expect(session._active_definition != null, "B: mouse press starts a drag")
	_expect(not session._active_is_touch, "B: mouse drag uses the mouse lift")
	var pointer := board.get_cell_global_center(Vector2i(2, 2)) + Vector2(0.0, session.mouse_drag_lift)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = _screen(pointer)
	motion.global_position = motion.position
	_send(motion)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	mouse_release.position = motion.position
	mouse_release.global_position = motion.position
	_send(mouse_release)
	_expect(session.moves == 1, "B: mouse release places the piece")
	_expect(not session.board_model.is_empty(Vector2i(2, 2)), "B: mouse piece lands under the cursor")
	root.remove_child(game)
	game.queue_free()
	await process_frame

	# C: a second finger on another slot does not steal the active drag.
	parts = await _new_game()
	game = parts[0]
	session = parts[1]
	tray = parts[2]
	board = parts[3]
	var first := InputEventScreenTouch.new()
	first.index = 0
	first.pressed = true
	first.position = _screen((tray.get_child(0) as PieceSlot).get_global_rect().get_center())
	_send(first)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = _screen((tray.get_child(2) as PieceSlot).get_global_rect().get_center())
	_send(second)
	_expect(session._active_slot == 0, "C: second finger keeps the first drag active")
	var first_move := InputEventScreenDrag.new()
	first_move.index = 0
	first_move.position = _screen(board.get_cell_global_center(Vector2i(6, 1)) + Vector2(0.0, session.touch_drag_lift))
	_send(first_move)
	var first_up := InputEventScreenTouch.new()
	first_up.index = 0
	first_up.position = first_move.position
	_send(first_up)
	var second_up := InputEventScreenTouch.new()
	second_up.index = 1
	second_up.position = second.position
	_send(second_up)
	_expect(session.moves == 1 and not session.board_model.is_empty(Vector2i(6, 1)), "C: first finger's piece is placed")
	_expect(tray.is_slot_available(2), "C: the second finger's piece stays in the tray")
	root.remove_child(game)
	game.queue_free()
	await process_frame

	# D: Undo pressed (second finger) while a piece is held drops it back cleanly.
	parts = await _new_game()
	game = parts[0]
	session = parts[1]
	tray = parts[2]
	board = parts[3]
	_expect(session.try_place_piece(0, Vector2i(0, 7)), "D: first move places")
	await create_timer(1.0).timeout
	var hold := InputEventScreenTouch.new()
	hold.index = 0
	hold.pressed = true
	hold.position = _screen((tray.get_child(1) as PieceSlot).get_global_rect().get_center())
	_send(hold)
	_expect(session.is_drag_active(), "D: piece is held")
	_expect(session.request_undo(), "D: free Undo works while a piece is held")
	_expect(not session.is_drag_active(), "D: Undo drops the held piece")
	_expect(not (tray.get_child(1) as PieceSlot).is_dragging(), "D: slot drag state is cleared")
	_expect(session.moves == 0 and session.board_model.is_empty(Vector2i(0, 7)), "D: Undo restored the board")
	var hold_up := InputEventScreenTouch.new()
	hold_up.index = 0
	hold_up.position = _screen(board.get_cell_global_center(Vector2i(3, 3)) + Vector2(0.0, session.touch_drag_lift))
	_send(hold_up)
	_expect(session.moves == 0, "D: lifting the finger after Undo places nothing")
	root.remove_child(game)
	game.queue_free()
	await process_frame

	if _failures.is_empty():
		print("TOUCH_INPUT_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
