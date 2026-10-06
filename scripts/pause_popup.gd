extends Control

signal resume_requested
signal restart_requested
signal menu_requested

## Icons of the sound button, picked in the scene.
@export var sound_on_icon: Texture2D
@export var sound_off_icon: Texture2D

@onready var sound_button: Button = %SoundButton


func _ready() -> void:
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%MenuButton.pressed.connect(func() -> void: menu_requested.emit())
	sound_button.pressed.connect(_toggle_sound)
	visibility_changed.connect(_refresh_sound_button)
	_refresh_sound_button()


func _toggle_sound() -> void:
	AudioManager.set_all_sound_enabled(not AudioManager.is_any_sound_enabled())
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	var enabled := AudioManager.is_any_sound_enabled()
	sound_button.text = tr("Звук: вкл.") if enabled else tr("Звук: выкл.")
	sound_button.icon = sound_on_icon if enabled else sound_off_icon
