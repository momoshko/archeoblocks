extends SceneTree

const PROGRESS_PATH := "res://tests/.m2_10_progress.cfg"
var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	ProgressStore.storage_path = ProjectSettings.globalize_path(PROGRESS_PATH)
	_delete_progress()
	var chapter := load("res://resources/chapters/overgrown_catacombs.tres") as ChapterDefinition
	_expect(chapter != null and chapter.validate().is_empty(), "Chapter III resource should validate")
	_expect(chapter.expeditions.size() == 10, "Chapter III should contain exactly ten expeditions")
	_expect(chapter.completion_reward_coins == 200, "Chapter III reward should be 200 Coins")
	var names: Dictionary = {}
	for index in chapter.expeditions.size():
		var expedition := chapter.expeditions[index]
		_expect(expedition.validate().is_empty(), "3-%d resource should validate" % (index + 1))
		_expect(expedition.artifact_fragments.size() >= 2 and expedition.artifact_fragments.size() <= 3, "3-%d should use 2-3 logical fragments" % (index + 1))
		_expect(expedition.artifact_fragments.all(func(fragment: ArtifactFragmentDefinition) -> bool: return fragment.cells.size() == 1), "3-%d should keep one target cell per fragment" % (index + 1))
		_expect(not expedition.root_obstacles.is_empty(), "3-%d should include Root pressure" % (index + 1))
		_expect(expedition.curated_piece_sequence.size() % 3 == 0, "3-%d should use complete deterministic piece sets" % (index + 1))
		_expect(not names.has(expedition.artifact_name_ru), "Chapter III artifact names should be distinct")
		names[expedition.artifact_name_ru] = true
		_expect(ResourceLoader.exists("res://scenes/screens/game_screen_ch3_%02d.tscn" % (index + 1)), "3-%d GameScreen should exist" % (index + 1))

	var chapter_two := load("res://resources/chapters/ruined_shrine.tres") as ChapterDefinition
	for expedition in chapter_two.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	var detail := load("res://scenes/screens/chapter_detail_03.tscn").instantiate() as Control
	root.add_child(detail)
	await process_frame
	_expect(detail.chapter_definition == chapter, "Chapter III detail should use the production chapter resource")
	_expect(detail.expedition_buttons.size() == 10, "Chapter detail should expose ten scene-authored buttons")
	_expect(not detail.expedition_buttons[0].disabled and detail.expedition_buttons[1].disabled, "Chapter III expeditions should unlock sequentially")
	detail.queue_free()
	await process_frame

	var collection := load("res://scenes/screens/collection.tscn").instantiate() as Control
	root.add_child(collection)
	await process_frame
	_expect(collection.chapter_three_grid.get_child_count() == 10, "Collection should contain ten Chapter III slots")
	_expect(collection.chapter_three_progress.text == "Коллекция: 0 / 10", "Unknown Chapter III collection should start at 0/10")
	for card in collection.chapter_three_grid.get_children():
		_expect((card.get_node("Layout/ArtifactName") as Label).text == "Неизвестная находка", "Unknown Chapter III entries should use neutral copy")
	collection.queue_free()
	await process_frame

	for expedition in chapter.expeditions:
		_expect(ProgressStore.mark_expedition_completed(expedition.id) == OK, "Chapter III completion should persist")
	var first_reward := ProgressStore.claim_chapter_reward(chapter.id, chapter.expedition_ids(), 200)
	var duplicate_reward := ProgressStore.claim_chapter_reward(chapter.id, chapter.expedition_ids(), 200)
	_expect(first_reward.granted and first_reward.coins == 200, "First Chapter III completion should grant 200 Coins")
	_expect(not duplicate_reward.granted and ProgressStore.get_coin_balance() == 200, "Chapter III reward must not duplicate")

	_expect(GameSession.is_web_debug_hint_toggle_allowed(true, true), "Debug Web semantics should allow the hidden Hint toggle")
	_expect(not GameSession.is_web_debug_hint_toggle_allowed(true, false), "Release Web semantics must reject the hidden Hint toggle")
	_expect(not GameSession.is_web_debug_hint_toggle_allowed(false, true), "Non-Web debug builds must reject the Web tester hotkey")
	_expect(
		not GameSession.should_use_debug_unlimited_hints(true, true, true, false),
		"Debug Web must start with normal Hint rules even when desktop debug unlimited is configured"
	)
	_expect(
		GameSession.should_use_debug_unlimited_hints(true, true, false, true),
		"Debug Web runtime toggle should enable unlimited Hint"
	)
	_expect(
		not GameSession.should_use_debug_unlimited_hints(true, false, true, true),
		"Release Web must never enable unlimited Hint"
	)
	_expect(
		GameSession.should_use_debug_unlimited_hints(false, true, true, false),
		"Desktop debug configuration should remain available"
	)

	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	_finish()


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _finish() -> void:
	if _failures.is_empty():
		print("M2_10_CHAPTER_PRODUCT_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
