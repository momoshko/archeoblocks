extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_6_progress.cfg"
const CARD_ROOT := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"
const COLLECTION_ROOT := "ContentCenter/PortraitContent/Layout/ArtifactGrid/"

var _failures: Array[String] = []
var _checks := 0
var _chapter: ChapterDefinition


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	_delete_test_progress()
	_chapter = load("res://resources/chapters/ancient_courtyard.tres") as ChapterDefinition
	_test_chapter_content()
	await _test_sequential_unlock_and_finale_return()
	_delete_test_progress()
	await _test_collection_states()
	_delete_test_progress()
	await _test_one_time_chapter_reward()
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_6_CHAPTER_PRODUCT_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_chapter_content() -> void:
	_expect(_chapter != null, "Ancient Courtyard chapter resource should load")
	_expect(_chapter.validate().is_empty(), "Chapter resource should validate")
	_expect(_chapter.title_ru == "Древний двор", "Chapter should use the Ancient Courtyard title")
	_expect(_chapter.expeditions.size() == 6, "Chapter I should contain exactly six expeditions")
	var expected_artifacts := [
		"Печать двора",
		"Каменный амулет",
		"Бронзовый ключ",
		"Мозаичная табличка",
		"Фигурка хранителя",
		"Золотая маска",
	]
	var expected_ranges := [Vector2i(3, 5), Vector2i(7, 10), Vector2i(10, 15), Vector2i(15, 20), Vector2i(20, 30), Vector2i(30, 40)]
	for index in _chapter.expeditions.size():
		var expedition := _chapter.expeditions[index]
		_expect(expedition.id == StringName("expedition_%02d" % (index + 1)), "Chapter expedition order should be 1 through 6")
		_expect(expedition.artifact_name_ru == expected_artifacts[index], "Expedition should expose its resource-driven artifact identity")
		_expect(expedition.validate().is_empty(), "Expedition %d should validate" % (index + 1))
		_expect(Vector2i(expedition.expected_moves_min, expedition.expected_moves_max) == expected_ranges[index], "Expedition should carry its non-binding pacing target")
		for fragment in expedition.artifact_fragments:
			_expect(fragment.cells.size() == 1, "Every Chapter I logical fragment must map to exactly one target cell")
	_expect(_chapter.expeditions[1].strong_soil_cells.has(Vector2i(4, 4)), "Expedition 2 should teach a depth-2 target")
	_expect(_chapter.expeditions[2].strong_soil_cells.has(Vector2i(3, 3)), "Expedition 3 intersection target should start at depth 2")
	_expect(_chapter.expeditions[5].artifact_id == &"golden_mask", "Expedition 6 should be the Golden Mask finale")
	_expect(_chapter.expeditions[5].artifact_fragments.size() == 3, "Golden Mask finale should have three logical fragments")
	_expect(_chapter.expeditions[0].full_artifact_texture != null and _chapter.expeditions[1].full_artifact_texture != null and _chapter.expeditions[5].full_artifact_texture != null, "Production artwork should remain assigned to Expeditions 1, 2, and 6")
	for index in range(2, 5):
		_expect(_chapter.expeditions[index].full_artifact_texture == null, "Expeditions 3–5 should gracefully retain missing optional art")


func _test_sequential_unlock_and_finale_return() -> void:
	var selector := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	for completed_count in 6:
		selector.refresh_progress()
		for index in 6:
			var button := selector.get_node(CARD_ROOT + "Expedition%02d" % (index + 1)) as Button
			var should_unlock := index <= completed_count
			_expect(button.visible, "All six Chapter I cards should remain visible")
			_expect(button.disabled == not should_unlock, "Only the next sequential expedition should unlock")
			if index < completed_count:
				_expect(button.text.ends_with("✓ Пройдено"), "Completed expedition should show its completed state")
			elif index == completed_count:
				_expect(button.text.ends_with("Открыто"), "Next expedition should show its open state")
		_expect(ProgressStore.mark_expedition_completed(_chapter.expeditions[completed_count].id) == OK, "Sequential completion should persist")
	selector.refresh_progress()
	for index in 6:
		var completed_button := selector.get_node(CARD_ROOT + "Expedition%02d" % (index + 1)) as Button
		_expect(completed_button.text.ends_with("✓ Пройдено"), "All six cards should show completed after the finale")
	selector.queue_free()
	await process_frame

	var finale := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(finale)
	current_scene = finale
	await process_frame
	await process_frame
	_expect(finale.next_expedition_scene_path == "res://scenes/screens/chapter_detail_01.tscn", "Expedition 6 should return to Chapter I detail")
	finale.call("_open_next_expedition")
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "ChapterDetailOne", "Finale Next should return to Chapter I detail")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _test_collection_states() -> void:
	var collection := load("res://scenes/screens/collection.tscn").instantiate() as Control
	root.add_child(collection)
	await process_frame
	var progress := collection.get_node("ContentCenter/PortraitContent/Layout/CollectionProgress") as Label
	_expect(progress.text == "Коллекция: 0 / 6", "Fresh Collection should show 0 / 6")
	for index in 6:
		var name_label := _collection_name(collection, index)
		_expect(name_label.text == "Неизвестная находка", "Unfinished Collection entries should conceal artifact names")

	for expedition in _chapter.expeditions:
		_expect(ProgressStore.mark_expedition_completed(expedition.id) == OK, "Collection fixture completion should save")
	collection.refresh_collection()
	_expect(progress.text == "Коллекция: 6 / 6", "Completed Collection should show 6 / 6")
	for index in 6:
		var expedition := _chapter.expeditions[index]
		var preview := _collection_preview(collection, index)
		_expect(_collection_name(collection, index).text == expedition.artifact_name_ru, "Completed entry should reveal the artifact name")
		if expedition.full_artifact_texture != null:
			_expect(preview.visible and ArtifactTextureUtil.source_texture(preview.texture) == expedition.full_artifact_texture, "Known production art should be reused in Collection")
		else:
			_expect(not preview.visible and preview.texture == null, "Missing optional art should keep the neutral scene placeholder")
	for index in range(6, 12):
		var hidden_card := collection.get_node(COLLECTION_ROOT + "Artifact%02d" % (index + 1)) as Control
		_expect(not hidden_card.visible, "Future collection slots should stay hidden instead of appearing as Chapter I entries")
	collection.queue_free()
	await process_frame


func _test_one_time_chapter_reward() -> void:
	for index in 5:
		_expect(ProgressStore.mark_expedition_completed(_chapter.expeditions[index].id) == OK, "Pre-finale completion should persist")
	var premature := ProgressStore.claim_chapter_reward(_chapter.id, _chapter.expedition_ids(), 100)
	_expect(not premature.granted and ProgressStore.get_coin_balance() == 0, "Chapter reward must not grant before all six expeditions")

	var finale := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(finale)
	await process_frame
	await process_frame
	var session := finale.get_node("GameSession") as GameSession
	session._finish_victory()
	var popup := finale.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(ProgressStore.is_expedition_completed(&"expedition_06"), "Finale victory should persist Expedition 6")
	_expect(ProgressStore.is_chapter_reward_claimed(_chapter.id), "Finale victory should persist the claimed chapter reward")
	_expect(ProgressStore.get_coin_balance() == 100, "Chapter completion should add exactly 100 persistent coins")
	_expect(popup.chapter_complete.visible, "Finale result should include chapter-complete feedback")
	_expect(popup.chapter_title.text == "Древний двор исследован", "Chapter feedback should identify the completed location")
	_expect(popup.chapter_progress.text == "Коллекция 6/6", "Chapter feedback should show the completed collection")
	_expect(popup.chapter_reward.text == "Награда главы: +100 монет", "First completion should display the granted reward")
	finale.queue_free()
	await process_frame

	var replay := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(replay)
	await process_frame
	await process_frame
	(replay.get_node("GameSession") as GameSession)._finish_victory()
	var replay_popup := replay.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(ProgressStore.get_coin_balance() == 100, "Replaying the finale must not duplicate the 100-coin reward")
	_expect(replay_popup.chapter_reward.text == "Награда главы уже получена", "Replay feedback should clearly avoid claiming a second reward")
	_expect(ProgressStore.completed_expeditions().size() == 6, "Reloaded progress should preserve all six completions")
	replay.queue_free()
	await process_frame


func _collection_name(collection: Control, index: int) -> Label:
	return collection.get_node(COLLECTION_ROOT + "Artifact%02d/Layout/ArtifactName" % (index + 1)) as Label


func _collection_preview(collection: Control, index: int) -> TextureRect:
	return collection.get_node(COLLECTION_ROOT + "Artifact%02d/Layout/ArtifactVisual/ArtifactPreview" % (index + 1)) as TextureRect


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
