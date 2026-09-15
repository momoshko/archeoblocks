extends Control

const WEB_PLAYTEST_BUILD := "M2.11-onboarding-3"


func _ready() -> void:
	if OS.has_feature("web") and OS.is_debug_build():
		print("Archeoblocks Web Playtest build=%s" % WEB_PLAYTEST_BUILD)
	%PlayButton.pressed.connect(_open_game)
	%ExpeditionsButton.pressed.connect(_open_expeditions)
	%CollectionButton.pressed.connect(_open_collection)
	%SettingsButton.pressed.connect(_open_settings)

func _open_game() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/game_screen.tscn")

func _open_expeditions() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/expedition_select.tscn")

func _open_collection() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/collection.tscn")

func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/settings.tscn")
