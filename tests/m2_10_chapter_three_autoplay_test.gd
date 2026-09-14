extends SceneTree

const GAME_SCREEN := preload("res://scenes/screens/game_screen.tscn")
const CHAPTER_PATH := "res://resources/chapters/overgrown_catacombs.tres"
const MAX_MOVES := 100

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var chapter := load(CHAPTER_PATH) as ChapterDefinition
	var only_level := _only_level_argument()
	for index in chapter.expeditions.size():
		if not only_level.is_empty() and only_level != "3-%d" % (index + 1):
			continue
		var outcome := await _autoplay(chapter, chapter.expeditions[index])
		print(
			"M2_10_ROOT_PRESSURE level=3-%d initial=%d growth=%d final=%d moves=%d fragments=%d/%d victory=%s terminal=%s max_ms=%.2f"
			% [
				index + 1, outcome.initial_roots, outcome.growth_events, outcome.final_roots,
				outcome.moves, outcome.fragments, outcome.fragment_count, outcome.victory,
				outcome.terminal, outcome.max_planning_ms,
			]
		)
		if not outcome.victory:
			_failures.append("3-%d failed: %s after %d moves" % [index + 1, outcome.terminal, outcome.moves])
	_finish()


func _only_level_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			return argument.trim_prefix("--only=")
	return ""


func _autoplay(chapter: ChapterDefinition, expedition: ExpeditionDefinition) -> Dictionary:
	var game := GAME_SCREEN.instantiate() as Control
	var session := game.get_node("GameSession") as GameSession
	session.chapter_definition = chapter
	session.expedition_definition = expedition
	root.add_child(game)
	await process_frame
	await process_frame
	var initial_roots := session.obstacle_model.root_count()
	var growth_events := 0
	var terminal := "turn_cap"
	var victory := false
	var max_planning_ms := 0.0
	while session.moves < MAX_MOVES:
		var hint := session.find_best_hint()
		if hint.is_empty():
			terminal = "no_hint"
			break
		max_planning_ms = maxf(max_planning_ms, float(hint.get("planning_time_ms", 0.0)))
		var result := session.debug_apply_hint_for_validation(hint)
		if result.is_empty():
			terminal = "apply_failed"
			break
		if result.root_new_growth:
			growth_events += 1
		if result.completes_expedition:
			victory = true
			terminal = "victory"
			break
		if result.immediate_loss:
			terminal = "no_moves"
			break
	var outcome := {
		"initial_roots": initial_roots,
		"growth_events": growth_events,
		"final_roots": session.obstacle_model.root_count(),
		"moves": session.moves,
		"fragments": session.excavation_model.collected_fragment_count(),
		"fragment_count": session.excavation_model.fragment_count(),
		"victory": victory,
		"terminal": terminal,
		"max_planning_ms": max_planning_ms,
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return outcome


func _finish() -> void:
	if _failures.is_empty():
		print("M2_10_CHAPTER_THREE_AUTOPLAY_OK levels=10")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
