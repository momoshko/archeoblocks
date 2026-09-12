extends Control

func _ready() -> void:
	%BackButton.pressed.connect(_back_to_menu)

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")

