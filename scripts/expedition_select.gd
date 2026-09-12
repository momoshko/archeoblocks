extends Control

func _ready() -> void:
	%BackButton.pressed.connect(_back_to_menu)
	%Expedition01.pressed.connect(_open_game)

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")

func _open_game() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")

