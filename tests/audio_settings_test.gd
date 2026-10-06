extends SceneTree

const TEST_SETTINGS_PATH := "res://tests/.audio_settings.cfg"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _bus_muted(bus_name: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name))


func _run() -> void:
	SettingsStore.storage_path = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(SettingsStore.storage_path)
	var audio := root.get_node_or_null("AudioManager")
	_expect(audio != null, "AudioManager autoload should exist")
	_expect(AudioServer.get_bus_index(&"Music") > 0 and AudioServer.get_bus_index(&"SFX") > 0, "Music and SFX buses should exist")
	audio.apply_settings()
	_expect(audio.is_music_enabled() and audio.is_sfx_enabled(), "Sound is on by default")
	for sound_name in audio.KNOWN_SOUNDS:
		_expect(audio._load_sound(sound_name) != null, "Sound %s should load" % sound_name)

	# Settings sliders save the volume, set the bus level and mute at zero.
	var settings := load("res://scenes/screens/settings.tscn").instantiate() as Control
	root.add_child(settings)
	await process_frame
	var music_slider := settings.get_node("%MusicSlider") as HSlider
	var sound_slider := settings.get_node("%SoundSlider") as HSlider
	_expect(settings.get_node("%LanguageRow").visible, "Language row is shown now that English exists")
	_expect(is_equal_approx(music_slider.value, 80.0), "Music slider starts at the default 80%")
	music_slider.value = 50.0
	_expect(is_equal_approx(SettingsStore.get_music_volume(), 0.5), "Music slider saves its volume")
	_expect(not _bus_muted(&"Music") and is_equal_approx(_bus_db(&"Music"), linear_to_db(0.25)), "Half the slider is a quarter of the power (squared curve)")
	_expect((settings.get_node("%MusicValue") as Label).text == "50%", "Music value shows the percent")
	music_slider.value = 0.0
	_expect(not SettingsStore.is_music_enabled() and _bus_muted(&"Music"), "Music slider at zero mutes the Music bus")
	_expect((settings.get_node("%MusicValue") as Label).text == "Выкл.", "Zero reads Off")
	sound_slider.value = 0.0
	_expect(not SettingsStore.is_sfx_enabled() and _bus_muted(&"SFX"), "Sound slider at zero mutes the SFX bus")
	settings.queue_free()
	await process_frame

	# Pause popup button turns all sound back on at once.
	var pause := load("res://scenes/ui/pause_popup.tscn").instantiate() as Control
	root.add_child(pause)
	await process_frame
	var sound_button := pause.get_node("%SoundButton") as Button
	_expect(sound_button.text == "Звук: выкл.", "Pause button reflects muted sound")
	sound_button.pressed.emit()
	_expect(SettingsStore.is_music_enabled() and SettingsStore.is_sfx_enabled(), "Pause button enables all sound")
	_expect(not _bus_muted(&"Music") and not _bus_muted(&"SFX"), "Buses are unmuted again (sliders left at zero go back to 80%)")
	_expect(sound_button.text == "Звук: вкл.", "Pause button reflects enabled sound")
	pause.queue_free()

	# Focus loss mutes everything and focus return restores it.
	audio.set_muted_for(&"focus", true)
	_expect(AudioServer.is_bus_mute(0), "Master is muted while unfocused")
	audio.set_muted_for(&"ad", true)
	audio.set_muted_for(&"focus", false)
	_expect(AudioServer.is_bus_mute(0), "Master stays muted while an ad is still showing")
	audio.set_muted_for(&"ad", false)
	_expect(not AudioServer.is_bus_mute(0), "Master unmutes when no reason remains")

	# Gameplay emits feedback cues for a placement and a line clear.
	var game := load("res://scenes/screens/game_screen_02.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var events: Array[StringName] = []
	session.feedback_event.connect(func(kind: StringName, _strength: int) -> void: events.append(kind))
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	session.piece_tray.load_set([single, single, single] as Array[PieceDefinition])
	var shape: Array[Vector2i] = [Vector2i.ZERO]
	for x in 7:
		session.board_model.place(shape, Vector2i(x, 5), Color.DARK_GREEN)
	_expect(session.try_place_piece(0, Vector2i(7, 5)), "Line move should place")
	await create_timer(1.0).timeout
	_expect(events.has(&"place") and events.has(&"line_clear"), "Placement and line clear emit feedback cues")
	game.queue_free()
	await process_frame

	# Music: missing tracks are silent, a stream loops and plays after the fade.
	_expect(audio.find_music(&"no_such_track_for_tests") == null, "Missing music file gives no stream")
	audio.play_music_track(&"no_such_track_for_tests", &"also_missing")
	_expect(audio.current_music_track() == &"", "Missing tracks leave music silent without errors")
	var tone := AudioStreamWAV.new()
	tone.mix_rate = 8000
	tone.format = AudioStreamWAV.FORMAT_8_BITS
	var samples := PackedByteArray()
	samples.resize(8000)
	tone.data = samples
	audio.play_music(tone)
	# A real track may still be playing (it fades out first, half a fade).
	await create_timer(audio.MUSIC_FADE_SECONDS * 0.5 + 0.2).timeout
	_expect(audio.music_player.stream == tone and audio.music_player.playing, "Music stream starts after the fade")
	_expect(tone.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
	audio.play_music(null)
	await create_timer(0.6).timeout
	_expect(not audio.music_player.playing, "play_music(null) fades the music out")

	DirAccess.remove_absolute(SettingsStore.storage_path)
	SettingsStore.storage_path = SettingsStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("AUDIO_SETTINGS_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))
