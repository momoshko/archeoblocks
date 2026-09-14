extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_8_campaign_progress.cfg"
const CHAPTER_ONE_PATH := "res://resources/chapters/ancient_courtyard.tres"
const CHAPTER_TWO_PATH := "res://resources/chapters/ruined_shrine.tres"
const CHAPTER_TWO_CARD_ROOT := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"
const COLLECTION_TWO_ROOT := "ContentCenter/PortraitContent/Layout/ChapterTwoSection/ArtifactGrid/"

var _failures: Array[String] = []
var _checks := 0
var _chapter_one: ChapterDefinition
var _chapter_two: ChapterDefinition


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	_delete_progress()
	_chapter_one = load(CHAPTER_ONE_PATH) as ChapterDefinition
	_chapter_two = load(CHAPTER_TWO_PATH) as ChapterDefinition
	_test_campaign_resources()
	await _test_unlock_sequence()
	_delete_progress()
	await _test_collection_and_placeholders()
	_delete_progress()
	await _test_finale_reward_and_return()
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_8_CAMPAIGN_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_campaign_resources() -> void:
	_expect(_chapter_two != null, "Chapter II resource should load")
	_expect(_chapter_two.validate().is_empty(), "Chapter II resource should validate")
	_expect(_chapter_two.number_ru == "Глава II", "Chapter II number should be resource-driven")
	_expect(_chapter_two.title_ru == "Разрушенное святилище", "Chapter II should use the accepted location title")
	_expect(_chapter_two.expeditions.size() == 8, "Chapter II should contain exactly eight expeditions")
	_expect(_chapter_two.completion_reward_coins == 150, "Chapter II completion reward should be 150 coins")
	var expected_names := [
		"Каменный оберег",
		"Бронзовый колокольчик",
		"Печать жреца",
		"Обломок стелы",
		"Ритуальный браслет",
		"Сосуд для благовоний",
		"Алтарный медальон",
		"Идол святилища",
	]
	var expected_ranges := [
		Vector2i(8, 12), Vector2i(12, 18), Vector2i(15, 22), Vector2i(18, 25),
		Vector2i(22, 30), Vector2i(25, 35), Vector2i(30, 40), Vector2i(35, 50),
	]
	for index in _chapter_two.expeditions.size():
		var expedition := _chapter_two.expeditions[index]
		_expect(expedition.id == StringName("ruined_shrine_%02d" % (index + 1)), "Chapter II expedition ids should be sequential")
		_expect(expedition.artifact_name_ru == expected_names[index], "Every Chapter II expedition should expose its artifact identity")
		_expect(expedition.validate().is_empty(), "Chapter II expedition %d should validate" % (index + 1))
		_expect(Vector2i(expedition.expected_moves_min, expedition.expected_moves_max) == expected_ranges[index], "Chapter II expedition should retain its pacing target")
		_expect(expedition.opening_piece_set.size() == 3, "Every Chapter II opening should be curated")
		_expect(not expedition.curated_piece_sequence.is_empty() and expedition.curated_piece_sequence.size() % 3 == 0, "Every Chapter II refill cycle should be curated in triples")
		for fragment in expedition.artifact_fragments:
			_expect(fragment.cells.size() == 1, "Chapter II logical fragments must remain one target cell each")
		var board := BoardModel.new()
		var obstacles := ObstacleModel.new()
		obstacles.load_expedition(expedition)
		for piece in expedition.opening_piece_set:
			_expect(obstacles.has_legal_placement(board, piece.cells), "Every opening piece should have legal space on the initial board")
		var sequence := PieceSequence.new()
		sequence.configure(expedition.curated_piece_sequence)
		var first_refill := sequence.next_set()
		var second_refill := sequence.peek_next_set()
		_expect(first_refill.size() == 3 and first_refill[0] == expedition.curated_piece_sequence[0], "Curated refill should return exactly its first resource-authored triple")
		_expect(second_refill.size() == 3 and second_refill[0] == expedition.curated_piece_sequence[3], "Curated refill should advance deterministically to the next triple")
	_expect(_chapter_two.expeditions[2].stone_obstacles.any(func(stone: StoneObstacleDefinition) -> bool: return stone.durability == 2), "Expedition 2-3 should introduce reinforced Stone")
	_expect(_chapter_two.expeditions[3].stone_obstacles.any(func(stone: StoneObstacleDefinition) -> bool: return _is_artifact_cell(_chapter_two.expeditions[3], stone.cell)), "Expedition 2-4 should place artifact targets under Stone")
	_expect(_chapter_two.expeditions[4].stone_obstacles.size() > _chapter_two.expeditions[3].stone_obstacles.size(), "Expedition 2-5 should increase corridor pressure instead of only soil depth")
	_expect(_chapter_two.expeditions[7].artifact_fragments.size() == 3, "Finale should use three logical fragments")


func _test_unlock_sequence() -> void:
	var selector := load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	var chapter_two_button := selector.get_node("ContentCenter/PortraitContent/Layout/ChapterList/ChapterTwoButton") as Button
	_expect(chapter_two_button.visible and chapter_two_button.disabled, "Chapter II should be visible but locked before Ancient Courtyard is complete")
	for expedition in _chapter_one.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	selector.refresh_progress()
	_expect(not chapter_two_button.disabled, "Ancient Courtyard completion should unlock Chapter II")
	selector.queue_free()
	await process_frame

	var detail := load("res://scenes/screens/chapter_detail_02.tscn").instantiate() as Control
	root.add_child(detail)
	await process_frame
	for completed_count in 8:
		detail.refresh_progress()
		for index in 8:
			var button := _chapter_two_button(detail, index)
			var should_unlock := index <= completed_count
			_expect(button.disabled == not should_unlock, "Only the next Chapter II expedition should unlock")
			if index < completed_count:
				_expect(button.text.ends_with("✓ Пройдено"), "Completed Chapter II cards should show their completed state")
			elif index == completed_count:
				_expect(button.text.ends_with("Открыто"), "The next Chapter II card should show Open")
		ProgressStore.mark_expedition_completed(_chapter_two.expeditions[completed_count].id)
	detail.refresh_progress()
	for index in 8:
		_expect(_chapter_two_button(detail, index).text.ends_with("✓ Пройдено"), "All Chapter II cards should remain replayable after completion")
	detail.queue_free()
	await process_frame


func _test_collection_and_placeholders() -> void:
	var collection := load("res://scenes/screens/collection.tscn").instantiate() as Control
	root.add_child(collection)
	await process_frame
	var progress := collection.get_node("ContentCenter/PortraitContent/Layout/ChapterTwoSection/CollectionProgress") as Label
	_expect(progress.text == "Коллекция: 0 / 8", "Fresh Chapter II Collection should show 0 / 8")
	for index in 8:
		var card := _chapter_two_collection_card(collection, index)
		var preview := card.get_node("Layout/ArtifactVisual/ArtifactPreview") as TextureRect
		var artifact_name := card.get_node("Layout/ArtifactName") as Label
		_expect(artifact_name.text == "Неизвестная находка", "Undiscovered Chapter II entries should conceal names")
		_expect(not preview.visible and preview.texture == null, "Missing Chapter II art should use the neutral scene placeholder")
	for expedition in _chapter_two.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	collection.refresh_collection()
	_expect(progress.text == "Коллекция: 8 / 8", "Completed Chapter II Collection should show 8 / 8")
	for index in 8:
		var card := _chapter_two_collection_card(collection, index)
		var preview := card.get_node("Layout/ArtifactVisual/ArtifactPreview") as TextureRect
		var artifact_name := card.get_node("Layout/ArtifactName") as Label
		_expect(artifact_name.text == _chapter_two.expeditions[index].artifact_name_ru, "Discovery should reveal the resource-driven Chapter II artifact name")
		_expect(not preview.visible and preview.texture == null, "A discovered artifact without art should keep a safe neutral placeholder")
	collection.queue_free()
	await process_frame


func _test_finale_reward_and_return() -> void:
	for expedition in _chapter_one.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	for index in 7:
		ProgressStore.mark_expedition_completed(_chapter_two.expeditions[index].id)
	var premature := ProgressStore.claim_chapter_reward(_chapter_two.id, _chapter_two.expedition_ids(), 150)
	_expect(not premature.granted and ProgressStore.get_coin_balance() == 0, "Chapter II reward must not grant before the finale")

	var finale := load("res://scenes/screens/game_screen_ch2_08.tscn").instantiate() as Control
	root.add_child(finale)
	await process_frame
	await process_frame
	var session := finale.get_node("GameSession") as GameSession
	session._finish_victory()
	var popup := finale.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(ProgressStore.is_expedition_completed(&"ruined_shrine_08"), "Finale victory should persist Expedition 2-8")
	_expect(ProgressStore.is_chapter_reward_claimed(_chapter_two.id), "Finale should persist the Chapter II reward claim")
	_expect(ProgressStore.get_coin_balance() == 150, "Chapter II completion should add exactly 150 coins")
	_expect(popup.chapter_title.text == "Разрушенное святилище исследовано", "Finale should show the exact Chapter II completion title")
	_expect(popup.chapter_progress.text == "Коллекция 8/8", "Finale should show Collection 8/8")
	_expect(popup.chapter_reward.text == "Награда главы: +150 монет", "First completion should show the granted 150-coin reward")
	_expect(finale.next_expedition_scene_path == "res://scenes/screens/chapter_detail_02.tscn", "Chapter II finale should return to its own chapter detail")
	finale.queue_free()
	await process_frame

	var replay := load("res://scenes/screens/game_screen_ch2_08.tscn").instantiate() as Control
	root.add_child(replay)
	await process_frame
	await process_frame
	(replay.get_node("GameSession") as GameSession)._finish_victory()
	_expect(ProgressStore.get_coin_balance() == 150, "Replaying Expedition 2-8 must not duplicate the reward")
	_expect((replay.get_node("ModalUI/ResultPopup") as ResultPopup).chapter_reward.text == "Награда главы уже получена", "Replay should report the already-claimed reward")
	current_scene = replay
	replay.call("_open_next_expedition")
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "ChapterDetailTwo", "Chapter II finale Next should return to Chapter II detail")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame


func _chapter_two_button(detail: Control, index: int) -> Button:
	return detail.get_node(CHAPTER_TWO_CARD_ROOT + "Expedition%02d" % (index + 1)) as Button


func _chapter_two_collection_card(collection: Control, index: int) -> Control:
	return collection.get_node(COLLECTION_TWO_ROOT + "ShrineArtifact%02d" % (index + 1)) as Control


func _is_artifact_cell(expedition: ExpeditionDefinition, cell: Vector2i) -> bool:
	for fragment in expedition.artifact_fragments:
		if fragment.cells.has(cell):
			return true
	return false


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
