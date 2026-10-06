extends Control

## Settings: music and sound volume (sliders), language; saved between sessions.

## Order matches the items of LanguageOption in settings.tscn.
const LANGUAGE_CODES: Array[String] = ["ru", "en"]

@onready var music_slider: HSlider = %MusicSlider
@onready var sound_slider: HSlider = %SoundSlider
@onready var language_row: Control = %LanguageRow
@onready var language_option: OptionButton = %LanguageOption
@onready var note_label: Label = %Note


func _ready() -> void:
	AudioManager.play_music_track(&"menu")
	%BackButton.pressed.connect(_back_to_menu)
	language_row.show()
	note_label.hide()
	language_option.select(maxi(0, LANGUAGE_CODES.find(Locale.current())))
	language_option.item_selected.connect(_on_language_selected)
	Locale.language_changed.connect(_on_language_changed)
	# Switched off (pause menu) shows as 0; the saved level comes back when moved.
	music_slider.set_value_no_signal(_percent(AudioManager.is_music_enabled(), AudioManager.get_music_volume()))
	sound_slider.set_value_no_signal(_percent(AudioManager.is_sfx_enabled(), AudioManager.get_sfx_volume()))
	music_slider.value_changed.connect(_on_music_changed)
	sound_slider.value_changed.connect(_on_sound_changed)
	# A sample at the new level once the finger lets go (not on every step).
	sound_slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_sfx(&"ui_click"))
	_refresh_labels()


static func _percent(enabled: bool, volume: float) -> float:
	return roundf(volume * 100.0) if enabled else 0.0


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	_refresh_labels()


func _on_sound_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	_refresh_labels()


func _on_language_selected(index: int) -> void:
	if index >= 0 and index < LANGUAGE_CODES.size():
		Locale.set_language(LANGUAGE_CODES[index])


func _on_language_changed(_code: String) -> void:
	# Scene Labels switch by themselves; texts set from code are refreshed here.
	_refresh_labels()


func _refresh_labels() -> void:
	%MusicValue.text = _value_text(music_slider.value)
	%SoundValue.text = _value_text(sound_slider.value)


func _value_text(value: float) -> String:
	return tr("Выкл.") if value <= 0.0 else "%d%%" % int(value)


func _back_to_menu() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/app/main.tscn")
