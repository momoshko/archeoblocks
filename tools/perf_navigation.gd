extends SceneTree

## Walks the menus like a player (change_scene_to_file, as the buttons do) and
## prints how long each screen takes to appear: from the button press to the
## first drawn frame of the new screen. Also prints the worst frame while the
## screen is open. Run with a window for real texture uploads:
##   godot --path . -s res://tools/perf_navigation.gd
## Exit code 1 if any screen after the first visit takes longer than --limit=ms
## (default 150).

const MAIN := "res://scenes/app/main.tscn"
const ROUTE := [
	"res://scenes/screens/settings.tscn", MAIN,
	"res://scenes/screens/expedition_select.tscn",
	"res://scenes/screens/chapter_detail_01.tscn",
	"res://scenes/screens/expedition_select.tscn", MAIN,
	"res://scenes/screens/collection.tscn", MAIN,
	"res://scenes/screens/settings.tscn", MAIN,
	"res://scenes/screens/expedition_select.tscn",
	"res://scenes/screens/chapter_detail_02.tscn",
	"res://scenes/screens/game_screen_ch2_01.tscn", MAIN,
]

var _limit_ms := 150.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--limit="):
			_limit_ms = float(arg.trim_prefix("--limit="))
	OnboardingTutorial.auto_start = false
	var visited := {}
	var slow := 0
	var first := await _open(MAIN)
	print("%-28s %7.1f ms  (first start)" % ["main.tscn", first.x])
	visited[MAIN] = true
	for path in ROUTE:
		var result := await _open(path)
		var again: bool = visited.has(path)
		visited[path] = true
		var mark := ""
		if again and result.x > _limit_ms:
			mark = "  <-- SLOW"
			slow += 1
		print("%-28s %7.1f ms  worst frame %5.1f ms  %s%s" % [
			path.get_file(), result.x, result.y, "again" if again else "first", mark])
	print("slow screens: %d (limit %.0f ms for repeat visits)" % [slow, _limit_ms])
	quit(1 if slow > 0 else 0)


## x = press-to-first-frame ms, y = worst frame ms over the next 15 frames.
func _open(path: String) -> Vector2:
	var start := Time.get_ticks_usec()
	change_scene_to_file(path)
	await process_frame
	await process_frame
	var shown := Time.get_ticks_usec()
	var worst := 0
	var prev := shown
	for i in 15:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - prev)
		prev = now
	return Vector2((shown - start) / 1000.0, worst / 1000.0)
