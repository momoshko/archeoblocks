extends Node

## Global audio: music and sound-effect playback, player sound settings and
## muting while the game is not in focus (Yandex requirement 1.3 / 4.7).
## Sounds are looked up by file name in SFX_DIR, so a sound can be replaced by
## dropping a new file with the same name (.ogg wins over .wav, so a chosen
## pack sound replaces the old synthesized one without deleting it).

signal settings_changed

const SFX_DIR := "res://assets/audio/sfx/"
## Music files are looked up by track name in MUSIC_DIR: menu.ogg, gameplay.ogg,
## and optionally gameplay_<chapter id>.ogg (.ogg, .mp3 or .wav). Missing files
## simply mean silence, so the game works before the tracks are added.
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const MUSIC_FADE_SECONDS := 0.8
const MUSIC_VOLUME_DB := -6.0
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const MIN_AUDIBLE_VOLUME := 0.01
const KNOWN_SOUNDS: Array[StringName] = [
	&"ui_click", &"pick", &"place", &"invalid", &"line_clear", &"line_clear_multi",
	&"dig", &"stone_hit", &"stone_break", &"root_cut", &"root_grow",
	&"fragment_found", &"victory", &"no_moves",
	# Restoration tools (RestorationScreen).
	&"restore_brush", &"restore_scalpel", &"restore_sponge", &"restore_snap",
]
## Silent until a file with this name exists (see audio_review/sfx_candidates).
const OPTIONAL_SOUNDS: Array[StringName] = [
	&"popup_open", &"score_count", &"hint", &"streak",
]
const SFX_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_players_root: Node = $SfxPlayers

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _sounds: Dictionary = {}
var _mute_reasons: Dictionary = {}
var _music_track: StringName = &""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in sfx_players_root.get_children():
		if child is AudioStreamPlayer:
			_sfx_players.append(child)
	for sound_name in KNOWN_SOUNDS + OPTIONAL_SOUNDS:
		_load_sound(sound_name)
	apply_settings()
	get_tree().node_added.connect(_on_node_added)


func apply_settings() -> void:
	_apply_bus(MUSIC_BUS, SettingsStore.is_music_enabled(), SettingsStore.get_music_volume())
	_apply_bus(SFX_BUS, SettingsStore.is_sfx_enabled(), SettingsStore.get_sfx_volume())
	settings_changed.emit()


func get_music_volume() -> float:
	return SettingsStore.get_music_volume()


func get_sfx_volume() -> float:
	return SettingsStore.get_sfx_volume()


## Settings slider. Moving it above zero also switches the sound back on.
func set_music_volume(volume: float) -> void:
	SettingsStore.set_music_volume(volume)
	SettingsStore.set_music_enabled(volume > MIN_AUDIBLE_VOLUME)
	apply_settings()


func set_sfx_volume(volume: float) -> void:
	SettingsStore.set_sfx_volume(volume)
	SettingsStore.set_sfx_enabled(volume > MIN_AUDIBLE_VOLUME)
	apply_settings()


func is_music_enabled() -> bool:
	return SettingsStore.is_music_enabled()


func is_sfx_enabled() -> bool:
	return SettingsStore.is_sfx_enabled()


func set_music_enabled(enabled: bool) -> void:
	SettingsStore.set_music_enabled(enabled)
	apply_settings()


func set_sfx_enabled(enabled: bool) -> void:
	SettingsStore.set_sfx_enabled(enabled)
	apply_settings()


func is_any_sound_enabled() -> bool:
	return is_music_enabled() or is_sfx_enabled()


## One switch for players who just want silence (pause menu button).
func set_all_sound_enabled(enabled: bool) -> void:
	SettingsStore.set_music_enabled(enabled)
	SettingsStore.set_sfx_enabled(enabled)
	# Switching on with a slider left at zero would still be silent.
	if enabled and SettingsStore.get_music_volume() <= MIN_AUDIBLE_VOLUME:
		SettingsStore.set_music_volume(SettingsStore.DEFAULT_VOLUME)
	if enabled and SettingsStore.get_sfx_volume() <= MIN_AUDIBLE_VOLUME:
		SettingsStore.set_sfx_volume(SettingsStore.DEFAULT_VOLUME)
	apply_settings()


func has_sfx(sound_name: StringName) -> bool:
	return _load_sound(sound_name) != null


func play_sfx(sound_name: StringName, pitch_scale := 1.0) -> void:
	if _sfx_players.is_empty():
		return
	var stream := _load_sound(sound_name)
	if stream == null:
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()


func play_music(stream: AudioStream) -> void:
	if stream == null:
		_fade_out_music()
		return
	if music_player.stream == stream and music_player.playing:
		return
	_enable_loop(stream)
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween()
	if music_player.playing:
		_music_tween.tween_property(music_player, "volume_db", -40.0, MUSIC_FADE_SECONDS * 0.5)
	_music_tween.tween_callback(func() -> void:
		music_player.stream = stream
		music_player.volume_db = -40.0
		music_player.play()
	)
	_music_tween.tween_property(music_player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_SECONDS)


## Plays a named track (see MUSIC_DIR). Each candidate is tried in order, so
## play_music_track(&"gameplay_ruined_shrine", &"gameplay") falls back to the
## common gameplay track. Calling it again with the playing track does nothing.
func play_music_track(track: StringName, fallback: StringName = &"") -> void:
	for candidate in [track, fallback]:
		if String(candidate).is_empty():
			continue
		var stream := find_music(candidate)
		if stream != null:
			if _music_track == candidate and music_player.playing:
				return
			_music_track = candidate
			play_music(stream)
			return
	_music_track = &""
	_fade_out_music()


func current_music_track() -> StringName:
	return _music_track


static func find_music(track: StringName) -> AudioStream:
	for extension in MUSIC_EXTENSIONS:
		var path := "%s%s.%s" % [MUSIC_DIR, track, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


func _fade_out_music() -> void:
	if not music_player.playing:
		music_player.stop()
		return
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -40.0, MUSIC_FADE_SECONDS * 0.5)
	_music_tween.tween_callback(music_player.stop)


static func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if wav.loop_end == 0:
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set("loop", true)


## Mutes everything while any reason is active: lost focus, platform pause, ad.
func set_muted_for(reason: StringName, muted: bool) -> void:
	if muted:
		_mute_reasons[reason] = true
	else:
		_mute_reasons.erase(reason)
	AudioServer.set_bus_mute(0, not _mute_reasons.is_empty())


func is_muted_for(reason: StringName) -> bool:
	return _mute_reasons.has(reason)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			set_muted_for(&"focus", true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			set_muted_for(&"focus", false)


func _load_sound(sound_name: StringName) -> AudioStream:
	if _sounds.has(sound_name):
		return _sounds[sound_name]
	var stream: AudioStream = null
	for extension in SFX_EXTENSIONS:
		var path := "%s%s.%s" % [SFX_DIR, sound_name, extension]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_sounds[sound_name] = stream
	return stream


func _apply_bus(bus_name: StringName, enabled: bool, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, not enabled or volume <= MIN_AUDIBLE_VOLUME)
	# Squared curve: the slider feels even (half way sounds about half as loud).
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume * volume, 0.0001)))




func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.is_in_group(&"no_click_sound"):
		# button_down (not pressed) keeps the click instant and leaves pressed free for game logic.
		(node as BaseButton).button_down.connect(_on_any_button_pressed)


func _on_any_button_pressed() -> void:
	play_sfx(&"ui_click")
