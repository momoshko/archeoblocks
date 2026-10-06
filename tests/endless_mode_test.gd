extends SceneTree

# Endless Excavation (M4.2): streaks, depth layers, records, the endless screen
# and the main menu lock.

const TEST_PROGRESS_PATH := "res://tests/.endless_progress.cfg"
const ENDLESS_SCENE := "res://scenes/screens/endless_screen.tscn"
const ENDLESS_DEFINITION := "res://resources/endless/endless_default.tres"
const SINGLE: PieceDefinition = preload("res://resources/pieces/single.tres")
const SQUARE: PieceDefinition = preload("res://resources/pieces/square_2.tres")

var _failures: Array[String] = []
var _checks := 0
var _finished_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	OnboardingTutorial.auto_start = true
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	DirAccess.remove_absolute(ProgressStore.storage_path)

	_test_streak_tracker()
	_test_definition()
	_test_records()
	await _test_menu_lock()
	await _test_endless_screen()

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("ENDLESS_MODE_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_streak_tracker() -> void:
	var tracker := StreakTracker.new()
	tracker.configure(3, 0.5, 2.0)
	_expect(tracker.register_move(0) == 1.0 and not tracker.is_active(), "A: no line, no streak")
	_expect(tracker.register_move(1) == 1.0 and tracker.streak == 1, "A: first line move is x1")
	_expect(tracker.register_move(2) == 1.5, "A: second line move in a row is x1.5")
	tracker.register_move(0)
	tracker.register_move(0)
	_expect(tracker.is_active() and tracker.moves_left == 1, "A: two misses keep the streak with one move left")
	_expect(tracker.register_move(1) == 2.0 and tracker.streak == 3, "A: a line within the grace moves continues the streak")
	_expect(tracker.register_move(1) == 2.0, "A: the multiplier stops at the cap")
	for i in 3:
		tracker.register_move(0)
	_expect(not tracker.is_active() and tracker.multiplier() == 1.0, "A: three misses end the streak")
	_expect(tracker.best_streak == 4, "A: best streak is remembered")
	var restored := StreakTracker.new()
	restored.restore_state(tracker.capture_state())
	_expect(restored.best_streak == 4 and restored.streak == 0, "A: capture/restore")


func _test_definition() -> void:
	var definition := load(ENDLESS_DEFINITION) as EndlessDefinition
	_expect(definition != null and definition.validate().is_empty(), "B: default endless definition is valid: %s" % [definition.validate() if definition else "missing"])
	_expect(definition.depth_for_lines(7) == 0 and definition.depth_for_lines(8) == 1 and definition.depth_for_lines(57) == 7, "B: 8 lines = 1 metre")
	_expect(definition.layer_index_for_depth(0) == 0 and definition.layer_index_for_depth(3) == 0, "B: surface layer to 3 m")
	_expect(definition.layer_index_for_depth(4) == 1 and definition.layer_index_for_depth(8) == 2 and definition.layer_index_for_depth(40) == 2, "B: clay from 4 m, catacombs from 8 m")
	var broken := EndlessDefinition.new()
	_expect(not broken.validate().is_empty(), "B: a definition without layers is invalid")
	_expect(GameSession.format_number(1234567) == "1 234 567" and GameSession.format_number(950) == "950", "B: numbers are grouped by thousands")


func _test_records() -> void:
	DirAccess.remove_absolute(ProgressStore.storage_path)
	_expect(ProgressStore.get_endless_best_score() == 0, "C: no record at first")
	var first := ProgressStore.submit_endless_run(1200, 3)
	_expect(first.error == OK and first.new_score_record and first.new_depth_record, "C: first run sets the records")
	var second := ProgressStore.submit_endless_run(800, 5)
	_expect(not second.new_score_record and second.new_depth_record, "C: a lower score keeps the best, a deeper dig updates depth")
	_expect(ProgressStore.get_endless_best_score() == 1200 and ProgressStore.get_endless_best_depth() == 5, "C: best score and depth are saved")
	var state := ProgressStore.export_state()
	_expect(int(state.records.endless_best_score) == 1200 and int(state.records.endless_runs) == 2, "C: records go to the cloud save")
	ProgressStore.merge_state({"records": {"endless_best_score": 3000, "endless_best_depth": 2, "endless_runs": 1}})
	_expect(ProgressStore.get_endless_best_score() == 3000 and ProgressStore.get_endless_best_depth() == 5, "C: merge keeps the best of both sides")
	DirAccess.remove_absolute(ProgressStore.storage_path)


func _test_menu_lock() -> void:
	DirAccess.remove_absolute(ProgressStore.storage_path)
	var menu := (load("res://scenes/screens/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	await process_frame
	var button := menu.get_node("%EndlessButton") as Button
	_expect(button.disabled and menu.get_node("%EndlessLockHint").visible, "D: endless mode is locked before expedition 3")
	root.remove_child(menu)
	menu.queue_free()
	ProgressStore.mark_expedition_completed(&"expedition_03")
	menu = (load("res://scenes/screens/main_menu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	await process_frame
	button = menu.get_node("%EndlessButton") as Button
	_expect(not button.disabled and not menu.get_node("%EndlessLockHint").visible, "D: endless mode opens after expedition 3")
	root.remove_child(menu)
	menu.queue_free()
	await process_frame


func _open_screen(seed_value: int) -> Control:
	var screen := (load(ENDLESS_SCENE) as PackedScene).instantiate() as Control
	var session := screen.get_node("GameSession") as GameSession
	session.endless_seed_override = seed_value
	root.add_child(screen)
	await process_frame
	_expect((screen.get_node("ModalUI/EndlessLobby") as CanvasItem).visible, "The run starts behind the lobby")
	_expect(session.is_input_blocked(), "The board waits while the lobby is open")
	screen.call("_start_run", false)
	await process_frame
	await process_frame
	return screen


func _close_screen(screen: Control) -> void:
	root.remove_child(screen)
	screen.queue_free()
	await process_frame


func _fill(session: GameSession, cells: Array[Vector2i]) -> void:
	for cell in cells:
		session.board_model.place([Vector2i.ZERO] as Array[Vector2i], cell)


func _row_cells(y: int, skip_x: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		if x != skip_x:
			cells.append(Vector2i(x, y))
	return cells


func _place(session: GameSession, slot: int, origin: Vector2i) -> bool:
	var placed := session.try_place_piece(slot, origin)
	while session.is_turn_resolving():
		await process_frame
	return placed


func _test_endless_screen() -> void:
	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.submit_endless_run(400, 1)

	# E: determinism of the run seed.
	var screen := await _open_screen(777)
	var session := screen.get_node("GameSession") as GameSession
	var first_tray := session.piece_tray.capture_state().map(func(p: PieceDefinition) -> StringName: return p.id)
	await _close_screen(screen)
	screen = await _open_screen(777)
	session = screen.get_node("GameSession") as GameSession
	var again := session.piece_tray.capture_state().map(func(p: PieceDefinition) -> StringName: return p.id)
	_expect(first_tray == again, "E: the same run seed gives the same pieces")
	_expect(session.get_endless_seed() == 777, "E: seed override is used")

	# F: endless screen basics.
	_expect(session.is_endless() and session.expedition_definition == null, "F: the session runs in endless mode")
	_expect(not screen.get_node("TutorialUI/OnboardingTutorial").visible, "F: no expedition intro or tutorial")
	_expect(not session.undo_button.visible and not session.hint_button.visible, "F: Undo and Hint are hidden")
	_expect(not session.request_undo() and not session.request_hint(), "F: Undo and Hint do nothing")
	_expect(session.score_label.text == "0", "F: score starts at 0")
	_expect(session.record_label.text == tr("Рекорд: %s") % "400", "F: the record is shown: %s" % session.record_label.text)
	_expect(session.depth_label.text.contains("0"), "F: depth starts at 0 m")

	# G: streak scoring through the real placement path.
	session.piece_tray.load_set([SINGLE, SINGLE, SINGLE] as Array[PieceDefinition])
	_fill(session, _row_cells(0, 0))
	_fill(session, [Vector2i(5, 5)] as Array[Vector2i])
	_expect(await _place(session, 0, Vector2i(0, 0)), "G: first line placement works")
	_expect(session.score == 10 + 100 and session.streak.streak == 1, "G: first line scores x1 (score %d)" % session.score)
	_fill(session, _row_cells(1, 0))
	_expect(await _place(session, 1, Vector2i(0, 1)), "G: second line placement works")
	_expect(session.score == 110 + 10 + 150, "G: second line in a row scores x1.5 (score %d)" % session.score)
	_expect(session.total_lines == 2 and session.depth == 0, "G: lines are counted")
	_expect(session.record_label.text == tr("До рекорда: %s") % "130", "G: past half of the record the gap is shown: %s" % session.record_label.text)
	_expect(session.streak_label.text.contains("●"), "G: streak indicator shows the grace moves")

	# H: board clear bonus and new record.
	session.board_model.reset()
	session.piece_tray.load_set([SINGLE, SINGLE, SINGLE] as Array[PieceDefinition])
	_fill(session, _row_cells(2, 3))
	var before := session.score
	_expect(await _place(session, 0, Vector2i(3, 2)), "H: clearing placement works")
	# x2 streak: line 200 + clean board 1000 * 2.
	_expect(session.score == before + 10 + 200 + 2000, "H: clean board bonus uses the streak (gained %d)" % (session.score - before))
	_expect(session.record_label.text == tr("Новый рекорд!"), "H: passing the record is announced")

	# I: going deeper switches the piece weights.
	var definition := session.endless_definition
	session.total_lines = 39
	session.board_model.reset()
	_fill(session, _row_cells(4, 2))
	_fill(session, [Vector2i(6, 6)] as Array[Vector2i])
	_expect(await _place(session, 1, Vector2i(2, 4)), "I: line placement at 39 lines works")
	_expect(session.depth == 5, "I: 40 lines = 5 m")
	_expect(session.piece_sequence.generation_config() == definition.layers[1].piece_generation, "I: clay weights from 5 m")
	_expect(session.depth_label.text.contains(tr("Глина")), "I: depth label names the layer: %s" % session.depth_label.text)

	# J: no moves ends the run, saves the record, offers Play again / Menu.
	session.endless_run_finished.connect(func(result: Dictionary) -> void: _finished_results.append(result))
	session.board_model.reset()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if (x + y) % 2 == 0:
				session.board_model.place([Vector2i.ZERO] as Array[Vector2i], Vector2i(x, y))
	session.piece_tray.load_set([SQUARE, SQUARE, SQUARE] as Array[PieceDefinition])
	session.evaluate_play_state()
	var popup := screen.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(session.is_no_moves_state() and popup.visible, "J: no moves shows the result")
	_expect(_finished_results.size() == 1, "J: run finished signal fires once")
	var result: Dictionary = _finished_results[0] if not _finished_results.is_empty() else {}
	_expect(bool(result.get("new_score_record", false)) and int(result.get("depth", -1)) == 5, "J: result has the record and depth")
	_expect(ProgressStore.get_endless_best_score() == session.score, "J: the new record is saved")
	_expect(popup.retry_button.text == tr("Ещё раз") and popup.next_button.text == tr("В меню"), "J: Play again and Menu buttons")
	_expect(not popup.undo_button.visible, "J: no Undo offer at the end of a run")
	_expect(popup._is_rescue, "J: the right button goes to the menu, not to a next expedition")

	# K: Play again starts a fresh run.
	popup.retry_button.pressed.emit()
	for i in 5:
		await process_frame
	_expect(not popup.visible and not session.is_no_moves_state(), "K: Play again closes the result")
	_expect(session.score == 0 and session.depth == 0 and session.total_lines == 0 and session.streak.streak == 0, "K: the new run starts from zero")
	_expect(session.piece_sequence.generation_config() == definition.layers[0].piece_generation, "K: back to the surface weights")
	_expect(session.record_label.text == tr("До рекорда: %s") % GameSession.format_number(ProgressStore.get_endless_best_score()) or session.record_label.text == tr("Рекорд: %s") % GameSession.format_number(ProgressStore.get_endless_best_score()), "K: the new record is the target")
	await _close_screen(screen)

