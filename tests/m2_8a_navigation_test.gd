extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_8a_navigation_progress.cfg"
const DETAIL_GRID := "ContentCenter/PortraitContent/ExpeditionScroll/ExpeditionGrid/"

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
	await _test_root_and_details()
	await _test_navigation_paths()
	_delete_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("M2_8A_NAVIGATION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_root_and_details() -> void:
	var root_screen := load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(root_screen)
	await process_frame
	var chapter_one_button := root_screen.get_node("ContentCenter/PortraitContent/Layout/ChapterList/ChapterOneButton") as Button
	var chapter_two_button := root_screen.get_node("ContentCenter/PortraitContent/Layout/ChapterList/ChapterTwoButton") as Button
	_expect(chapter_one_button.visible and chapter_two_button.visible, "Chapters root should show exactly the two real chapter entries")
	_expect(chapter_one_button.text.contains("Глава I") and chapter_one_button.text.contains("Древний двор"), "Chapter I root card should identify its chapter")
	_expect(chapter_two_button.text.contains("Глава II") and chapter_two_button.text.contains("Разрушенное святилище"), "Chapter II root card should identify its chapter")
	_expect(chapter_one_button.text.contains("0 / 6") and chapter_one_button.text.contains("+100"), "Chapter I root card should show progress and reward")
	_expect(chapter_two_button.text.contains("0 / 8") and chapter_two_button.text.contains("+150"), "Chapter II root card should show progress and reward")
	_expect(not chapter_one_button.disabled and chapter_two_button.disabled, "Chapter II should remain locked until Chapter I completion")
	root_screen.queue_free()
	await process_frame

	var detail_one := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	root.add_child(detail_one)
	await process_frame
	_expect(_visible_expedition_count(detail_one) == 6, "Chapter I detail should show exactly six expedition cards")
	_expect(not _detail_button(detail_one, 0).disabled and _detail_button(detail_one, 1).disabled, "Chapter I detail should preserve sequential states")
	_expect((detail_one.get_node("ContentCenter/PortraitContent/ExpeditionScroll") as ScrollContainer).get_child_count() == 1, "Chapter detail should use one non-nested expedition scroll")
	detail_one.queue_free()
	await process_frame

	var detail_two := load("res://scenes/screens/chapter_detail_02.tscn").instantiate() as Control
	root.add_child(detail_two)
	await process_frame
	_expect(_visible_expedition_count(detail_two) == 8, "Chapter II detail should show exactly eight expedition cards")
	for index in 8:
		_expect(_detail_button(detail_two, index).disabled, "Direct Chapter II detail access should respect the locked prerequisite")
	detail_two.queue_free()
	await process_frame

	var chapter_one := load("res://resources/chapters/ancient_courtyard.tres") as ChapterDefinition
	for expedition in chapter_one.expeditions:
		ProgressStore.mark_expedition_completed(expedition.id)
	root_screen = load("res://scenes/screens/expedition_select.tscn").instantiate() as Control
	root.add_child(root_screen)
	await process_frame
	chapter_two_button = root_screen.get_node("ContentCenter/PortraitContent/Layout/ChapterList/ChapterTwoButton") as Button
	_expect(not chapter_two_button.disabled and chapter_two_button.text.ends_with("Открыто"), "Completing Chapter I should unlock Chapter II at the root")
	root_screen.queue_free()
	await process_frame

	detail_two = load("res://scenes/screens/chapter_detail_02.tscn").instantiate() as Control
	root.add_child(detail_two)
	await process_frame
	_expect(not _detail_button(detail_two, 0).disabled and _detail_button(detail_two, 0).text.ends_with("Открыто"), "Unlocked Chapter II detail should open Expedition 2-1")
	_expect(_detail_button(detail_two, 1).disabled and _detail_button(detail_two, 1).text.ends_with("Закрыто"), "Expedition 2-2 should wait for 2-1")
	ProgressStore.mark_expedition_completed(&"ruined_shrine_01")
	detail_two.refresh_progress()
	_expect(_detail_button(detail_two, 0).text.ends_with("✓ Пройдено"), "Completed expedition should keep its checkmark state")
	_expect(not _detail_button(detail_two, 1).disabled and _detail_button(detail_two, 1).text.ends_with("Открыто"), "Completing 2-1 should unlock 2-2")
	detail_two.queue_free()
	await process_frame


func _test_navigation_paths() -> void:
	var detail := load("res://scenes/screens/chapter_detail_01.tscn").instantiate() as Control
	root.add_child(detail)
	current_scene = detail
	await process_frame
	detail.call("_back_to_chapters")
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.name == "ExpeditionSelect", "Chapter Detail Back should return to Chapters Root")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame
	var finale_one := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	var finale_two := load("res://scenes/screens/game_screen_ch2_08.tscn").instantiate() as Control
	_expect(finale_one.next_expedition_scene_path == "res://scenes/screens/chapter_detail_01.tscn", "Chapter I finale should return to Chapter I detail")
	_expect(finale_two.next_expedition_scene_path == "res://scenes/screens/chapter_detail_02.tscn", "Chapter II finale should return to Chapter II detail")
	finale_one.free()
	finale_two.free()


func _visible_expedition_count(detail: Control) -> int:
	var count := 0
	for index in 8:
		if _detail_button(detail, index).visible:
			count += 1
	return count


func _detail_button(detail: Control, index: int) -> Button:
	return detail.get_node(DETAIL_GRID + "Expedition%02d" % (index + 1)) as Button


func _delete_progress() -> void:
	var path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
