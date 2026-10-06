extends SceneTree

## Endless events: dig spots appear after lines and cave in after their moves;
## a dug-up spot gives points and counts a find; clay drops stones; the Daily
## Dig has one seed per date and saves the reached goal; the lobby shows it.

const PROGRESS_PATH := "res://tests/.endless_events_progress.cfg"
const ENDLESS_SCENE := "res://scenes/screens/endless_screen.tscn"

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
	var definition := load("res://resources/endless/endless_default.tres") as EndlessDefinition
	_expect(definition.validate().is_empty(), "Endless definition validates")

	# Pure logic.
	var events := EndlessEvents.new()
	var pool: Array[ExpeditionDefinition] = [load("res://resources/expeditions/expedition_01.tres") as ExpeditionDefinition]
	events.reset(definition, 12345, false, pool)
	var board := BoardModel.new()
	var obstacles := ObstacleModel.new()
	var excavation := ExcavationModel.new()
	var spawned: Array[Dictionary] = []
	for move in 10:
		spawned.append_array(events.after_move(1, 0, board, obstacles, excavation))
	var spot_events := spawned.filter(func(e: Dictionary) -> bool: return e.type == "spot_new")
	_expect(spot_events.size() == 1, "One dig spot after %d lines" % definition.find_every_lines)
	if not spot_events.is_empty():
		var spot: Dictionary = spot_events[0]
		excavation.add_dig_spot(spot.id, spot.cell, int(spot.depth))
		_expect(excavation.get_soil_depth(spot.cell) == 1 and excavation.is_target_cell(spot.cell), "The spot is soil with a find under it")
		var expired := false
		for move in definition.spot_moves + 2:
			for event in events.after_move(0, 0, board, obstacles, excavation):
				if event.type == "spot_expired" and event.id == spot.id:
					expired = true
		_expect(expired, "The spot caves in after %d moves" % definition.spot_moves)
		excavation.remove_fragment(spot.id)
		_expect(excavation.get_soil_depth(spot.cell) == 0, "A caved-in spot leaves no soil")
	events.reset(definition, 777, false, pool)
	var stones := 0
	for move in 30:
		for event in events.after_move(0, 6, board, obstacles, excavation):
			if event.type == "stone":
				stones += 1
	_expect(stones == 2, "Clay drops a stone every 14 moves (got %d in 30)" % stones)
	_expect(EndlessDefinition.daily_seed("2026-10-06") == EndlessDefinition.daily_seed("2026-10-06"), "Daily seed is stable for a date")
	_expect(EndlessDefinition.daily_seed("2026-10-06") != EndlessDefinition.daily_seed("2026-10-07"), "Daily seed changes every day")

	# In the game: a spot dug up by a line.
	var screen := (load(ENDLESS_SCENE) as PackedScene).instantiate() as Control
	var session := screen.get_node("GameSession") as GameSession
	session.endless_seed_override = 99
	session.daily_date_override = "2026-10-06"
	root.add_child(screen)
	await process_frame
	screen.call("_start_run", true)
	await process_frame
	await process_frame
	_expect(session.daily_mode and session.get_endless_seed() == EndlessDefinition.daily_seed("2026-10-06"), "Daily Dig uses the date seed")
	_expect(session.expedition_title.text == "Раскоп дня", "Daily title")
	var cell := Vector2i(3, 4)
	var spot_id := &"spot_test"
	session.excavation_model.add_dig_spot(spot_id, cell, 1)
	session.endless_events.spots[spot_id] = {"cell": cell, "moves_left": 10, "deep": false, "find": pool[0]}
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	session.piece_tray.load_set([single, single, single] as Array[PieceDefinition])
	for x in 8:
		if x != 0:
			session.board_model.place([Vector2i.ZERO] as Array[Vector2i], Vector2i(x, 4))
	var score_before := session.score
	_expect(session.try_place_piece(0, Vector2i(0, 4)), "Line through the spot")
	for frame in 240:
		await process_frame
		if not session._busy:
			break
	_expect(session.endless_events.finds_found == 1, "The find is counted")
	_expect(session.score - score_before >= definition.spot_bonus, "The find gives its bonus")
	_expect(session.finds_label.text == "Находки: 1 / 3", "HUD shows the daily progress (%s)" % session.finds_label.text)
	_expect(session.excavation_model.get_soil_depth(cell) == 0, "The dug-up spot is gone")
	# Goal reached saves the day.
	session.endless_events.finds_found = definition.daily_goal_finds
	await session._collect_endless_finds([] as Array[StringName], 1.0)
	_expect(ProgressStore.is_daily_done("2026-10-06"), "Reaching the goal saves today's dig")
	var lobby := screen.get_node("ModalUI/EndlessLobby") as EndlessLobby
	lobby.refresh(definition, {"year": 2026, "month": 10, "day": 6, "weekday": 2})
	_expect(lobby.get_node("%DailyStatus").text.begins_with("Сегодня пройден"), "Lobby shows today as done")
	var tuesday := lobby.get_node("%WeekRow").get_child(1).get_node("Star") as CanvasItem
	var monday := lobby.get_node("%WeekRow").get_child(0).get_node("Star") as CanvasItem
	_expect(tuesday.modulate.a > 0.9 and monday.modulate.a < 0.9, "Only Tuesday's star is lit")
	root.remove_child(screen)
	screen.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("endless_events_test: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
