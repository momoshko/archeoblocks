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
	await _test_cell_layers_and_state_mapping()
	await _test_block_color_mapping()
	await _test_tray_and_drag_blocks()
	if _failures.is_empty():
		print("M2_5A3_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_cell_layers_and_state_mapping() -> void:
	var cell := load("res://scenes/game/cell_view.tscn").instantiate() as CellView
	root.add_child(cell)
	await process_frame
	_expect(cell.background is TextureRect, "Depth 0 base should be a TextureRect")
	_expect(cell.soil_visual is TextureRect, "Depth 1 base should be a TextureRect")
	_expect(cell.strong_soil_visual is TextureRect, "Depth 2 base should be a TextureRect")
	_expect(cell.artifact_hint.z_index < cell.block_visual.z_index, "Artifact presentation must render below blocks")
	_expect(cell.block_visual.z_index < cell.valid_preview.z_index, "Blocks must render below placement previews")
	_expect(cell.valid_preview.z_index < cell.artifact_target_border.z_index, "Artifact target marker must remain above placement previews")
	_expect(not cell.has_node("ArtifactHint/ArtifactDepth1Clip"), "Board cells must not contain full depth-1 artifact artwork")
	_expect(not cell.has_node("ArtifactHint/ArtifactRevealedClip"), "Board cells must not contain full revealed artifact artwork")

	cell.set_excavation_state(2, true, false, false)
	_expect(cell.strong_soil_visual.visible and not cell.soil_visual.visible and not cell.background.visible, "Depth 2 should select strong soil only")
	_expect(cell.burial_depth_2.visible and not cell.burial_depth_1.visible, "Depth 2 artifact should use the generic deep hint")
	_expect(cell.artifact_target_border.visible, "Unfinished depth-2 artifact cell should keep a target marker")

	cell.set_excavation_state(1, true, false, false)
	_expect(cell.soil_visual.visible and not cell.strong_soil_visual.visible and not cell.background.visible, "Depth 1 should select normal soil only")
	_expect(cell.burial_depth_1.visible and not cell.burial_depth_2.visible, "Depth 1 should use only the generic opening overlay")
	_expect(cell.artifact_target_border.visible, "Unfinished depth-1 artifact cell should keep a target marker")

	cell.set_excavation_state(0, true, true, false)
	_expect(cell.background.visible and not cell.soil_visual.visible and not cell.strong_soil_visual.visible, "Depth 0 should select the excavated base only")
	_expect(not cell.artifact_hint.visible and not cell.artifact_target_border.visible, "Completed target should have no burial art or target marker")

	cell.set_preview(true, Color.RED)
	_expect(cell.valid_preview.visible and not cell.invalid_preview.visible, "Valid preview should use only the approved valid overlay")
	cell.set_preview(false, Color.GREEN)
	_expect(cell.invalid_preview.visible and not cell.valid_preview.visible, "Invalid preview should use only the approved invalid overlay")
	cell.queue_free()
	await process_frame


func _test_block_color_mapping() -> void:
	var cell := load("res://scenes/game/cell_view.tscn").instantiate() as CellView
	root.add_child(cell)
	await process_frame
	var cases := [
		[Color(0.239216, 0.552941, 0.341176, 1), "block_green_v1.png"],
		[Color(0.2, 0.443137, 0.67451, 1), "block_blue_v1.png"],
		[Color(0.74902, 0.301961, 0.2, 1), "block_red_v1.png"],
		[Color(0.870588, 0.631373, 0.137255, 1), "block_amber_v1.png"],
	]
	for test_case in cases:
		cell.set_occupied(test_case[0])
		_expect(
			cell.block_visual.texture.resource_path.ends_with(test_case[1]),
			"Gameplay color should resolve to %s" % test_case[1]
		)
	cell.set_excavation_state(1, false)
	cell.set_occupied(Color(0.239216, 0.552941, 0.341176, 1))
	_expect(cell.soil_visual.visible and cell.block_visual.visible, "Block should compose above soil without replacing it")
	cell.set_empty()
	_expect(not cell.block_visual.visible and cell.soil_visual.visible, "Clearing a block must leave the terrain layer intact")
	cell.queue_free()
	await process_frame


func _test_tray_and_drag_blocks() -> void:
	var definition := load("res://resources/pieces/small_t.tres") as PieceDefinition
	var expected := load("res://assets/blocks/core_blocks_pack_v1/block_red_v1.png") as Texture2D
	var slot := load("res://scenes/game/piece_slot.tscn").instantiate() as PieceSlot
	root.add_child(slot)
	await process_frame
	slot.set_definition(definition)
	await process_frame
	var tray_cell := slot.get_node("SlotLayout/PieceCanvas/PieceCell01") as TextureRect
	_expect(tray_cell.visible and tray_cell.texture == expected, "Tray should compose pieces from approved single-cell block sprites")

	var drag := load("res://scenes/ui/drag_piece_preview.tscn").instantiate() as DragPiecePreview
	root.add_child(drag)
	await process_frame
	drag.show_definition(definition, Vector2(60, 60), Vector2(65, 65))
	var drag_cell := drag.get_node("PreviewCell01") as TextureRect
	_expect(drag_cell.visible and drag_cell.texture == expected, "Drag representation should use the same block sprite as tray and board")
	drag.set_valid(false)
	_expect(drag_cell.modulate.r > drag_cell.modulate.g, "Invalid floating drag state should remain visibly tinted while board uses the X overlay")
	slot.queue_free()
	drag.queue_free()
	await process_frame
