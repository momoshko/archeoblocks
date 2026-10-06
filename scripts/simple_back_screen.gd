extends Control

func _ready() -> void:
	%BackButton.pressed.connect(_back_to_menu)

func _back_to_menu() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/app/main.tscn")

