extends Control

const WEB_PLAYTEST_BUILD := "M2.11-onboarding-3"
const ENDLESS_SCENE_PATH := "res://scenes/screens/endless_screen.tscn"
const ENDLESS_DEFINITION: EndlessDefinition = preload("res://resources/endless/endless_default.tres")


func _ready() -> void:
	# First start only: load the menus and the game screen now, while the
	# loading screen is up, so every later screen opens without a pause.
	ScreenCache.warm_up()
	AudioManager.play_music_track(&"menu")
	if OS.has_feature("web") and OS.is_debug_build():
		print("Archeoblocks Web Playtest build=%s" % WEB_PLAYTEST_BUILD)
	%PlayButton.pressed.connect(_open_game)
	%EndlessButton.pressed.connect(_open_endless)
	%ExpeditionsButton.pressed.connect(_open_expeditions)
	%CollectionButton.pressed.connect(_open_collection)
	%SettingsButton.pressed.connect(_open_settings)
	_refresh_play_button()
	_refresh_endless_button()
	# SDK init and cloud progress merge happen once, before the first real screen.
	await Platform.boot()
	if not is_inside_tree():
		return
	_refresh_play_button()
	_refresh_endless_button()
	Platform.notify_loading_ready()


func _refresh_play_button() -> void:
	%PlayButton.text = tr("Продолжить") if CampaignRoute.has_progress() else tr("Играть")
	# Under the big button: where it leads, and the find waiting there.
	var next := CampaignRoute.next_expedition()
	%NextExpeditionLabel.text = tr(next.title_ru) if next != null else tr("Все экспедиции пройдены")
	var level := Difficulty.current()
	if next == null and level + 1 < Difficulty.COUNT and Difficulty.is_unlocked(level + 1):
		%NextExpeditionLabel.text = tr("Открыта сложность: %s!") % tr(Difficulty.name_ru(level + 1))
	elif Difficulty.is_unlocked(Difficulty.Level.MEDIUM):
		%NextExpeditionLabel.text += " · " + tr(Difficulty.name_ru(level))
	%FindPicture.texture = next.full_artifact_texture if next != null else null
	%FindPicture.visible = %FindPicture.texture != null

## Endless Excavation opens after the expedition that teaches lines and soil.
static func is_endless_unlocked() -> bool:
	return ProgressStore.is_expedition_completed_any(ENDLESS_DEFINITION.unlock_expedition_id)


func _refresh_endless_button() -> void:
	var unlocked := is_endless_unlocked()
	%EndlessButton.disabled = not unlocked
	%EndlessLockHint.visible = not unlocked
	%LockBadge.visible = not unlocked


func _open_endless() -> void:
	if not is_endless_unlocked():
		return
	ScreenCache.change_to(get_tree(), ENDLESS_SCENE_PATH)

func _open_game() -> void:
	ScreenCache.change_to(get_tree(), CampaignRoute.play_scene_path())

func _open_expeditions() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/screens/expedition_select.tscn")

func _open_collection() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/screens/collection.tscn")

func _open_settings() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/screens/settings.tscn")
