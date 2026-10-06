extends SceneTree

## After an excavation: "Очистить находку" -> restoration of that find ->
## "Готово" goes on to the next level; the find is marked clean; a clean find
## gets no button next time; the collection opens cleaning for dusty finds.

const PROGRESS_PATH := "res://tests/.restoration_flow_progress.cfg"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	OnboardingTutorial.auto_start = false
	ProgressStore.storage_path = ProjectSettings.globalize_path(PROGRESS_PATH)
	DirAccess.remove_absolute(ProgressStore.storage_path)

	ScreenCache.change_to(self, "res://scenes/screens/game_screen_02.tscn")
	await process_frame
	await process_frame
	var game := current_scene
	var session := game.get_node("GameSession") as GameSession
	session._finish_victory()
	var popup := game.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(popup.visible and popup.clean_button.visible, "Victory offers cleaning the find")
	popup.clean_button.pressed.emit()
	await process_frame
	await process_frame
	var restoration := current_scene as RestorationScreen
	_expect(restoration != null, "Cleaning opens the restoration screen")
	if restoration != null:
		_expect(restoration.expedition_definition.id == &"expedition_02", "Restoration shows the dug-up find")
		_expect(restoration.return_scene_path == "res://scenes/screens/game_screen_site_expedition_03.tscn", "After cleaning the campaign goes on")
		restoration.skip()
		for frame in 120:
			await process_frame
			if restoration.stage == RestorationScreen.Stage.DONE:
				break
		_expect(ProgressStore.is_artifact_restored(&"stone_amulet"), "The find is saved as clean")

	# A clean find: no button after a replay.
	ScreenCache.change_to(self, "res://scenes/screens/game_screen_02.tscn")
	await process_frame
	await process_frame
	(current_scene.get_node("GameSession") as GameSession)._finish_victory()
	_expect(not (current_scene.get_node("ModalUI/ResultPopup") as ResultPopup).clean_button.visible, "Clean finds are not offered again")

	# Collection: a dusty find opens the restoration with a tap.
	ProgressStore.mark_expedition_completed(&"expedition_01")
	ScreenCache.change_to(self, "res://scenes/screens/collection.tscn")
	await process_frame
	await process_frame
	var card := current_scene.get_node("ContentCenter/PortraitContent/Layout/ArtifactGrid/Artifact01") as Control
	_expect((card.get_node("Layout/ArtifactVisual/CleanBadge") as CanvasItem).visible, "Dusty find shows the brush badge")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)
	await process_frame
	await process_frame
	_expect(current_scene is RestorationScreen and (current_scene as RestorationScreen).expedition_definition.id == &"expedition_01", "Tapping a dusty find opens its cleaning")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("restoration_flow_test: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
