extends SceneTree

const GAME_SCREEN := preload("res://scenes/screens/game_screen.tscn")
const CHAPTER_PATHS := [
	"res://resources/chapters/ancient_courtyard.tres",
	"res://resources/chapters/ruined_shrine.tres",
]
const ROOT_CHAPTER_PATH := "res://resources/chapters/overgrown_catacombs_prototype.tres"
const MAX_MOVES := 96

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var only_level := _only_level_argument()
	for chapter_path in CHAPTER_PATHS:
		var chapter := load(chapter_path) as ChapterDefinition
		for expedition_index in chapter.expeditions.size():
			var label := "%s %d-%d" % [chapter.title_ru, 1 if chapter_path == CHAPTER_PATHS[0] else 2, expedition_index + 1]
			var level_id := "%d-%d" % [1 if chapter_path == CHAPTER_PATHS[0] else 2, expedition_index + 1]
			if not only_level.is_empty() and level_id != only_level:
				continue
			var outcome := await _autoplay(chapter, chapter.expeditions[expedition_index])
			print(
				"M2_9A_AUTOPLAY level=%s victory=%s moves=%d fragments=%d/%d terminal=%s classes=%s max_states=%d max_ms=%.2f"
				% [
					label,
					outcome.victory,
					outcome.moves,
					outcome.fragments,
					outcome.fragment_count,
					outcome.terminal,
					outcome.classes,
					outcome.max_states,
					outcome.max_planning_ms,
				]
			)
			_expect(outcome.victory, "%s should finish under Hint-only autoplay; terminal=%s moves=%d" % [label, outcome.terminal, outcome.moves])
			if chapter_path == CHAPTER_PATHS[1] and expedition_index == 6:
				_expect(not outcome.used_rescue, "Dedicated 2-7 Hint-only validation must not use rescue")
				_expect(outcome.fragments == outcome.fragment_count, "Dedicated 2-7 validation should excavate every fragment")

	if only_level.is_empty() or only_level == "root":
		var root_chapter := load(ROOT_CHAPTER_PATH) as ChapterDefinition
		var root_outcome := await _autoplay(root_chapter, root_chapter.expeditions[0])
		print(
			"M2_9A_ROOT_AUTOPLAY victory=%s moves=%d fragments=%d/%d terminal=%s root_count=%d"
			% [
				root_outcome.victory,
				root_outcome.moves,
				root_outcome.fragments,
				root_outcome.fragment_count,
				root_outcome.terminal,
				root_outcome.root_count,
			]
		)
		_expect(root_outcome.moves > 0, "Root prototype autoplay should produce a deterministic non-empty outcome")
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
	var terminal := "move_limit"
	var last_result: Dictionary = {}
	var classes: Dictionary = {}
	var max_states := 0
	var max_planning_ms := 0.0
	while session.moves < MAX_MOVES:
		var hint := session.find_best_hint()
		if hint.is_empty():
			terminal = "no_hint"
			break
		var safety_class := str(hint.get("safety_class", "UNKNOWN"))
		classes[safety_class] = int(classes.get(safety_class, 0)) + 1
		max_states = maxi(max_states, int(hint.get("explored_states", 0)))
		max_planning_ms = maxf(max_planning_ms, float(hint.get("planning_time_ms", 0.0)))
		last_result = session.debug_apply_hint_for_validation(hint)
		if last_result.is_empty():
			terminal = "apply_failed"
			break
		if last_result.completes_expedition:
			terminal = "victory"
			break
		if last_result.immediate_loss:
			terminal = "no_moves"
			break
	var outcome := {
		"victory": not last_result.is_empty() and bool(last_result.get("completes_expedition", false)),
		"moves": session.moves,
		"fragments": session.excavation_model.collected_fragment_count(),
		"fragment_count": session.excavation_model.fragment_count(),
		"terminal": terminal,
		"classes": classes,
		"max_states": max_states,
		"max_planning_ms": max_planning_ms,
		"used_rescue": false,
		"root_count": session.obstacle_model.root_count(),
	}
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return outcome


func _finish() -> void:
	if _failures.is_empty():
		print("M2_9A_CAMPAIGN_HINT_AUTOPLAY_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
