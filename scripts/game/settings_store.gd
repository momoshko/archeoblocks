class_name SettingsStore
extends RefCounted

## Player preferences that are not campaign progress (sound, music, language).

const DEFAULT_STORAGE_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const GENERAL_SECTION := "general"

const DEFAULT_VOLUME := 0.8

static var storage_path := DEFAULT_STORAGE_PATH


static func is_music_enabled() -> bool:
	return bool(_load().get_value(AUDIO_SECTION, "music_enabled", true))


static func is_sfx_enabled() -> bool:
	return bool(_load().get_value(AUDIO_SECTION, "sfx_enabled", true))


## Volume 0..1 (the slider in Settings). 0 counts as "off".
static func get_music_volume() -> float:
	return clampf(float(_load().get_value(AUDIO_SECTION, "music_volume", DEFAULT_VOLUME)), 0.0, 1.0)


static func get_sfx_volume() -> float:
	return clampf(float(_load().get_value(AUDIO_SECTION, "sfx_volume", DEFAULT_VOLUME)), 0.0, 1.0)


static func set_music_volume(volume: float) -> Error:
	return _save_value(AUDIO_SECTION, "music_volume", clampf(volume, 0.0, 1.0))


static func set_sfx_volume(volume: float) -> Error:
	return _save_value(AUDIO_SECTION, "sfx_volume", clampf(volume, 0.0, 1.0))


static func set_music_enabled(enabled: bool) -> Error:
	return _save_value(AUDIO_SECTION, "music_enabled", enabled)


static func set_sfx_enabled(enabled: bool) -> Error:
	return _save_value(AUDIO_SECTION, "sfx_enabled", enabled)


## "ru" / "en" chosen by the player, or "" when the game should detect it.
static func get_language() -> String:
	return String(_load().get_value(GENERAL_SECTION, "language", ""))


static func set_language(code: String) -> Error:
	return _save_value(GENERAL_SECTION, "language", code)


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(storage_path)
	return config


static func _save_value(section: String, key: String, value: Variant) -> Error:
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(section, key, value)
	return config.save(storage_path)
