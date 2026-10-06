extends SceneTree

## Frame strips of short UI animations (for reviews: a still screenshot cannot
## show motion). Run with a window, like capture_screens.gd:
##   godot --path . -s res://tools/capture_motion.gd -- --size=390x844 --out=build/motion
## Saves <out>/<name>_<ms>.png: line clear, piece landing, window pop-in, button press.

var _out := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var size := Vector2i(390, 844)
	_out = ProjectSettings.globalize_path("res://build/motion")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--out="):
			_out = ProjectSettings.globalize_path("res://" + arg.trim_prefix("--out="))
	DisplayServer.window_set_size(size)
	root.size = size
	DirAccess.make_dir_recursive_absolute(_out)
	FileAccess.open(_out.get_base_dir().path_join(".gdignore"), FileAccess.WRITE).store_string("")
	OnboardingTutorial.auto_start = false
	var game := (load("res://scenes/screens/game_screen_ch2_01.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await create_timer(0.6).timeout
	var session := game.get_node("GameSession") as GameSession
	var board := session.board_view

	# Line clear: a full bottom row of mixed colours, the piece was at its left end.
	var colours := [Color(0.2, 0.6, 0.3), Color(0.25, 0.45, 0.85), Color(0.85, 0.25, 0.2), Color(0.9, 0.7, 0.2)]
	var row: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		row.append(Vector2i(x, 7))
		board.set_cells_occupied([Vector2i(x, 7)] as Array[Vector2i], colours[x / 2])
	await create_timer(0.2).timeout
	if board.has_method("play_landing"):
		board.play_landing([Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)] as Array[Vector2i])
		await _strip("land", [0, 40, 90])
		await create_timer(0.3).timeout
	var clear_args := [row, Vector2(1.0, 7.0)] if board.has_method("play_landing") else [row]
	board.clear_cells_with_feedback.callv.call_deferred(clear_args)
	await process_frame
	await _strip("line", [0, 50, 100, 150, 220, 320])
	await create_timer(0.6).timeout

	# Window pop-in.
	session.result_popup.show_victory("Test", 120, 0, null)
	await _strip("popup", [0, 60, 120, 240])
	session.result_popup.close_popup()
	await create_timer(0.2).timeout

	# Victory celebration: ribbon, confetti, score count-up, buttons later.
	var mask := load("res://assets/artifacts/ancient_courtyard/golden_mask_full_v1.png") as Texture2D
	session.result_popup.show_victory(tr("Золотая маска"), 1250, 0, mask)
	await _strip("victory", [100, 350, 600, 900, 1300])
	session.result_popup.close_popup()
	await create_timer(0.2).timeout

	# Button press: hold, then release.
	var pause := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/PauseButton") as Button
	pause.button_down.emit()
	await _strip("press", [0, 80])
	pause.button_up.emit()
	await _strip("release", [60, 160])
	quit(0)


## Saves a frame at each given time (ms from now).
func _strip(name: String, times_ms: Array) -> void:
	var start := Time.get_ticks_msec()
	for target in times_ms:
		while Time.get_ticks_msec() - start < int(target):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("%s_%03d.png" % [name, int(target)]))
