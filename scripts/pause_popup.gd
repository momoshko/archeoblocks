extends Control

signal resume_requested
signal menu_requested

func _ready() -> void:
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%MenuButton.pressed.connect(func() -> void: menu_requested.emit())

