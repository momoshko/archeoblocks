extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_4b_popup_test_progress.cfg"

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
	var absolute_progress_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	var expedition := load("res://resources/expeditions/expedition_06.tres") as ExpeditionDefinition
	_expect(expedition != null, "Golden Mask expedition should load")
	_expect(expedition.full_artifact_texture != null, "Golden Mask expedition should provide full artifact artwork")
	if expedition.full_artifact_texture != null:
		_expect(
			expedition.full_artifact_texture.get_width() == 512
			and expedition.full_artifact_texture.get_height() == 512,
			"Artifact preview should use the mobile-sized 512x512 source"
		)

	var game := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var session := game.get_node("GameSession") as GameSession
	session.score = 1234
	session.coins_earned = 20
	session._finish_victory()
	await process_frame

	var popup := game.get_node("ModalUI/ResultPopup") as ResultPopup
	var content_path := "PopupCenter/PopupPanel/Content/"
	var preview := popup.get_node(content_path + "ArtifactPreview") as TextureRect
	var artifact_name := popup.get_node(content_path + "ArtifactName") as Label
	var score := popup.get_node(content_path + "Score") as Label
	var coins := popup.get_node(content_path + "Coins") as Label
	var buttons := popup.get_node(content_path + "Buttons") as HBoxContainer
	var panel := popup.get_node("PopupCenter/PopupPanel") as PanelContainer
	_expect(popup.visible, "Victory popup should be visible")
	_expect(
		preview.visible
		and ArtifactTextureUtil.source_texture(preview.texture) == expedition.full_artifact_texture,
		"Victory popup should show the expedition artifact texture"
	)
	_expect(artifact_name.text == "Золотая маска", "Victory popup should keep the artifact name")
	_expect(score.visible and score.text == "Счёт: 1234", "Victory popup should keep the score readable")
	_expect(coins.visible and coins.text == "Монеты: +20", "Victory popup should keep the coin reward readable")
	_expect(buttons.visible, "Victory popup buttons should remain visible")
	_expect(panel.size.x <= 720.0 and panel.size.y <= 1280.0, "Victory popup should fit the portrait viewport")
	_expect(popup.get_node_or_null(content_path + "ArtifactPlaceholder") == null, "Flat artifact placeholder should be removed")

	game.queue_free()
	await process_frame
	current_scene = null
	if FileAccess.file_exists(absolute_progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_4B_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
