extends SceneTree

## Font trial: the same screens with other fonts, without changing the theme file.
##   godot --path . -s res://tools/font_trial.gd -- --size=390x844 --name=B \
##       --head=/abs/Head.ttf --body=/abs/Body.ttf --bold=/abs/BodyBold.ttf [--outline]
## Saves build/font_trial/<name>_<screen>.png (menu, game HUD, victory).
## The folder tools/ is not exported, so this never ships in the game.

const PROGRESS_PATH := "user://font_trial_progress.cfg"

var _args := {}


func _init() -> void:
	call_deferred("_run")


func _font(path: String) -> FontFile:
	var font := FontFile.new()
	font.load_dynamic_font(path)
	return font


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var size := Vector2i(390, 844)
	if _args.has("size"):
		var s: PackedStringArray = String(_args["size"]).split("x")
		size = Vector2i(int(s[0]), int(s[1]))
	DisplayServer.window_set_size(size)
	root.size = size
	var theme := ThemeDB.get_project_theme()
	if _args.has("body"):
		theme.default_font = _font(_args["body"])
	if _args.has("bold"):
		theme.set_font("font", "Button", _font(_args["bold"]))
	if _args.has("head"):
		theme.set_font("font", "HeaderLabel", _font(_args["head"]))
	if _args.has("outline"):
		theme.set_constant("outline_size", "PrimaryButton", 5)
		theme.set_color("font_outline_color", "PrimaryButton", Color(0.09, 0.2, 0.12, 0.9))
		theme.set_color("font_shadow_color", "HeaderLabel", Color(0.35, 0.2, 0.08, 0.35))
		theme.set_constant("shadow_offset_y", "HeaderLabel", 2)
		theme.set_constant("shadow_offset_x", "HeaderLabel", 0)
	TranslationServer.set_locale(_args.get("lang", "ru"))
	await _frames(3)
	var out := ProjectSettings.globalize_path("res://build/font_trial")
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join(".gdignore"), FileAccess.WRITE).store_string("")
	ProgressStore.storage_path = ProjectSettings.globalize_path(PROGRESS_PATH)
	ProgressStore.changed_hook = Callable()
	DirAccess.remove_absolute(ProgressStore.storage_path)
	var tag: String = _args.get("name", "trial")

	var node := await _open("res://scenes/app/main.tscn")
	await _save(out.path_join(tag + "_1menu.png"))
	await _close(node)

	node = await _open("res://scenes/screens/game_screen_ch2_01.tscn")
	node.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	await _frames(3)
	await _save(out.path_join(tag + "_2game.png"))
	await _close(node)

	for id in [&"expedition_01", &"expedition_02", &"expedition_03", &"expedition_04", &"expedition_05"]:
		ProgressStore.mark_expedition_completed(id)
	node = await _open("res://scenes/screens/game_screen_06.tscn")
	node.get_node("TutorialUI/OnboardingTutorial").call("_finish")
	(node.get_node("GameSession") as GameSession).call("_finish_victory")
	await _frames(3)
	await _save(out.path_join(tag + "_3victory.png"))
	await _close(node)
	DirAccess.remove_absolute(ProgressStore.storage_path)
	quit(0)


func _open(scene_path: String) -> Node:
	var node := (load(scene_path) as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await _frames(4)
	return node


func _close(node: Node) -> void:
	root.remove_child(node)
	node.queue_free()
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	await _frames(1)
	root.get_texture().get_image().save_png(path)
