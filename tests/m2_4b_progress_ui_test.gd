extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_4b_progress_ui_test.cfg"
const CARD_ROOT := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"

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
	await _test_progression_states()
	await _test_collection_preview()
	await _test_responsive_layout(Vector2i(720, 1280), false)
	await _test_responsive_layout(Vector2i(420, 900), true)
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_4B_PROGRESS_UI_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_progression_states() -> void:
	var selector := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	var first := selector.get_node(CARD_ROOT + "Expedition01") as Button
	var second := selector.get_node(CARD_ROOT + "Expedition02") as Button
	var third := selector.get_node(CARD_ROOT + "Expedition03") as Button
	_expect(not first.disabled and first.text.ends_with("Открыто"), "First expedition should start open")
	_expect(second.disabled and second.text.ends_with("Закрыто"), "Second expedition should start locked")
	_expect(third.disabled and third.text.ends_with("Закрыто"), "Third expedition should start locked")
	_expect(not first.text.contains("Древний двор"), "Cards should not repeat the location name")

	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	(game.get_node("GameSession") as GameSession)._finish_victory()
	_expect(ProgressStore.is_expedition_completed(&"expedition_01"), "Victory should persist Expedition 1 completion")
	selector.refresh_progress()
	_expect(first.text.ends_with("✓ Пройдено"), "Completed Expedition 1 should show a checkmark")
	_expect(not second.disabled and second.text.ends_with("Открыто"), "Completing Expedition 1 should unlock Expedition 2")
	_expect(third.disabled, "Expedition 3 should remain locked until Expedition 2 is complete")
	game.queue_free()
	await process_frame

	_expect(ProgressStore.mark_expedition_completed(&"expedition_02") == OK, "Expedition 2 completion should save")
	selector.refresh_progress()
	_expect(not third.disabled and third.text.ends_with("Открыто"), "Completing Expedition 2 should unlock Expedition 3")
	_expect(ProgressStore.mark_expedition_completed(&"expedition_03") == OK, "Expedition 3 completion should save")
	selector.refresh_progress()
	_expect(third.text.ends_with("✓ Пройдено"), "Completed Expedition 3 should show a checkmark")
	selector.queue_free()
	await process_frame


func _test_collection_preview() -> void:
	var expeditions: Array[ExpeditionDefinition] = [
		load("res://resources/expeditions/expedition_01.tres") as ExpeditionDefinition,
		load("res://resources/expeditions/expedition_02.tres") as ExpeditionDefinition,
		load("res://resources/expeditions/expedition_06.tres") as ExpeditionDefinition,
	]
	_expect(ProgressStore.mark_expedition_completed(&"expedition_06") == OK, "Expedition 6 completion should save for Collection artwork")
	var collection := load("res://scenes/screens/collection.tscn").instantiate() as Control
	root.add_child(collection)
	await process_frame
	var collection_slots := [1, 2, 6]
	for index in expeditions.size():
		var expedition := expeditions[index]
		var card_name := "Artifact%02d" % collection_slots[index]
		var card_path := "ContentCenter/PortraitContent/Layout/ArtifactGrid/%s/" % card_name
		var preview := collection.get_node(card_path + "Layout/ArtifactVisual/ArtifactPreview") as TextureRect
		var artifact_name := collection.get_node(card_path + "Layout/ArtifactName") as Label
		_expect(
			preview.visible
			and ArtifactTextureUtil.source_texture(preview.texture) == expedition.full_artifact_texture,
			"Completed collection card should reuse expedition artwork: %s" % expedition.id
		)
		_expect(artifact_name.text == expedition.artifact_name_ru, "Collection should reuse each artifact resource name")
	collection.queue_free()
	await process_frame


func _test_responsive_layout(viewport_size: Vector2i, should_wrap: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)
	var selector := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	viewport.add_child(selector)
	await process_frame
	await process_frame
	var first := selector.get_node(CARD_ROOT + "Expedition01") as Button
	var second := selector.get_node(CARD_ROOT + "Expedition02") as Button
	var third := selector.get_node(CARD_ROOT + "Expedition03") as Button
	var buttons: Array[Button] = [first, second, third]
	for button in buttons:
		var rect: Rect2 = button.get_global_rect()
		_expect(rect.position.x >= -0.5, "Card should not clip past the left edge at %s" % viewport_size)
		_expect(rect.end.x <= viewport_size.x + 0.5, "Card should not clip past the right edge at %s" % viewport_size)
	if should_wrap:
		_expect(second.position.y > first.position.y and third.position.y > second.position.y, "Narrow layout should wrap onboarding cards vertically")
	viewport.queue_free()
	await process_frame


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
