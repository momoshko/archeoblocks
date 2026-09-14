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
	await _test_modal_layer_contract_and_cleanup()
	await _test_persistent_artifact_target_marker()
	_test_useful_drag_prediction()
	_test_scene_authored_grid_spacing()
	if _failures.is_empty():
		print("M2_5A3B_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_modal_layer_contract_and_cleanup() -> void:
	var screen: Node = load("res://scenes/screens/game_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var modal_layer := screen.get_node("ModalUI") as CanvasLayer
	var cell := screen.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board/BoardContentCenter/Grid/Cell01") as CellView
	var drag_preview := screen.get_node("DragPreview") as DragPiecePreview
	var feedback := screen.get_node("FeedbackUI/ActionFeedback") as ActionFeedback
	var session := screen.get_node("GameSession") as GameSession
	_expect(modal_layer.layer == 10, "Modal UI must live on its dedicated high CanvasLayer")
	_expect(cell.selection_highlight.z_index < modal_layer.layer, "Gameplay-local z values must stay below the modal layer contract")
	_expect(drag_preview.z_index < modal_layer.layer, "Drag ghost must stay below modal UI")

	cell.set_excavation_state(1, true, false)
	cell.set_preview(true, Color.WHITE)
	cell.set_hint_highlight(true)
	cell.play_dig_feedback()
	cell.set_artifact_target_emphasized(true)
	drag_preview.show_definition(load("res://resources/pieces/single.tres"), Vector2(60, 60), Vector2(63, 63))
	feedback.show_message("TEMP")
	session.set_input_blocked(true)
	_expect(not drag_preview.visible, "Opening a modal must clear the drag ghost")
	_expect(not cell.valid_preview.visible and not cell.invalid_preview.visible, "Opening a modal must clear board placement previews")
	_expect(not cell.selection_highlight.visible and not cell.dig_flash.visible, "Opening a modal must clear hint and temporary cell feedback")
	_expect(not cell.artifact_target_prediction.visible and cell.artifact_target_border.visible, "Modal cleanup must remove transient emphasis but preserve the target state")
	_expect(not feedback.visible and feedback.queued_message_count() == 0, "Opening a modal must clear action feedback and its queue")
	screen.queue_free()
	await process_frame


func _test_persistent_artifact_target_marker() -> void:
	var cell := load("res://scenes/game/cell_view.tscn").instantiate() as CellView
	root.add_child(cell)
	await process_frame
	cell.set_excavation_state(2, true, false)
	cell.set_occupied(Color(0.239216, 0.552941, 0.341176, 1))
	_expect(cell.artifact_target_border.visible, "Artifact target marker must remain visible above an occupying block")
	_expect(cell.artifact_target_border.z_index > cell.block_visual.z_index, "Artifact target marker must draw above the block")
	var depth_2_alpha := cell.artifact_target_border.modulate.a
	cell.set_excavation_state(1, true, false)
	_expect(cell.artifact_target_border.modulate.a > depth_2_alpha, "Depth 1 target marker should be stronger than depth 2")
	cell.set_artifact_target_emphasized(true)
	_expect(cell.artifact_target_prediction.visible, "Useful drag should enable a distinct marker emphasis")
	cell.set_artifact_target_emphasized(false)
	_expect(not cell.artifact_target_prediction.visible and cell.artifact_target_border.visible, "Ending drag should restore the persistent marker")
	cell.set_excavation_state(0, true, true)
	_expect(not cell.artifact_target_border.visible, "Completed target marker must disappear")
	cell.queue_free()
	await process_frame


func _test_useful_drag_prediction() -> void:
	var session := GameSession.new()
	var definition := load("res://resources/pieces/single.tres") as PieceDefinition
	var expedition := load("res://resources/expeditions/expedition_06.tres") as ExpeditionDefinition
	_expect(session.excavation_model.load_expedition(expedition).is_empty(), "Prediction fixture expedition must be valid")
	for x in 7:
		session.board_model.place(definition.cells, Vector2i(x, 1), Color.WHITE)
	var targets: Array[Vector2i] = session._predict_artifact_hit_cells(definition, Vector2i(7, 1))
	_expect(targets == [Vector2i(1, 1)], "Line-completing drag must identify the one Chapter I target cell that receives an excavation hit")
	_expect(session._predict_artifact_hit_cells(definition, Vector2i(7, 2)).is_empty(), "Valid placement without a completed target line must not emphasize artifact cells")
	session.free()


func _test_scene_authored_grid_spacing() -> void:
	var board := load("res://scenes/game/board_view.tscn").instantiate() as BoardView
	var grid := board.get_node("BoardContentCenter/Grid") as GridContainer
	_expect(grid.get_theme_constant("h_separation") == 3, "Horizontal grid spacing should be scene-authored at 3 px")
	_expect(grid.get_theme_constant("v_separation") == 3, "Vertical grid spacing should be scene-authored at 3 px")
	board.free()
