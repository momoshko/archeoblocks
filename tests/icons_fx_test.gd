extends SceneTree

## Gemini icons on the buttons and the light board effects (icon/FX sheets L1-L4).

const ICON_DIR := "res://assets/ui_art/icons/"
const FX_DIR := "res://assets/ui_art/fx/"
## Runtime sprites stay small: the Web build downloads all of them.
const MAX_SPRITE_BYTES := 100000  # 256 px light burst is ~92 KB

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	_check_sprite_files()
	await _check_game_screen()
	await _check_back_buttons()
	await _check_locks()
	await _check_restoration_tools()
	if _failures.is_empty():
		print("ICONS_FX_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_sprite_files() -> void:
	for dir_path in [ICON_DIR, FX_DIR]:
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".png"):
				continue
			var path: String = dir_path + file_name
			var bytes := FileAccess.get_file_as_bytes(path).size()
			_expect(bytes > 0 and bytes <= MAX_SPRITE_BYTES, "%s should be a small runtime sprite (%d bytes)" % [path, bytes])
			_expect(load(path) is Texture2D, "%s should import as a texture" % path)


func _check_game_screen() -> void:
	var game := (load("res://scenes/screens/game_screen_ch2_01.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var pause := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/PauseButton") as Button
	_expect(pause.icon != null and pause.text.is_empty(), "Pause should be an icon-only button")
	_expect(not pause.tooltip_text.is_empty(), "Icon-only Pause keeps a tooltip")
	for path in ["ContentCenter/PortraitContent/MainLayout/Actions/UndoButton", "ContentCenter/PortraitContent/MainLayout/Actions/HintButton"]:
		var button := game.get_node(path) as Button
		_expect(button.icon != null and button.text.is_empty() and not button.tooltip_text.is_empty(), "%s should be a round icon button with a tooltip" % path)
		_expect(button is RoundActionButton and not (button as RoundActionButton).badge_text().is_empty(), "%s should show a counter badge" % path)

	# Pause popup: the sound icon follows the sound state.
	var pause_popup := game.get_node("ModalUI/PausePopup")
	var sound_button := pause_popup.get_node("%SoundButton") as Button
	pause_popup.call("_refresh_sound_button")
	var enabled: bool = root.get_node("AudioManager").call("is_any_sound_enabled")
	_expect(sound_button.icon == (pause_popup.sound_on_icon if enabled else pause_popup.sound_off_icon), "Sound button icon should match the sound state")

	# Board effects: one-shot particles start on a line clear, a dig and a find.
	var session := game.get_node("GameSession") as GameSession
	var board := session.board_view
	var fx := game.get_node("FeedbackUI/BoardFx") as BoardFx
	_expect(fx != null, "Game screen should have the BoardFx layer")
	var row: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		row.append(Vector2i(x, 0))
	board.clear_cells_with_feedback(row)
	_expect(_any_emitting(fx, "Dust"), "Line clear should raise dust")
	_expect(_any_emitting(fx, "Chips"), "Line clear should throw a few stone chips")
	for emitter in fx.find_children("*", "CPUParticles2D", false, false):
		var particles := emitter as CPUParticles2D
		_expect(particles.one_shot, "%s should be one-shot" % particles.name)
		_expect(particles.amount <= fx.max_particles, "%s should stay light (%d particles)" % [particles.name, particles.amount])
	board.reset_game_state()
	_expect(not _any_emitting(fx, "Dust"), "Restart should clear running effects")
	board.set_excavation_cell(Vector2i(3, 3), 1, false, false, false, true)
	await process_frame
	_expect(_any_emitting(fx, "Dust"), "Dug soil should raise dust")
	var find_cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2)]
	board.show_fragment_found_feedback(find_cells)
	_expect((fx.get_node("Sparkles") as CPUParticles2D).emitting, "An uncovered fragment should sparkle")
	_expect((fx.get_node("LightBurst") as CanvasItem).visible, "An uncovered fragment should flash a light burst")

	# Victory window: the find glows; closing the window stops it.
	var result := session.result_popup
	result.show_victory("Test", 0, 0, load("res://assets/artifacts/ancient_courtyard/golden_mask_full_v1.png") as Texture2D)
	await process_frame
	var glow := result.find_glow
	_expect(glow.get_node("Sparkles").emitting, "Victory find should sparkle")
	_expect(result.next_button.icon == result.next_icon, "Victory 'Дальше' should show the play icon")
	result.close_popup()
	await process_frame
	_expect(not glow.get_node("Sparkles").emitting, "Closed victory window should stop its effects")
	result.show_rescue("0 / 2", false, false, false)
	_expect(result.next_button.icon == result.menu_icon, "Rescue 'В меню' should show the home icon")
	result.close_popup()

	game.queue_free()
	await process_frame


func _any_emitting(fx: BoardFx, prefix: String) -> bool:
	for child in fx.get_children():
		if child is CPUParticles2D and String(child.name).begins_with(prefix) and child.emitting:
			return true
	return false


func _check_back_buttons() -> void:
	for scene_path in [
		"res://scenes/screens/settings.tscn",
		"res://scenes/screens/collection.tscn",
		"res://scenes/screens/expedition_select.tscn",
		"res://scenes/screens/chapter_detail_01.tscn",
	]:
		var screen := (load(scene_path) as PackedScene).instantiate() as Control
		root.add_child(screen)
		await process_frame
		var back := screen.get_node("%BackButton") as Button
		_expect(back.icon != null and back.text.is_empty() and not back.tooltip_text.is_empty(), "%s Back should be an arrow icon with a tooltip" % scene_path)
		screen.queue_free()
		await process_frame


func _check_locks() -> void:
	var detail := (load("res://scenes/screens/chapter_detail_01.tscn") as PackedScene).instantiate() as Control
	root.add_child(detail)
	await process_frame
	for button_name in ["Expedition01", "Expedition02"]:
		var button := detail.get_node("%" + button_name) as Button
		var lock := button.get_node("LockIcon") as CanvasItem
		if button.visible:
			_expect(lock.visible == button.disabled, "%s padlock should show exactly when it is closed" % button_name)
	detail.queue_free()
	await process_frame


func _check_restoration_tools() -> void:
	var screen := (load("res://scenes/screens/restoration_screen.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	await process_frame
	var brush := screen.get_node("%BrushIcon") as CanvasItem
	var sponge := screen.get_node("%SpongeIcon") as CanvasItem
	var scalpel := screen.get_node("%ScalpelIcon") as CanvasItem
	var shards := screen.get_node("%ShardsIcon") as CanvasItem
	_expect(brush.visible and not sponge.visible and not shards.visible, "Soil stage shows the brush")
	screen.call("_set_stage", RestorationScreen.Stage.SHARDS)
	_expect(shards.visible and not brush.visible and not sponge.visible, "Shards stage shows the shards icon")
	screen.call("_set_stage", RestorationScreen.Stage.CRUST)
	_expect(scalpel.visible and not brush.visible, "Crust stage shows the scalpel")
	screen.call("_set_stage", RestorationScreen.Stage.PATINA)
	_expect(sponge.visible and not brush.visible and not scalpel.visible, "Patina stage shows the sponge")
	screen.call("_set_stage", RestorationScreen.Stage.SHINE)
	_expect(not sponge.visible and not brush.visible and not scalpel.visible and not shards.visible, "Shine stage hides the tools")
	screen.queue_free()
	await process_frame
