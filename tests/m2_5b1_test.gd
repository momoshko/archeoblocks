extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.m2_5b1_progress.cfg"
const EXPEDITION_PATHS := [
	"res://resources/expeditions/expedition_01.tres",
	"res://resources/expeditions/expedition_02.tres",
	"res://resources/expeditions/expedition_06.tres",
]

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
	_test_resource_artwork_and_fragment_mapping()
	await _test_discovery_feedback_lifecycle()
	await _test_single_find_reveal_then_victory()
	await _test_game_modal_cleanup_and_board_separation()
	await _test_victory_and_collection_artwork()
	_delete_test_progress()
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH

	if _failures.is_empty():
		print("M2_5B1_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_resource_artwork_and_fragment_mapping() -> void:
	var expedition_1 := load(EXPEDITION_PATHS[0]) as ExpeditionDefinition
	var expedition_2 := load(EXPEDITION_PATHS[1]) as ExpeditionDefinition
	var expedition_3 := load(EXPEDITION_PATHS[2]) as ExpeditionDefinition
	var expeditions: Array[ExpeditionDefinition] = [expedition_1, expedition_2, expedition_3]
	for expedition in expeditions:
		_expect(expedition != null, "Expedition resource should load")
		_expect(expedition.full_artifact_texture != null, "%s should own full artifact artwork" % expedition.id)
		_expect(expedition.validate().is_empty(), "%s artifact presentation data should validate" % expedition.id)
		_expect(
			expedition.full_artifact_texture.resource_path.begins_with("res://assets/artifacts/ancient_courtyard/"),
			"Runtime artwork must use the clean production asset folder"
		)

	_expect(
		expedition_1.get_fragment_texture(&"courtyard_seal") == expedition_1.full_artifact_texture,
		"Single-find Courtyard Seal should reveal its full artwork"
	)
	_expect(
		expedition_2.get_fragment_texture(&"stone_amulet") == expedition_2.full_artifact_texture,
		"Single-find Stone Amulet should reveal its full artwork"
	)
	var expected_fragment_files := [
		"golden_mask_fragment_a_v1.png",
		"golden_mask_fragment_b_v1.png",
		"golden_mask_fragment_c_v1.png",
	]
	var expected_ids := [&"mask_left", &"mask_center", &"mask_right"]
	for index in expected_ids.size():
		var texture := expedition_3.get_fragment_texture(expected_ids[index])
		_expect(texture != null, "Golden Mask logical fragment should have artwork: %s" % expected_ids[index])
		_expect(
			texture.resource_path.get_file() == expected_fragment_files[index],
			"Golden Mask fragment mapping should follow resource order"
		)
	_expect(expedition_3.get_fragment_texture(&"unknown") == null, "Unknown fragment IDs must not map by board cell")


func _test_discovery_feedback_lifecycle() -> void:
	var expedition := load(EXPEDITION_PATHS[2]) as ExpeditionDefinition
	var feedback := load("res://scenes/ui/artifact_discovery_feedback.tscn").instantiate() as ArtifactDiscoveryFeedback
	root.add_child(feedback)
	await process_frame
	feedback.show_discoveries([expedition.fragment_textures[0]], expedition.artifact_name_ru)
	await process_frame
	var artwork := feedback.get_node("Center/DiscoveryCard/Layout/ArtworkRow/Artwork01") as TextureRect
	_expect(feedback.visible, "Discovery feedback should become visible")
	_expect(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Discovery feedback must not intercept input")
	_expect(
		ArtifactTextureUtil.source_texture(artwork.texture) == expedition.fragment_textures[0],
		"Discovery feedback should present the mapped fragment artwork"
	)
	_expect(artwork.texture is AtlasTexture, "Transparent padding should be fitted non-destructively for presentation")
	feedback.clear()
	_expect(not feedback.visible and artwork.texture == null, "Discovery cleanup should remove temporary artwork")
	feedback.queue_free()
	await process_frame


func _test_game_modal_cleanup_and_board_separation() -> void:
	var game := load("res://scenes/screens/game_screen_06.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var feedback := game.get_node("FeedbackUI/ArtifactDiscoveryFeedback") as ArtifactDiscoveryFeedback
	feedback.show_discoveries([session.expedition_definition.fragment_textures[1]], "Золотая маска")
	await process_frame
	_expect(feedback.visible, "Game discovery presentation should be available below modal UI")
	_expect(
		(game.get_node("ModalUI") as CanvasLayer).layer > (game.get_node("FeedbackUI") as CanvasLayer).layer,
		"Modal canvas must stay above artifact feedback"
	)
	session.set_input_blocked(true)
	_expect(not feedback.visible, "Opening modal state should clear artifact discovery feedback")
	var cell := session.board_view.get_cell_view(Vector2i(1, 1))
	_expect(cell.get_node_or_null("ArtifactArtwork") == null, "Board cells must not receive production artifact artwork")
	game.queue_free()
	await process_frame


func _test_single_find_reveal_then_victory() -> void:
	var game := load("res://scenes/screens/game_screen.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var feedback := game.get_node("FeedbackUI/ArtifactDiscoveryFeedback") as ArtifactDiscoveryFeedback
	feedback.display_seconds = 0.5
	_expect(session.try_place_piece(0, Vector2i(0, 3)), "Seal tutorial first piece should place")
	_expect(session.try_place_piece(1, Vector2i(3, 3)), "Seal tutorial second piece should place")
	_expect(session.try_place_piece(2, Vector2i(6, 3)), "Seal tutorial final piece should place")
	await create_timer(session.board_view.clear_feedback_duration + 0.38).timeout
	var artwork := feedback.get_node("Center/DiscoveryCard/Layout/ArtworkRow/Artwork01") as TextureRect
	_expect(feedback.visible, "Single-find expedition should show its actual artifact before victory")
	_expect(
		ArtifactTextureUtil.source_texture(artwork.texture) == session.expedition_definition.full_artifact_texture,
		"Courtyard Seal discovery should use the resource's full artwork"
	)
	await create_timer(0.75).timeout
	_expect(session.result_popup.visible, "Victory should follow the short single-find artwork reveal")
	_expect(
		ArtifactTextureUtil.source_texture(session.result_popup.artifact_preview.texture)
		== session.expedition_definition.full_artifact_texture,
		"Single-find victory should keep the same artifact identity"
	)
	game.queue_free()
	await process_frame


func _test_victory_and_collection_artwork() -> void:
	var expeditions: Array[ExpeditionDefinition] = []
	for path in EXPEDITION_PATHS:
		var expedition := load(path) as ExpeditionDefinition
		expeditions.append(expedition)
		_expect(ProgressStore.mark_expedition_completed(expedition.id) == OK, "Test completion should save")

	var collection := load("res://scenes/screens/collection.tscn").instantiate() as Control
	root.add_child(collection)
	await process_frame
	var collection_slots := [1, 2, 6]
	for index in expeditions.size():
		var preview_path := "ContentCenter/PortraitContent/Layout/ArtifactGrid/Artifact%02d/Layout/ArtifactVisual/ArtifactPreview" % collection_slots[index]
		var preview := collection.get_node(preview_path) as TextureRect
		_expect(preview.visible, "Completed artifact should be visible in Collection")
		_expect(
			ArtifactTextureUtil.source_texture(preview.texture) == expeditions[index].full_artifact_texture,
			"Collection should use the expedition's resource-driven full artwork"
		)
	collection.queue_free()
	await process_frame

	var popup := load("res://scenes/ui/result_popup.tscn").instantiate() as ResultPopup
	root.add_child(popup)
	await process_frame
	for expedition in expeditions:
		popup.show_victory(expedition.artifact_name_ru, 100, 20, expedition.full_artifact_texture)
		_expect(
			ArtifactTextureUtil.source_texture(popup.artifact_preview.texture) == expedition.full_artifact_texture,
			"Victory popup should use the correct full artwork for %s" % expedition.id
		)
	popup.queue_free()
	await process_frame


func _delete_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
