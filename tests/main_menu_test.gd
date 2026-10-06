extends SceneTree

## Main menu layout (M3.5): big Play with the next expedition and its find,
## icon tiles, settings gear in the corner, padlock on locked Endless.

const TEST_PROGRESS_PATH := "res://tests/.main_menu_progress.cfg"
const MENU_SCENE := "res://scenes/screens/main_menu.tscn"

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
	DirAccess.remove_absolute(ProgressStore.storage_path)

	var menu := await _open_menu()
	var play := menu.get_node("%PlayButton") as Button
	var first := CampaignRoute.next_expedition()
	_expect(first != null and first.id == &"expedition_01", "Fresh progress leads to expedition 1")
	_expect(play.text == "Играть", "Fresh progress shows 'Играть'")
	_expect((menu.get_node("%NextExpeditionLabel") as Label).text == first.title_ru, "Under Play: the next expedition title")
	var picture := menu.get_node("%FindPicture") as TextureRect
	_expect(picture.visible and picture.texture == first.full_artifact_texture, "Play shows the find waiting in the next expedition")
	_expect(play.size.y >= 110.0, "Play is the biggest button (%d px)" % play.size.y)
	for tile_name in ["ExpeditionsButton", "CollectionButton", "EndlessButton"]:
		var tile := menu.get_node("%" + tile_name) as Button
		_expect(tile.icon != null and not tile.text.is_empty(), "%s is a tile with an icon and a caption" % tile_name)
		_expect(tile.get_parent().name == "TileGrid", "%s sits in the tile grid" % tile_name)
		_expect(tile.size.x < play.size.x * 0.5, "%s is a third of the row, Play is the full row (%s vs %s)" % [tile_name, tile.size, play.size])
	var settings := menu.get_node("%SettingsButton") as Button
	_expect(settings.icon != null and settings.text.is_empty() and not settings.tooltip_text.is_empty(), "Settings is an icon-only gear with a tooltip")
	_expect(settings.get_global_rect().position.y < play.get_global_rect().position.y, "The gear is above the menu, in the corner")
	_expect((menu.get_node("%LockBadge") as CanvasItem).visible, "Locked Endless shows a padlock")
	await _close(menu)

	ProgressStore.mark_expedition_completed(&"expedition_01")
	ProgressStore.mark_expedition_completed(&"expedition_02")
	ProgressStore.mark_expedition_completed(&"expedition_03")
	menu = await _open_menu()
	play = menu.get_node("%PlayButton") as Button
	var next := CampaignRoute.next_expedition()
	_expect(play.text == "Продолжить", "With progress Play reads 'Продолжить'")
	_expect(next.id == &"expedition_04_site" and (menu.get_node("%NextExpeditionLabel") as Label).text == next.title_ru, "Play leads to the site of expedition 4")
	_expect(not (menu.get_node("%LockBadge") as CanvasItem).visible, "Open Endless has no padlock")
	await _close(menu)

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("MAIN_MENU_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _open_menu() -> Control:
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame
	return menu


func _close(menu: Control) -> void:
	root.remove_child(menu)
	menu.queue_free()
	await process_frame
