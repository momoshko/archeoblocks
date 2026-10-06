extends SceneTree

## Site preparation levels (goal clear_site): HUD counts the rubble, the Hint
## plays them to the end, the win shows "Участок готов!" and is saved; every
## site validates and sits right before its excavation.

const PROGRESS_PATH := "res://tests/.site_levels_progress.cfg"

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

	var sites := 0
	for chapter in CampaignRoute.chapters():
		for expedition in chapter.expeditions:
			if expedition.is_site_preparation():
				sites += 1
				_expect(expedition.validate().is_empty(), "%s validates" % expedition.id)
				_expect(expedition.artifact_fragments.is_empty(), "%s has no fragments" % expedition.id)
				_expect(expedition.full_artifact_texture != null, "%s shows the find it leads to" % expedition.id)
	_expect(sites == 23, "23 site levels (got %d)" % sites)

	var game := (load("res://scenes/screens/game_screen_site_ruined_shrine_03.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var won := [false]
	session.victory_reached.connect(func() -> void: won[0] = true)
	_expect(session.excavation_model.is_site_preparation(), "The model knows the goal")
	_expect(session.fragment_progress.text == "Завалы: 5", "HUD counts 4 soil cells + 1 stone (%s)" % session.fragment_progress.text)
	_expect(not session.excavation_model.is_goal_complete(session.obstacle_model), "Not won at the start")
	for move in 80:
		if won[0] or session.is_no_moves_state():
			break
		var hint := session.find_best_hint()
		if hint.is_empty():
			break
		session.try_place_piece(hint.slot_index, hint.origin)
		for frame in 90:
			await process_frame
			if not session._busy:
				break
	_expect(won[0], "Hint moves clear the site (moves: %d)" % session.moves)
	var popup := game.get_node("ModalUI/ResultPopup") as ResultPopup
	_expect(popup.visible and popup.title_label.text == "УЧАСТОК ГОТОВ!", "Win shows the site-ready window")
	_expect(not popup.clean_button.visible, "No cleaning after a site level")
	_expect(ProgressStore.is_expedition_completed(&"ruined_shrine_03_site"), "Site completion is saved")
	_expect(CampaignRoute.next_expedition() != null, "The campaign continues")
	game.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("site_levels_test: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
