extends Control

@export_file("*.tscn") var next_expedition_scene_path := ""

func _ready() -> void:
	%PauseButton.pressed.connect(_open_pause)
	%PausePopup.resume_requested.connect(_close_pause)
	%PausePopup.restart_requested.connect(_restart_expedition)
	%PausePopup.menu_requested.connect(_back_to_menu)
	$ModalUI/ResultPopup.retry_requested.connect(_restart_expedition)
	$ModalUI/ResultPopup.next_requested.connect(_open_next_expedition)

func _open_pause() -> void:
	%GameSession.set_input_blocked(true)
	%PausePopup.show()
	%PausePopup.move_to_front()

func _close_pause() -> void:
	%PausePopup.hide()
	%GameSession.set_input_blocked(false)

func _back_to_menu() -> void:
	%GameSession.set_input_blocked(true)
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")

func _open_next_expedition() -> void:
	%GameSession.set_input_blocked(true)
	if next_expedition_scene_path.is_empty():
		get_tree().change_scene_to_file("res://scenes/screens/expedition_select.tscn")
	else:
		get_tree().change_scene_to_file(next_expedition_scene_path)

func _restart_expedition() -> void:
	%PausePopup.hide()
	$ModalUI/ResultPopup.close_popup()
	%GameSession.restart_expedition()
