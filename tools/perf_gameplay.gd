extends SceneTree

## Frame-time check of a level played by Hint moves (Hint is planned in the
## background, sliced over frames). Run with a window:
##   godot --path . -s res://tools/perf_gameplay.gd -- --scene=game_screen_ch2_01 --moves=6
## Prints, per move: how long after the move the Hint plan was ready, the time
## from Hint press to the highlighted move, and the worst frame meanwhile.
## Exit code 1 if any frame took longer than --limit=ms (default 50).

var _limit_ms := 50.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := "game_screen_ch2_01"
	var move_count := 6
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene = arg.trim_prefix("--scene=")
		elif arg.begins_with("--moves="):
			move_count = int(arg.trim_prefix("--moves="))
		elif arg.begins_with("--limit="):
			_limit_ms = float(arg.trim_prefix("--limit="))
	OnboardingTutorial.auto_start = false
	var game := (load("res://scenes/screens/%s.tscn" % scene) as PackedScene).instantiate()
	root.add_child(game)
	var session: GameSession = game.find_children("*", "GameSession", true, false)[0]
	var worst_all := 0.0
	for move in move_count:
		# Wait (like a thinking player) until the background plan is ready.
		var start := Time.get_ticks_usec()
		var worst := 0.0
		var prev := start
		var ready_ms := -1.0
		for frame in 600:
			await process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - prev) / 1000.0)
			prev = now
			if session._hint_plan_ready():
				ready_ms = (now - start) / 1000.0
				break
		var press := Time.get_ticks_usec()
		var hint := session.find_best_hint()
		var press_ms := (Time.get_ticks_usec() - press) / 1000.0
		worst_all = maxf(worst_all, worst)
		print("move %d: plan ready after %6.0f ms, Hint press %5.1f ms, worst frame %5.1f ms%s" % [
			move + 1, ready_ms, press_ms, worst, "  <-- SLOW" if worst > _limit_ms else ""])
		if hint.is_empty() or not session.try_place_piece(hint.slot_index, hint.origin):
			break
		var after_move := 0.0
		var spike_frame := -1
		for frame in 30:
			var before := Time.get_ticks_usec()
			await process_frame
			var took := (Time.get_ticks_usec() - before) / 1000.0
			if took > after_move:
				after_move = took
				spike_frame = frame
		worst_all = maxf(worst_all, after_move)
		print("        after the move (lines, effects): worst frame %5.1f ms at frame %d%s" % [
			after_move, spike_frame, "  <-- SLOW" if after_move > _limit_ms else ""])
	print("worst frame overall %.1f ms (limit %.0f)" % [worst_all, _limit_ms])
	quit(1 if worst_all > _limit_ms else 0)
