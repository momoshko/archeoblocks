extends "res://scripts/game_screen.gd"

## Endless Excavation screen (scenes/screens/endless_screen.tscn).
## Same board, tray, pause and result popup as an expedition; GameSession runs
## in endless mode because its endless_definition is set in the scene.


const BACKGROUND_FADE_SECONDS := 0.6

var _background_tween: Tween

@onready var lobby: EndlessLobby = $ModalUI/EndlessLobby


func _ready() -> void:
	super._ready()
	lobby.play_requested.connect(_start_run)
	lobby.menu_requested.connect(_back_to_menu)
	show_lobby()


## The start window: records, today's dig. The board waits behind it.
func show_lobby() -> void:
	%GameSession.set_input_blocked(true)
	Platform.gameplay_stop()
	lobby.refresh(%GameSession.endless_definition, Time.get_date_dict_from_system())
	lobby.show()
	lobby.move_to_front()


func _start_run(daily: bool) -> void:
	lobby.hide()
	%GameSession.daily_mode = daily
	%GameSession.restart_expedition()
	Platform.gameplay_start()


## The layer picture (EndlessLayer.background_texture) follows the depth.
func _apply_background() -> void:
	_set_layer_background(false)
	if not %GameSession.depth_changed.is_connected(_on_depth_changed):
		%GameSession.depth_changed.connect(_on_depth_changed)
	if not %GameSession.expedition_restarted.is_connected(_on_run_restarted):
		%GameSession.expedition_restarted.connect(_on_run_restarted)


func _on_depth_changed(_depth: int) -> void:
	_set_layer_background(true)


func _on_run_restarted() -> void:
	_set_layer_background(false)


func _set_layer_background(animated: bool) -> void:
	var definition: EndlessDefinition = %GameSession.endless_definition
	if definition == null:
		return
	var layer := definition.layer_for_depth(%GameSession.depth)
	if layer == null or layer.background_texture == null:
		return
	var background: TextureRect = $Background
	if background.texture == layer.background_texture:
		return
	if _background_tween != null:
		_background_tween.kill()
	if not animated:
		background.texture = layer.background_texture
		background.self_modulate = Color.WHITE
		return
	_background_tween = create_tween()
	_background_tween.tween_property(background, "self_modulate", Color.BLACK, BACKGROUND_FADE_SECONDS * 0.5)
	_background_tween.tween_callback(func() -> void: background.texture = layer.background_texture)
	_background_tween.tween_property(background, "self_modulate", Color.WHITE, BACKGROUND_FADE_SECONDS * 0.5)


func _start_music() -> void:
	AudioManager.play_music_track(&"gameplay_endless", &"gameplay")


## "Ещё раз" after a finished run is a logical pause: a fullscreen ad may show
## (Platform keeps its own limits, e.g. never right after a rewarded video).
## Restart from the pause menu starts at once.
func _restart_expedition() -> void:
	var run_finished: bool = $ModalUI/ResultPopup.visible and %GameSession.is_no_moves_state()
	if run_finished:
		%GameSession.set_input_blocked(true)
		await Platform.show_interstitial()
		if not is_inside_tree():
			return
	super._restart_expedition()
