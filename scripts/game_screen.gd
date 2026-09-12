extends Control

func _ready() -> void:
	%PauseButton.pressed.connect(_open_pause)
	%PausePopup.resume_requested.connect(_close_pause)
	%PausePopup.menu_requested.connect(_back_to_menu)

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
