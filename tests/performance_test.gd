extends SceneTree

## No pauses: menus open from memory after the first visit, the Hint is planned
## in the background (sliced over frames) and pressing Hint is instant.
## Limits are loose (slow CI machines); real numbers: tools/perf_navigation.gd,
## tools/perf_gameplay.gd.

const REPEAT_SCREEN_LIMIT_MS := 120.0
const HINT_PRESS_LIMIT_MS := 20.0
const PLANNING_FRAME_LIMIT_MS := 40.0

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
	await _test_chapters_loaded_once()
	await _test_repeat_screens_fast()
	await _test_hint_planned_in_background()
	if _failures.is_empty():
		print("performance_test: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_chapters_loaded_once() -> void:
	CampaignRoute.chapters()
	var start := Time.get_ticks_usec()
	for i in 10:
		CampaignRoute.next_expedition()
	var each_ms := (Time.get_ticks_usec() - start) / 10000.0
	_expect(each_ms < 5.0, "Chapters must stay loaded (next_expedition took %.1f ms)" % each_ms)
	_expect(CampaignRoute.chapters()[0] == CampaignRoute.chapters()[0], "Chapters must be the same loaded objects")


func _test_repeat_screens_fast() -> void:
	ScreenCache.warm_up()
	var route := [
		"res://scenes/screens/settings.tscn", ScreenCache.MAIN_SCENE,
		"res://scenes/screens/expedition_select.tscn",
		"res://scenes/screens/chapter_detail_01.tscn",
		"res://scenes/screens/expedition_select.tscn", ScreenCache.MAIN_SCENE,
		"res://scenes/screens/collection.tscn", ScreenCache.MAIN_SCENE,
	]
	for path in route:
		await _open(path)  # first pass: anything not warmed up loads here
	for path in route:
		var ms := await _open(path)
		_expect(ms < REPEAT_SCREEN_LIMIT_MS, "%s opened in %.0f ms (limit %.0f)" % [path.get_file(), ms, REPEAT_SCREEN_LIMIT_MS])
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame


func _open(path: String) -> float:
	var start := Time.get_ticks_usec()
	_expect(ScreenCache.change_to(self, path) == OK, "ScreenCache should open %s" % path)
	await process_frame
	await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0


func _test_hint_planned_in_background() -> void:
	var game := (load("res://scenes/screens/game_screen_04.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	var session := game.get_node("GameSession") as GameSession
	await process_frame
	await process_frame
	var reference := HintPlanner.new().find_best(session)
	var worst_ms := 0.0
	var ready := false
	var previous := Time.get_ticks_usec()
	for frame in 2000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now - previous) / 1000.0)
		previous = now
		if session._hint_plan_ready():
			ready = true
			break
	_expect(ready, "The Hint should be planned in the background")
	_expect(worst_ms < PLANNING_FRAME_LIMIT_MS, "Background planning must not stall a frame (%.1f ms)" % worst_ms)
	var start := Time.get_ticks_usec()
	var hint := session.find_best_hint()
	var press_ms := (Time.get_ticks_usec() - start) / 1000.0
	_expect(press_ms < HINT_PRESS_LIMIT_MS, "Hint press must be instant after planning (%.1f ms)" % press_ms)
	_expect(hint.get("cache_hit", false), "Hint press should use the background plan")
	_expect(
		hint.get("slot_index") == reference.get("slot_index") and hint.get("origin") == reference.get("origin"),
		"Background plan must equal the all-at-once plan"
	)

	# A move during planning: the old plan is dropped, a new one is made.
	_expect(session.try_place_piece(hint.slot_index, hint.origin), "Hinted move should be legal")
	await create_timer(0.1).timeout
	_expect(not session._hint_plan_ready(), "Old plan must not count for the new board")
	for frame in 2000:
		await process_frame
		if session._hint_plan_ready():
			break
	_expect(session._hint_plan_ready(), "A new plan should be made after the move")
	game.queue_free()
	await process_frame
