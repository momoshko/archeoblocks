extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_9_root_access_progress.cfg"

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
	var chapter_one := load("res://resources/chapters/ancient_courtyard.tres") as ChapterDefinition
	var chapter_two := load("res://resources/chapters/ruined_shrine.tres") as ChapterDefinition
	for expedition in chapter_one.expeditions:
		_expect(expedition.root_obstacles.is_empty(), "Chapter I must remain Root-free")
	for expedition in chapter_two.expeditions:
		_expect(expedition.root_obstacles.is_empty(), "Chapter II must remain Root-free")

	var selector := load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	_expect(not selector.chapter_three_button.visible, "Chapter III prototype entry should stay hidden before Chapter II completion")
	selector.queue_free()
	await process_frame
	for expedition in chapter_two.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	selector = load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	_expect(selector.chapter_three_button.visible and not selector.chapter_three_button.disabled, "Chapter III prototype should appear after Chapter II completion")
	_expect(selector.chapter_three_button.text.contains("Глава III · прототип") and selector.chapter_three_button.text.contains("Заросшие катакомбы"), "Prototype entry should expose accepted product naming")
	selector.queue_free()
	await process_frame

	var detail := load("res://scenes/screens/chapter_detail_03_prototype.tscn").instantiate() as Control
	root.add_child(detail)
	await process_frame
	var visible_cards := 0
	for button in detail.expedition_buttons:
		if button.visible:
			visible_cards += 1
	_expect(visible_cards == 1 and detail.expedition_buttons[0].text.contains("Живые корни"), "Prototype detail should contain exactly one expedition")
	_expect(not detail.reward_label.visible, "Prototype chapter should not advertise a chapter reward")
	detail.queue_free()
	await process_frame

	var game := load("res://scenes/screens/game_screen_ch3_prototype_01.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var artifact_root_cell := session.board_view.get_cell_view(Vector2i(6, 5))
	_expect(artifact_root_cell.root_obstacle.visible and artifact_root_cell.artifact_target_border.visible, "Artifact target marker should remain visible on a Root cell")
	_expect(artifact_root_cell.artifact_target_border.z_index > artifact_root_cell.root_obstacle.z_index, "Artifact marker should render above Root")
	var warning_cell := session.board_view.get_cell_view(session.get_root_threat_cell())
	_expect(warning_cell.root_growth_warning.visible, "Scene-authored warning should appear on threatened cell")
	_expect(warning_cell.root_growth_warning.z_index > warning_cell.artifact_target_border.z_index, "Growth warning layer should remain above artifact marker")
	_expect(session.expedition_definition.instruction_ru == "Корни расползаются после хода. Разрушайте их линиями или перекрывайте путь.", "Prototype should use one concise onboarding line")
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
		print("M2_9_ROOT_ACCESS_VISUAL_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
