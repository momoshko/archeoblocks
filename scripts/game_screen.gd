extends Control

@export_file("*.tscn") var next_expedition_scene_path := ""


func _ready() -> void:
	_apply_background()
	_start_music()
	%PauseButton.pressed.connect(_open_pause)
	%PausePopup.resume_requested.connect(_close_pause)
	%PausePopup.restart_requested.connect(_restart_expedition)
	%PausePopup.menu_requested.connect(_back_to_menu)
	$ModalUI/ResultPopup.retry_requested.connect(_restart_expedition)
	$ModalUI/ResultPopup.next_requested.connect(_open_next_expedition)
	$ModalUI/ResultPopup.menu_requested.connect(_back_to_menu)
	$ModalUI/ResultPopup.clean_requested.connect(_open_restoration)
	%GameSession.victory_reached.connect(Platform.gameplay_stop)
	%GameSession.no_moves_reached.connect(Platform.gameplay_stop)
	%GameSession.turn_undone.connect(Platform.gameplay_start)
	Platform.paused_by_platform.connect(_on_platform_paused)
	Platform.gameplay_start()


## The chapter picture behind the board (ChapterDefinition.background_texture);
## without one the scene keeps its own background.
func _apply_background() -> void:
	var chapter: ChapterDefinition = %GameSession.chapter_definition
	if chapter != null and chapter.background_texture != null:
		$Background.texture = chapter.background_texture


## Chapter track if present (gameplay_<chapter id>), otherwise the common one.
func _start_music() -> void:
	var chapter: ChapterDefinition = %GameSession.chapter_definition
	var chapter_track := StringName("gameplay_%s" % chapter.id) if chapter != null else &""
	AudioManager.play_music_track(chapter_track, &"gameplay")


func _exit_tree() -> void:
	Platform.gameplay_stop()


func _open_pause() -> void:
	Platform.gameplay_stop()
	%GameSession.set_input_blocked(true)
	%PausePopup.show()
	%PausePopup.move_to_front()


func _close_pause() -> void:
	%PausePopup.hide()
	%GameSession.set_input_blocked(false)
	Platform.gameplay_start()


## Tab hidden, ad opened or platform dialog: stop the run behind the pause menu.
func _on_platform_paused() -> void:
	if %PausePopup.visible or $ModalUI/ResultPopup.visible:
		return
	_open_pause()


func _back_to_menu() -> void:
	%GameSession.set_input_blocked(true)
	Platform.gameplay_stop()
	ScreenCache.change_to(get_tree(), "res://scenes/app/main.tscn")


func _open_next_expedition() -> void:
	%GameSession.set_input_blocked(true)
	Platform.gameplay_stop()
	# A completed expedition is the logical pause for a fullscreen ad.
	await Platform.show_interstitial()
	if not is_inside_tree():
		return
	if next_expedition_scene_path.is_empty():
		ScreenCache.change_to(get_tree(), "res://scenes/screens/expedition_select.tscn")
	else:
		ScreenCache.change_to(get_tree(), next_expedition_scene_path)


## After an excavation: clean the find, then go on where "Дальше" would lead.
func _open_restoration() -> void:
	%GameSession.set_input_blocked(true)
	Platform.gameplay_stop()
	RestorationScreen.pending_expedition = %GameSession.expedition_definition
	RestorationScreen.pending_return_scene = (
		next_expedition_scene_path
		if not next_expedition_scene_path.is_empty()
		else "res://scenes/screens/expedition_select.tscn"
	)
	ScreenCache.change_to(get_tree(), "res://scenes/screens/restoration_screen.tscn")


func _restart_expedition() -> void:
	%PausePopup.hide()
	$ModalUI/ResultPopup.close_popup()
	%GameSession.restart_expedition()
	Platform.gameplay_start()
