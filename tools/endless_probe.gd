extends SceneTree

## Bot runs of Endless Excavation (with dig spots, stones, roots):
##   godot --headless --path . -s res://tools/endless_probe.gd -- --runs=20 [--daily]
## Prints median moves, depth, finds and score. Target for the bot (no undo):
## a median run of 40-80 moves (4-8 minutes for a person), depth 4-7 m.

var _runs := 20
var _daily := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = int(arg.trim_prefix("--runs="))
		elif arg == "--daily":
			_daily = true
	call_deferred("_run")


func _run() -> void:
	OnboardingTutorial.auto_start = false
	ProgressStore.storage_path = ProjectSettings.globalize_path("user://endless_probe_progress.cfg")
	var moves: Array[int] = []
	var depths: Array[int] = []
	var finds: Array[int] = []
	var scores: Array[int] = []
	var daily_done := 0
	for run in _runs:
		var screen := (load("res://scenes/screens/endless_screen.tscn") as PackedScene).instantiate() as Control
		var session := screen.get_node("GameSession") as GameSession
		session.endless_seed_override = 1000 + run * 7919
		session.daily_date_override = "2026-01-%02d" % (1 + run % 28)
		root.add_child(screen)
		await process_frame
		screen.call("_start_run", _daily)
		await process_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = run
		while session.moves < 400 and not session.is_no_moves_state():
			var options: Array[Dictionary] = session._enumerate_hint_moves(session._capture_hint_search_state())
			if options.is_empty():
				break
			var best: Dictionary = {}
			var best_value := -INF
			for option in options:
				var value := 120.0 * int(option.get("line_count", 0)) + 60.0 * int(option.get("artifact_hits", 0)) + 3.0 * int(option.get("remaining_legal_moves", 0)) + rng.randf_range(0.0, 50.0)
				if option.get("immediate_loss", false):
					value -= 10000.0
				if value > best_value:
					best_value = value
					best = option
			if not session.try_place_piece(best.slot_index, best.origin):
				break
			for frame in 600:
				await process_frame
				if not session._busy:
					break
		moves.append(session.moves)
		depths.append(session.depth)
		finds.append(session.endless_events.finds_found)
		scores.append(session.score)
		if session.endless_events.is_daily_goal_reached():
			daily_done += 1
		root.remove_child(screen)
		screen.queue_free()
		await process_frame
	print("ENDLESS daily=%s runs=%d moves %s | depth %s | finds %s | score %s | daily goal %d/%d" % [
		_daily, _runs, _median(moves), _median(depths), _median(finds), _median(scores), daily_done, _runs])
	quit()


func _median(values: Array[int]) -> String:
	values.sort()
	return "median %d (%d..%d)" % [values[values.size() / 2], values[0], values[-1]]
