extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.campaign_route_progress.cfg"

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

	# Every campaign expedition points to a game screen that plays exactly that expedition.
	var total := 0
	for chapter in CampaignRoute.chapters():
		for expedition in chapter.expeditions:
			total += 1
			var path := expedition.game_scene_path
			_expect(not path.is_empty(), "%s must define game_scene_path" % expedition.id)
			if path.is_empty() or not ResourceLoader.exists(path):
				_expect(false, "%s game scene must exist: %s" % [expedition.id, path])
				continue
			var game := (load(path) as PackedScene).instantiate()
			var session := game.get_node("GameSession") as GameSession
			_expect(session.expedition_definition.id == expedition.id, "%s scene must play the same expedition" % expedition.id)
			game.free()
	_expect(total == 47, "Campaign should contain 24 excavations + 23 site levels (got %d)" % total)
	# Every excavation but the onboarding one comes right after its site level.
	for chapter in CampaignRoute.chapters():
		var previous: ExpeditionDefinition = null
		for expedition in chapter.expeditions:
			if not expedition.is_site_preparation() and expedition.id != &"expedition_01":
				_expect(previous != null and previous.is_site_preparation() and previous.id == StringName("%s_site" % expedition.id), "%s follows its site level" % expedition.id)
			previous = expedition

	# Play continues from the first unfinished expedition.
	_expect(CampaignRoute.play_scene_path() == "res://scenes/screens/game_screen.tscn", "New player starts at Expedition 1")
	_expect(not CampaignRoute.has_progress(), "New player has no progress")
	ProgressStore.mark_expedition_completed(&"expedition_01")
	_expect(CampaignRoute.play_scene_path() == "res://scenes/screens/game_screen_site_expedition_02.tscn", "Play continues at the site of Expedition 2")
	ProgressStore.mark_expedition_completed(&"expedition_02_site")
	_expect(CampaignRoute.play_scene_path() == "res://scenes/screens/game_screen_02.tscn", "Then Expedition 2 itself")
	_expect(CampaignRoute.has_progress(), "Progress is detected after one victory")
	for chapter in CampaignRoute.chapters().slice(0, 1):
		for expedition in chapter.expeditions:
			ProgressStore.mark_expedition_completed(expedition.id)
	_expect(CampaignRoute.play_scene_path() == "res://scenes/screens/game_screen_site_ruined_shrine_01.tscn", "Play continues at Chapter II (its first site) after Chapter I")
	for chapter in CampaignRoute.chapters():
		for expedition in chapter.expeditions:
			ProgressStore.mark_expedition_completed(expedition.id)
	_expect(CampaignRoute.play_scene_path() == CampaignRoute.EXPEDITION_SELECT_SCENE, "Finished campaign opens the expedition list")

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("CAMPAIGN_ROUTE_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
