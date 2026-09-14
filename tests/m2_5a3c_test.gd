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
	await _test_primary_marker_shape_and_block_coverage()
	await _test_intro_pulse_once()
	_test_useful_drag_prediction_stays_specific()
	await _test_modal_cleanup_keeps_persistent_marker()
	if _failures.is_empty():
		print("M2_5A3C_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_primary_marker_shape_and_block_coverage() -> void:
	var cell := load("res://scenes/game/cell_view.tscn").instantiate() as CellView
	root.add_child(cell)
	await process_frame
	cell.set_excavation_state(2, true, false)
	cell.set_occupied(Color(0.2, 0.443137, 0.67451, 1))
	_expect(cell.artifact_target_border.visible, "Artifact target marker must remain visible over a colored block")
	_expect(cell.artifact_target_border.z_index > cell.block_visual.z_index, "Artifact target marker must draw above blocks")
	_expect(cell.has_node("ArtifactTargetBorder/TargetRing"), "Primary marker needs a central ring shape")
	_expect(cell.has_node("ArtifactTargetBorder/TargetRing/TargetDiamond"), "Primary marker needs a non-color diamond cue")
	var depth_2_alpha := cell.artifact_target_border.modulate.a
	cell.set_excavation_state(1, true, false)
	_expect(cell.artifact_target_border.modulate.a > depth_2_alpha, "Depth 1 marker should be brighter than depth 2")
	cell.set_artifact_target_emphasized(true)
	_expect(cell.artifact_target_prediction.visible, "Useful drag state must add the stronger emphasis layer")
	cell.set_artifact_target_emphasized(false)
	_expect(not cell.artifact_target_prediction.visible and cell.artifact_target_border.visible, "Leaving useful drag must restore only the persistent marker")
	cell.queue_free()
	await process_frame


func _test_intro_pulse_once() -> void:
	var board := load("res://scenes/game/board_view.tscn").instantiate() as BoardView
	root.add_child(board)
	await process_frame
	var target := board.get_cell_view(Vector2i(1, 1))
	target.set_excavation_state(2, true, false)
	board.play_artifact_targets_intro()
	var first_tween: Tween = target._artifact_intro_tween
	_expect(board.has_artifact_targets_intro_played(), "Board should remember that the one-time intro reveal has played")
	_expect(target.is_artifact_target_intro_active(), "Level start should briefly pulse current artifact targets")
	board.play_artifact_targets_intro()
	_expect(target._artifact_intro_tween == first_tween, "Repeated intro requests must not restart or stack pulses")
	await create_timer(target.artifact_intro_pulse_duration + 0.1).timeout
	_expect(not target.is_artifact_target_intro_active(), "Intro reveal must finish instead of looping")
	_expect(target.artifact_target_border.visible and not target.artifact_target_prediction.visible, "Persistent marker must remain after intro settles")
	board.queue_free()
	await process_frame


func _test_useful_drag_prediction_stays_specific() -> void:
	var session := GameSession.new()
	var definition := load("res://resources/pieces/single.tres") as PieceDefinition
	var expedition := load("res://resources/expeditions/expedition_06.tres") as ExpeditionDefinition
	_expect(session.excavation_model.load_expedition(expedition).is_empty(), "Prediction fixture expedition must be valid")
	for x in 7:
		session.board_model.place(definition.cells, Vector2i(x, 1), Color.WHITE)
	var targets: Array[Vector2i] = session._predict_artifact_hit_cells(definition, Vector2i(7, 1))
	_expect(targets == [Vector2i(1, 1)], "A real excavation line must identify its one Chapter I artifact target")
	_expect(session._predict_artifact_hit_cells(definition, Vector2i(7, 2)).is_empty(), "A placement without a target excavation line must not trigger emphasis")
	session.free()


func _test_modal_cleanup_keeps_persistent_marker() -> void:
	var screen: Node = load("res://scenes/screens/game_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var session := screen.get_node("GameSession") as GameSession
	var cell := screen.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board/BoardContentCenter/Grid/Cell10") as CellView
	cell.set_excavation_state(2, true, false)
	cell.play_artifact_target_intro()
	cell.set_artifact_target_emphasized(true)
	session.set_input_blocked(true)
	_expect(not cell.is_artifact_target_intro_active(), "Modal cleanup must stop intro target animation")
	_expect(not cell.artifact_target_prediction.visible, "Modal cleanup must remove useful-drag emphasis")
	_expect(cell.artifact_target_border.visible, "Modal cleanup must preserve the strategic target marker")
	_expect(cell.artifact_target_border.z_index < (screen.get_node("ModalUI") as CanvasLayer).layer, "Target marker must remain below modal UI")
	screen.queue_free()
	await process_frame
