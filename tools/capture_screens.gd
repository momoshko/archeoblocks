extends SceneTree

## Screenshots of every screen in Russian and English + a text-fit check.
##
## Run with a window (not --headless), from the project folder:
##   Godot_v4.7-stable_win64_console.exe --path . -s res://tools/capture_screens.gd
## Optional window size (landscape desktop, small phone...):
##   ... -s res://tools/capture_screens.gd -- --size=1280x720
## PNGs go to build/screens/<size>/<lang>/ ; problems are printed as LAYOUT: lines.
## Uses a temporary progress file, your own saves are not touched.
## The folder tools/ is not exported, so this never ships in the game.

const PROGRESS_PATH := "user://capture_progress.cfg"
const CHAPTER_ONE := [&"expedition_01", &"expedition_02", &"expedition_03", &"expedition_04", &"expedition_05"]

var _out_dir := ""
var _problems: Array[String] = []
var _lang := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var size := Vector2i(720, 1280)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(size)
	root.size = size
	await _frames(3)
	# .gdignore keeps the editor from importing the screenshots as game assets.
	var base := ProjectSettings.globalize_path("res://build/screens")
	DirAccess.make_dir_recursive_absolute(base)
	FileAccess.open(base.path_join(".gdignore"), FileAccess.WRITE).store_string("")
	ProgressStore.storage_path = ProjectSettings.globalize_path(PROGRESS_PATH)
	ProgressStore.changed_hook = Callable()
	for lang in ["ru", "en"]:
		_lang = lang
		TranslationServer.set_locale(lang)
		_out_dir = ProjectSettings.globalize_path("res://build/screens/%dx%d/%s" % [size.x, size.y, lang])
		DirAccess.make_dir_recursive_absolute(_out_dir)
		await _capture_all()
	DirAccess.remove_absolute(ProgressStore.storage_path)
	for problem in _problems:
		print("LAYOUT: ", problem)
	print("CAPTURE_DONE screens in build/screens, layout problems=", _problems.size())
	quit(0 if _problems.is_empty() else 1)


func _capture_all() -> void:
	_reset_progress([])
	await _shot("01_main_menu_new", "res://scenes/app/main.tscn")
	await _shot("02_settings", "res://scenes/screens/settings.tscn")
	await _shot("03_chapters_new", "res://scenes/screens/expedition_select.tscn")
	await _shot("04_chapter1_new", "res://scenes/screens/chapter_detail_01.tscn")
	await _shot("05_collection_new", "res://scenes/screens/collection.tscn")

	# Expedition 1 guided tutorial, then the plain HUD.
	var game := await _open("res://scenes/screens/game_screen.tscn")
	await _save_png("06_tutorial_expedition1", game)
	var tutorial := game.get_node("TutorialUI/OnboardingTutorial")
	(tutorial.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	await _save_png("07_tutorial_take_step", game)
	await _close(game)

	# Other expeditions: objective card, HUD, pause, rescue.
	game = await _open("res://scenes/screens/game_screen_ch2_01.tscn")
	await _save_png("08_objective_card", game)
	tutorial = game.get_node("TutorialUI/OnboardingTutorial")
	tutorial.call("_finish")
	await _frames(3)
	await _save_png("09_hud_chapter2", game)
	game.call("_open_pause")
	await _frames(3)
	await _save_png("10_pause", game)
	game.call("_close_pause")
	var session := game.get_node("GameSession") as GameSession
	session.call("_show_rescue_popup")
	await _frames(3)
	await _save_png("11_rescue", game)
	await _close(game)

	game = await _open("res://scenes/screens/game_screen_ch3_01.tscn")
	game.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	await _frames(3)
	await _save_png("12_hud_chapter3_roots", game)
	await _close(game)

	# Chapter I finale: victory with the chapter-complete block.
	_reset_progress(CHAPTER_ONE)
	game = await _open("res://scenes/screens/game_screen_06.tscn")
	game.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	session = game.get_node("GameSession") as GameSession
	session.call("_finish_victory")
	await create_timer(1.2).timeout  # score count-up and buttons slide in
	await _frames(3)
	await _save_png("13_victory_chapter_complete", game)
	await _close(game)

	# Screens with progress.
	await _shot("14_main_menu_continue", "res://scenes/app/main.tscn")
	await _shot("15_chapters_progress", "res://scenes/screens/expedition_select.tscn")
	await _shot("16_chapter2", "res://scenes/screens/chapter_detail_02.tscn")
	await _shot("17_chapter3", "res://scenes/screens/chapter_detail_03.tscn")
	await _shot("18_collection_progress", "res://scenes/screens/collection.tscn")

	# Endless Excavation: HUD mid-run with a streak, then the end-of-run result.
	ProgressStore.submit_endless_run(2400, 4)
	ProgressStore.submit_daily_run(ProgressStore.date_key(Time.get_date_dict_from_system()), 1800, true)
	game = await _open("res://scenes/screens/endless_screen.tscn")
	await _save_png("19a_endless_lobby", game)
	# Leaderboard window with sample data (the real one comes from Yandex).
	var board := game.get_node("ModalUI/EndlessLobby/LeaderboardPanel") as LeaderboardPanel
	board.show()
	board.show_data({
		"state": "ok",
		"authorized": true,
		"entries": [
			{"rank": 1, "name": "Анна К.", "score": 18450, "me": false},
			{"rank": 2, "name": "Археолог", "score": 15200, "me": false},
			{"rank": 3, "name": "Mikhail", "score": 12980, "me": false},
			{"rank": 4, "name": "Ольга", "score": 9100, "me": false},
			{"rank": 5, "name": "Вы", "score": 2400, "me": true},
		],
		"me": {"rank": 5, "score": 2400},
	})
	await _frames(3)
	await _save_png("19c_endless_leaderboard", game)
	board.hide()
	game.call("_start_run", false)
	await _frames(3)
	session = game.get_node("GameSession") as GameSession
	for cell in [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(1, 6), Vector2i(6, 0), Vector2i(7, 0), Vector2i(7, 1), Vector2i(4, 4), Vector2i(5, 4)]:
		session.board_model.place([Vector2i.ZERO] as Array[Vector2i], cell, Color(0.62, 0.42, 0.24))
	session.call("_sync_board_occupancy_view")
	session.score = 1350
	session.total_lines = 57
	session.depth = 5
	session.streak.register_move(1)
	session.streak.register_move(1)
	session.call("_update_score_label")
	session.call("_update_endless_hud")
	game.call("_set_layer_background", false)
	await _frames(3)
	await _save_png("19_endless_hud", game)
	# A dig spot with its countdown.
	session.excavation_model.add_dig_spot(&"spot_shot", Vector2i(3, 2), 1)
	session.endless_events.spots[&"spot_shot"] = {"cell": Vector2i(3, 2), "moves_left": 7, "deep": false, "find": null}
	session.call("_update_excavation_view", [Vector2i(3, 2)] as Array[Vector2i], false)
	session.board_view.set_cell_countdown(Vector2i(3, 2), 7)
	session.obstacle_model.set_obstacle(Vector2i(5, 6), 1)
	session.call("_sync_obstacle_view")
	await _frames(3)
	await _save_png("19b_endless_spot_stone", game)
	session.score = 2750
	session.streak.register_move(1)
	session.call("_finish_endless_run")
	await _frames(3)
	await _save_png("20_endless_result_record", game)
	await _close(game)

	# Site preparation: HUD and the "site ready" window; an excavation win with "clean".
	game = await _open("res://scenes/screens/game_screen_site_ruined_shrine_03.tscn")
	await _save_png("23_site_objective", game)
	game.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	await _frames(3)
	await _save_png("24_site_hud", game)
	# Hard: the move counter shows the limit.
	var site_session := game.get_node("GameSession") as GameSession
	site_session.move_limit = 24
	site_session.moves = 22
	site_session.call("_update_moves_label")
	await _frames(2)
	await _save_png("24b_hard_moves", game)
	site_session.move_limit = 0
	(game.get_node("GameSession") as GameSession).call("_finish_victory")
	await create_timer(1.2).timeout
	await _frames(3)
	await _save_png("25_site_ready", game)
	await _close(game)
	game = await _open("res://scenes/screens/game_screen_02.tscn")
	game.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	(game.get_node("GameSession") as GameSession).call("_finish_victory")
	await create_timer(1.2).timeout
	await _frames(3)
	await _save_png("26_victory_clean", game)
	await _close(game)

	# Restoration of the idol: brush, shards (two in place), scalpel, sponge.
	game = await _open("res://scenes/screens/restoration_screen.tscn")
	var restoration := game as RestorationScreen
	for y in range(30, 110, 9):
		restoration.rub_uv_line(Vector2(0.15, y / 256.0), Vector2(0.85, y / 256.0))
	await _frames(3)
	await _save_png("21_restoration_brush", game)
	await _rub_all(restoration, 3)
	await create_timer(1.3).timeout
	restoration.drop_shard(0, Vector2.ZERO)
	restoration.drop_shard(1, Vector2.ZERO)
	await create_timer(0.3).timeout
	await _save_png("21b_restoration_shards", game)
	for index in restoration.shard_count():
		restoration.drop_shard(index, Vector2.ZERO)
	await create_timer(1.4).timeout
	for y in range(40, 120, 6):
		restoration.rub_uv_line(Vector2(0.1, y / 256.0), Vector2(0.9, y / 256.0))
	await _frames(3)
	await _save_png("21c_restoration_scalpel", game)
	await _rub_all(restoration, 6)
	await create_timer(0.9).timeout
	for y in range(30, 110, 9):
		restoration.rub_uv_line(Vector2(0.15, y / 256.0), Vector2(0.85, y / 256.0))
	await _frames(3)
	await _save_png("22_restoration_sponge", game)
	await _close(game)


func _rub_all(screen: RestorationScreen, passes: int) -> void:
	for pass_index in passes:
		for y in range(0, 257, 5):
			screen.rub_uv_line(Vector2(0.0, y / 256.0), Vector2(1.0, y / 256.0))
		await _frames(1)
	await create_timer(0.8).timeout


func _reset_progress(completed: Array) -> void:
	DirAccess.remove_absolute(ProgressStore.storage_path)
	for expedition_id in completed:
		ProgressStore.mark_expedition_completed(expedition_id)
	if completed.size() >= 6:
		ProgressStore.claim_chapter_reward(&"ancient_courtyard", completed as Array[StringName], 0)


func _shot(file_name: String, scene_path: String) -> void:
	var node := await _open(scene_path)
	await _save_png(file_name, node)
	await _close(node)


func _open(scene_path: String) -> Node:
	var node := (load(scene_path) as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await _frames(4)
	return node


func _close(node: Node) -> void:
	root.remove_child(node)
	node.queue_free()
	current_scene = null
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _save_png(file_name: String, scene_root: Node) -> void:
	# Let pop-in and other short UI animations finish before the shot.
	await create_timer(0.45).timeout
	await _frames(1)
	var image := root.get_texture().get_image()
	image.save_png(_out_dir.path_join(file_name + ".png"))
	_check_layout(file_name, scene_root)


func _inside_scroll(control: Control) -> bool:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


## Text that does not fit: a Label/Button wider than its parent, a Button whose
## text needs more room than the button has, or a control outside the window
## (content of a ScrollContainer may continue below the window).
func _check_layout(screen: String, scene_root: Node) -> void:
	var view := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for node in scene_root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.get_global_rect().size == Vector2.ZERO:
			continue
		if not (control is Label or control is Button):
			continue
		var text: String = control.atr(control.text)
		if text.strip_edges().is_empty():
			continue
		var where := "%s/%s %s '%s'" % [_lang, screen, scene_root.get_path_to(control), text.replace("\n", " ")]
		var rect := control.get_global_rect()
		if not view.grow(1.0).encloses(rect) and not _inside_scroll(control):
			_problems.append("%s: outside the window %s" % [where, rect])
		var parent := control.get_parent() as Control
		if parent != null and parent is Container and rect.size.x > parent.get_global_rect().size.x + 1.0:
			_problems.append("%s: wider than its parent (%d > %d)" % [where, rect.size.x, parent.get_global_rect().size.x])
		if control is Button and control.get_minimum_size().x > rect.size.x + 1.0:
			_problems.append("%s: text needs %d px, button is %d px" % [where, control.get_minimum_size().x, rect.size.x])
		if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var label := control as Label
			var needed := label.get_theme_font("font").get_string_size(
				text, label.horizontal_alignment, -1, label.get_theme_font_size("font_size")
			).x
			if not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and needed > rect.size.x + 1.0:
				_problems.append("%s: text needs %d px, label is %d px" % [where, needed, rect.size.x])
