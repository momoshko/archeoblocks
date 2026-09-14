extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_9_root_session_progress.cfg"

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
	var game := load("res://scenes/screens/game_screen_ch3_prototype_01.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var initial_threat := session.get_root_threat_cell()
	var initial_source := session.get_root_threat_source()
	_expect(initial_threat == Vector2i(2, 1), "Prototype should expose deterministic initial warning")
	_expect(session.obstacle_model.root_count() == 4, "Prototype session should start with four Roots")
	_expect(session.board_view.get_cell_view(initial_threat).root_growth_warning.visible, "Threatened CellView should show warning before the move")

	_expect(session.try_place_piece(0, Vector2i(0, 0)), "Unrelated opening placement should be legal")
	await create_timer(0.75).timeout
	_expect(session.obstacle_model.is_root(initial_threat), "Unopposed Root should grow into exactly the warned cell")
	_expect(session.obstacle_model.root_count() == 5, "Normal turn should add exactly one Root")
	_expect(session.request_undo(), "Undo should accept a turn containing Root growth")
	_expect(session.obstacle_model.root_count() == 4 and not session.obstacle_model.is_root(initial_threat), "Undo should remove the newly grown Root")
	_expect(session.get_root_threat_source() == initial_source and session.get_root_threat_cell() == initial_threat, "Undo should restore the same source and warning")
	_expect(session.board_view.get_cell_view(initial_threat).root_growth_warning.visible, "Undo should restore warning visual")

	session.restart_expedition()
	var blocked_target := session.get_root_threat_cell()
	session.board_model.place([Vector2i.ZERO], blocked_target, Color.WHITE)
	var before_blocked_growth := session.obstacle_model.root_count()
	_expect(not await session._resolve_root_growth(false), "Occupied warned cell should block growth")
	_expect(session.obstacle_model.root_count() == before_blocked_growth, "Blocked growth must not retarget elsewhere in the same turn")

	session.restart_expedition()
	var cut_source := session.get_root_threat_source()
	var cut_result := session.obstacle_model.apply_hit_map({cut_source: 1})
	var after_cut := session.obstacle_model.root_count()
	_expect(cut_result.roots_destroyed == 1, "Fixture should cut one Root")
	_expect(not await session._resolve_root_growth(true), "Destroying a Root should suppress growth for that turn")
	_expect(session.obstacle_model.root_count() == after_cut, "Suppressed growth should not replace the destroyed Root")

	session.restart_expedition()
	_expect(session.get_root_threat_cell() == initial_threat, "Restart should restore deterministic initial warning")
	var no_moves_target := session.get_root_threat_cell()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if cell != no_moves_target and not session.obstacle_model.has_obstacle(cell):
				session.board_model.place([Vector2i.ZERO], cell, Color.WHITE)
	_expect(await session._resolve_root_growth(false), "Fixture should allow final warned growth")
	session.evaluate_play_state()
	_expect(session.is_no_moves_state(), "NO_MOVES should evaluate the board after Root growth")

	session.restart_expedition()
	var roots_before_victory := session.obstacle_model.root_count()
	var all_target_hits: Dictionary = {}
	for fragment in session.expedition_definition.artifact_fragments:
		for cell in fragment.cells:
			all_target_hits[cell] = 2
	session.excavation_model.apply_hit_map_detailed(all_target_hits)
	session.excavation_model.collect_newly_completed_fragments()
	session._commit_placement(0, session.piece_tray.get_definition(0), Vector2i(0, 0), session.piece_tray.get_definition(0).translated_cells(Vector2i(0, 0)))
	await process_frame
	_expect(session.obstacle_model.root_count() == roots_before_victory, "Immediate victory should finish before Root growth")

	game.queue_free()
	await process_frame
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	_finish()


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures.is_empty():
		print("M2_9_ROOT_SESSION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
