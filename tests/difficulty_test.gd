extends SceneTree

## Three playthroughs (Difficulty): unlock order, separate progress, old saves
## count as Easy, what each difficulty changes in a level, the Hard move limit,
## medals, the picker and the cloud format.

const TEST_PROGRESS_PATH := "res://tests/.difficulty_progress.cfg"
const LEVEL_SCENE := "res://scenes/screens/game_screen_ch2_03.tscn"

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
	Difficulty.override_level = -1
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	ProgressStore.changed_hook = Callable()
	DirAccess.remove_absolute(ProgressStore.storage_path)

	# A: unlock order and separate progress.
	_expect(Difficulty.current() == Difficulty.Level.EASY, "A: a new player plays Easy")
	_expect(not Difficulty.is_unlocked(Difficulty.Level.MEDIUM) and not Difficulty.is_unlocked(Difficulty.Level.HARD), "A: Medium and Hard start locked")
	Difficulty.select(Difficulty.Level.HARD)
	_expect(Difficulty.current() == Difficulty.Level.EASY, "A: a locked difficulty cannot be chosen")
	# An old save (before difficulties) is Easy progress.
	var config := ConfigFile.new()
	config.set_value("completed_expeditions", "expedition_01", true)
	config.save(ProgressStore.storage_path)
	_expect(ProgressStore.is_expedition_completed(&"expedition_01"), "A: an old save counts as Easy")
	for chapter in CampaignRoute.chapters():
		for dig in chapter.dig_expeditions():
			ProgressStore.mark_expedition_completed(dig.id)
	_expect(Difficulty.is_campaign_complete(Difficulty.Level.EASY), "A: all finds on Easy complete the campaign")
	_expect(Difficulty.is_unlocked(Difficulty.Level.MEDIUM) and not Difficulty.is_unlocked(Difficulty.Level.HARD), "A: Medium opens after Easy, Hard still locked")
	Difficulty.select(Difficulty.Level.MEDIUM)
	_expect(Difficulty.current() == Difficulty.Level.MEDIUM, "A: Medium can be chosen now")
	_expect(ProgressStore.completed_expeditions().is_empty(), "A: Medium starts with an empty campaign")
	_expect(CampaignRoute.next_expedition().id == &"expedition_01", "A: Play starts the campaign again on Medium")
	_expect(ProgressStore.is_expedition_completed_any(&"expedition_03"), "A: finds dug on Easy stay known (collection, Endless)")
	ProgressStore.mark_expedition_completed(&"expedition_02")
	_expect(ProgressStore.highest_difficulty_completed(&"expedition_02") == Difficulty.Level.MEDIUM, "A: the best difficulty of a find is remembered")
	_expect(ProgressStore.highest_difficulty_completed(&"expedition_04") == Difficulty.Level.EASY, "A: other finds keep their Easy medal")

	# B: cloud format keeps every playthrough and the chosen difficulty.
	var state := ProgressStore.export_state()
	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.merge_state(state)
	_expect(ProgressStore.get_selected_difficulty() == Difficulty.Level.MEDIUM, "B: the chosen difficulty comes back from the cloud")
	_expect(ProgressStore.is_expedition_completed(&"expedition_02", Difficulty.Level.MEDIUM), "B: Medium progress comes back from the cloud")
	_expect(Difficulty.is_campaign_complete(Difficulty.Level.EASY), "B: Easy progress comes back from the cloud")

	# C: what a level looks like on each difficulty.
	var easy := await _open_level(Difficulty.Level.EASY)
	var medium := await _open_level(Difficulty.Level.MEDIUM)
	var hard := await _open_level(Difficulty.Level.HARD)
	_expect(easy.help_state.free_undos_remaining == 3 and easy.help_state.free_hints_remaining == 3, "C: Easy gives 3 free Undo and Hint")
	_expect(medium.help_state.free_undos_remaining == 1 and medium.help_state.free_hints_remaining == 1, "C: Medium gives 1 free Undo and Hint")
	_expect(hard.help_state.free_undos_remaining == 0 and hard.help_state.free_hints_remaining == 0, "C: Hard has no free Undo or Hint")
	_expect(hard.help_state.rewarded_undos_remaining > 0, "C: Hard still has Undo for an ad")
	var easy_soil := _soil_total(easy)
	var medium_soil := _soil_total(medium)
	var hard_soil := _soil_total(hard)
	_expect(easy_soil <= medium_soil and medium_soil < hard_soil, "C: soil Easy <= Medium < Hard (%d, %d, %d)" % [easy_soil, medium_soil, hard_soil])
	_expect(_max_depth(easy) == 1, "C: Easy has no strong soil")
	_expect(_max_stone(easy) <= 1, "C: Easy stones break with one line")
	_expect(_max_stone(hard) == _max_stone(medium), "C: Hard keeps the stones of the level")
	_expect(easy.move_limit == 0 and medium.move_limit == 0 and hard.move_limit > 0, "C: only Hard limits the moves (%d)" % hard.move_limit)
	_expect(hard.moves_label.text.contains("/"), "C: the Hard counter shows the limit (%s)" % hard.moves_label.text)

	# D: score multiplier.
	easy.call("_add_score", 100)
	medium.call("_add_score", 100)
	hard.call("_add_score", 100)
	_expect(easy.score == 100 and medium.score == 100 and hard.score == 200, "D: score x1 / x1 / x2 (%d, %d, %d)" % [easy.score, medium.score, hard.score])

	# E: out of moves on Hard ends the attempt with its own message.
	hard.moves = hard.move_limit
	hard.evaluate_play_state()
	_expect(hard.is_no_moves_state(), "E: reaching the move limit ends the attempt")
	var popup := hard.result_popup
	_expect(popup.visible and popup.title_label.text == "ХОДЫ ЗАКОНЧИЛИСЬ", "E: the popup says the moves ran out (%s)" % popup.title_label.text)
	for session in [easy, medium, hard]:
		session.get_parent().queue_free()
	await process_frame

	# F: picker on the chapters screen and medals in the collection.
	Difficulty.override_level = -1
	var select := (load("res://scenes/screens/expedition_select.tscn") as PackedScene).instantiate() as Control
	root.add_child(select)
	await process_frame
	var picker := select.get_node("%DifficultyPicker") as DifficultyPicker
	var buttons := picker.get_node("Buttons")
	_expect((buttons.get_node("Medium") as Button).button_pressed, "F: the picker shows the chosen difficulty")
	_expect((buttons.get_node("Hard/LockIcon") as CanvasItem).visible, "F: Hard has a padlock")
	(buttons.get_node("Hard") as Button).pressed.emit()
	_expect(Difficulty.current() == Difficulty.Level.MEDIUM, "F: tapping the locked Hard keeps Medium")
	_expect((picker.get_node("%Description") as Label).text.contains("средней"), "F: the locked tab says what opens it")
	(buttons.get_node("Easy") as Button).pressed.emit()
	_expect(Difficulty.current() == Difficulty.Level.EASY, "F: tapping Easy switches back")
	select.queue_free()
	var collection := (load("res://scenes/screens/collection.tscn") as PackedScene).instantiate() as Control
	root.add_child(collection)
	await process_frame
	await process_frame
	var medals := 0
	for medal in collection.find_children("MedalBadge", "TextureRect", true, false):
		if (medal as TextureRect).visible:
			medals += 1
	_expect(medals > 0, "F: dug finds show a medal in the collection (%d)" % medals)
	collection.queue_free()
	await process_frame

	Difficulty.override_level = -1
	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("DIFFICULTY_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _open_level(level: int) -> GameSession:
	Difficulty.override_level = level
	var game := (load(LEVEL_SCENE) as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	session.restart_expedition()
	Difficulty.override_level = -1
	return session


func _soil_total(session: GameSession) -> int:
	var total := 0
	for y in ExcavationModel.HEIGHT:
		for x in ExcavationModel.WIDTH:
			total += session.excavation_model.get_soil_depth(Vector2i(x, y))
	return total


func _max_depth(session: GameSession) -> int:
	var best := 0
	for y in ExcavationModel.HEIGHT:
		for x in ExcavationModel.WIDTH:
			best = maxi(best, session.excavation_model.get_soil_depth(Vector2i(x, y)))
	return best


func _max_stone(session: GameSession) -> int:
	var best := 0
	for cell in session.obstacle_model.get_stone_cells():
		best = maxi(best, session.obstacle_model.get_durability(cell))
	return best
