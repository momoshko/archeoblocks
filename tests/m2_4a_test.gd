extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_4a_test_progress.cfg"

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
	var expedition_1 := load("res://resources/expeditions/expedition_01.tres") as ExpeditionDefinition
	var expedition_2 := load("res://resources/expeditions/expedition_02.tres") as ExpeditionDefinition
	var expedition_3 := load("res://resources/expeditions/expedition_03.tres") as ExpeditionDefinition
	_test_content_resources(expedition_1, expedition_2, expedition_3)
	_test_strong_soil_lesson(expedition_2)
	await _test_selection_and_scene_binding(expedition_1, expedition_2, expedition_3)
	await _test_first_expedition_line_clear(expedition_1)
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_4A_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_content_resources(
	expedition_1: ExpeditionDefinition,
	expedition_2: ExpeditionDefinition,
	expedition_3: ExpeditionDefinition
) -> void:
	var expeditions: Array[ExpeditionDefinition] = [expedition_1, expedition_2, expedition_3]
	for index in expeditions.size():
		var expedition := expeditions[index]
		_expect(expedition != null, "Expedition %d resource should load" % (index + 1))
		_expect(expedition.validate().is_empty(), "Expedition %d resource should validate" % (index + 1))
		_expect(expedition.title_ru.begins_with("Древний двор %d" % (index + 1)), "Expedition %d should belong to Ancient Courtyard" % (index + 1))
		_expect(not expedition.objective_ru.is_empty() and not expedition.instruction_ru.is_empty(), "Expedition %d should provide short instructional copy" % (index + 1))

	_expect(expedition_1.artifact_fragments.size() == 1, "Expedition 1 should use one forgiving artifact target")
	_expect(expedition_1.normal_soil_cells.size() == 8 and expedition_1.strong_soil_cells.is_empty(), "Expedition 1 should present one simple normal-soil line")
	_expect(_definition_ids(expedition_1.opening_piece_set) == [&"line_3_horizontal", &"line_3_horizontal", &"domino_horizontal"], "Expedition 1 opening should exactly fill a row when used together")
	_expect(expedition_2.artifact_fragments.size() == 1 and expedition_2.strong_soil_cells == [Vector2i(4, 4)], "Expedition 2 should focus one depth-2 artifact target")
	_expect(expedition_2.opening_piece_set.size() == 3, "Expedition 2 should keep a curated deterministic opening")
	_expect(expedition_3.artifact_id == &"bronze_key" and expedition_3.artifact_fragments.size() == 1, "Expedition 3 should teach the intersection with one Bronze Key target")
	_expect(_fragment_cell_count(expedition_3) == 1 and expedition_3.strong_soil_cells == [Vector2i(3, 3)], "Expedition 3 should map its logical fragment to one depth-2 target")


func _test_strong_soil_lesson(expedition: ExpeditionDefinition) -> void:
	var model := ExcavationModel.new()
	_expect(model.load_expedition(expedition).is_empty(), "Expedition 2 should load into ExcavationModel")
	var target := Vector2i(4, 4)
	var row: Array[int] = [4]
	var no_columns: Array[int] = []
	var hit_map := ExcavationModel.build_line_hit_map(row, no_columns)
	model.apply_hit_map_detailed(hit_map)
	_expect(model.get_soil_depth(target) == 1, "One line should leave one layer on Expedition 2 strong soil")
	_expect(model.collect_newly_completed_fragments().is_empty(), "Expedition 2 artifact should remain buried after one hit")
	model.apply_hit_map_detailed(hit_map)
	_expect(model.get_soil_depth(target) == 0, "A second relevant line should remove the final strong-soil layer")
	_expect(model.collect_newly_completed_fragments() == [&"stone_amulet"], "Second hit should complete the Expedition 2 artifact")


func _test_selection_and_scene_binding(
	expedition_1: ExpeditionDefinition,
	expedition_2: ExpeditionDefinition,
	expedition_3: ExpeditionDefinition
) -> void:
	var selector := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	var card_root := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"
	var first := selector.get_node(card_root + "Expedition01") as Button
	var second := selector.get_node(card_root + "Expedition02") as Button
	var third := selector.get_node(card_root + "Expedition03") as Button
	var fourth := selector.get_node(card_root + "Expedition04") as Button
	_expect(not first.disabled, "First Ancient Courtyard expedition should start selectable")
	_expect(second.disabled and third.disabled, "Later onboarding expeditions should unlock in sequence")
	_expect(fourth.disabled, "Expedition 4 should remain locked until Expedition 3 is complete")
	_expect(not first.text.contains("Древний двор") and not second.text.contains("Древний двор") and not third.text.contains("Древний двор"), "Onboarding cards should not repeat the location header")
	await _remove_scene(selector)

	var scene_paths := [
		"res://scenes/screens/game_screen.tscn",
		"res://scenes/screens/game_screen_02.tscn",
		"res://scenes/screens/game_screen_03.tscn",
	]
	var definitions: Array[ExpeditionDefinition] = [expedition_1, expedition_2, expedition_3]
	for index in scene_paths.size():
		var game := load(scene_paths[index]).instantiate() as Control
		root.add_child(game)
		await process_frame
		await process_frame
		var session := game.get_node("GameSession") as GameSession
		_expect(session.expedition_definition == definitions[index], "GameScreen %d should bind the matching expedition resource" % (index + 1))
		_expect(session.expedition_title.text == definitions[index].title_ru, "GameScreen %d should show its resource title" % (index + 1))
		_expect(session.objective_text.text == definitions[index].objective_ru and session.instruction_text.text == definitions[index].instruction_ru, "GameScreen %d should show its short resource instructions" % (index + 1))
		await _remove_scene(game)


func _test_first_expedition_line_clear(expedition: ExpeditionDefinition) -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var board := game.get_node("ContentCenter/PortraitContent/MainLayout/BoardFrame/Board") as BoardView
	var tray := game.get_node("ContentCenter/PortraitContent/MainLayout/PieceTray") as PieceTray
	_expect(session.expedition_definition == expedition, "Expedition 1 smoke should use the first curated resource")
	_expect(_definition_ids(tray.remaining_definitions()) == [&"line_3_horizontal", &"line_3_horizontal", &"domino_horizontal"], "Expedition 1 should start with the curated row-building pieces")
	_expect(session.try_place_piece(0, Vector2i(0, 3)), "First tutorial piece should place on the soil row")
	_expect(session.try_place_piece(1, Vector2i(3, 3)), "Second tutorial piece should continue the row")
	_expect(session.try_place_piece(2, Vector2i(6, 3)), "Third tutorial piece should complete the row")
	await create_timer(board.clear_feedback_duration + 1.35).timeout
	_expect(session.excavation_model.get_soil_depth(Vector2i(3, 3)) == 0, "Completed line should remove Expedition 1 soil")
	_expect(session.excavation_model.all_fragments_complete(), "Completed tutorial line should uncover the first artifact")
	_expect(session.result_popup.visible, "Expedition 1 completion should use the existing victory flow")
	await _remove_scene(game)
	current_scene = null


func _remove_scene(node: Node) -> void:
	if is_instance_valid(node) and node.get_parent() == root:
		root.remove_child(node)
		node.queue_free()
	await process_frame


func _definition_ids(definitions: Array[PieceDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in definitions:
		ids.append(definition.id)
	return ids


func _fragment_cell_count(expedition: ExpeditionDefinition) -> int:
	var count := 0
	for fragment in expedition.artifact_fragments:
		count += fragment.cells.size()
	return count


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
