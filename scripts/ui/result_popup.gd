class_name ResultPopup
extends Control

signal retry_requested
signal next_requested
signal undo_requested
signal menu_requested
## "Очистить находку" after an excavation: open the restoration of this find.
signal clean_requested

## Icons of the right button: "Дальше" (next expedition) and "В меню".
@export var next_icon: Texture2D
@export var menu_icon: Texture2D

## Victory celebration: the score counts up, confetti falls, the buttons
## slide in after a short pause so the find is seen first.
@export_range(0.0, 2.0, 0.05) var buttons_delay := 0.6
@export_range(0.1, 2.0, 0.05) var score_count_seconds := 0.7

var _is_rescue := false
var _celebration: Tween
## Score shown at the end of the count-up (the label reaches it when it ends).
var final_score := 0

@onready var title_label: Label = $PopupCenter/PopupPanel/Content/Title
@onready var subtitle_label: Label = $PopupCenter/PopupPanel/Content/Subtitle
@onready var artifact_name_label: Label = $PopupCenter/PopupPanel/Content/ArtifactName
@onready var artifact_preview: TextureRect = $PopupCenter/PopupPanel/Content/ArtifactPreview
@onready var progress_label: Label = $PopupCenter/PopupPanel/Content/Progress
@onready var score_label: Label = $PopupCenter/PopupPanel/Content/Score
@onready var coins_label: Label = $PopupCenter/PopupPanel/Content/Coins
@onready var chapter_complete: PanelContainer = $PopupCenter/PopupPanel/Content/ChapterComplete
@onready var chapter_title: Label = $PopupCenter/PopupPanel/Content/ChapterComplete/Layout/ChapterTitle
@onready var chapter_progress: Label = $PopupCenter/PopupPanel/Content/ChapterComplete/Layout/ChapterProgress
@onready var chapter_reward: Label = $PopupCenter/PopupPanel/Content/ChapterComplete/Layout/ChapterReward
@onready var undo_button: Button = $PopupCenter/PopupPanel/Content/UndoButton
@onready var retry_button: Button = $PopupCenter/PopupPanel/Content/Buttons/RetryButton
@onready var next_button: Button = $PopupCenter/PopupPanel/Content/Buttons/NextButton
@onready var clean_button: Button = $PopupCenter/PopupPanel/Content/CleanButton
@onready var find_glow: FindGlow = $PopupCenter/PopupPanel/Content/ArtifactPreview/FindGlow
@onready var ribbon: NinePatchRect = %Ribbon
@onready var buttons: HBoxContainer = $PopupCenter/PopupPanel/Content/Buttons
@onready var confetti: CPUParticles2D = $Confetti


func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	# In the rescue state the right button reads "В меню" and must not open the next expedition.
	next_button.pressed.connect(_on_next_pressed)
	undo_button.pressed.connect(func() -> void: undo_requested.emit())
	clean_button.pressed.connect(func() -> void: clean_requested.emit())


func show_victory(
	artifact_name: String,
	score: int = 0,
	coins: int = 0,
	artifact_texture: Texture2D = null,
	chapter_info: Dictionary = {},
	can_clean := false
) -> void:
	_is_rescue = false
	title_label.text = tr("ЭКСПЕДИЦИЯ ЗАВЕРШЕНА!")
	subtitle_label.text = tr("Находка восстановлена")
	artifact_name_label.text = artifact_name
	artifact_name_label.show()
	artifact_preview.modulate = Color.WHITE
	clean_button.visible = can_clean
	artifact_preview.texture = ArtifactTextureUtil.fit_visible_alpha(artifact_texture)
	artifact_preview.visible = artifact_texture != null
	progress_label.hide()
	score_label.text = tr("Счёт: %d") % score
	coins_label.text = tr("Монеты: +%d") % coins
	score_label.show()
	coins_label.visible = FeatureFlags.SHOW_COINS
	_show_chapter_complete(chapter_info)
	undo_button.hide()
	retry_button.text = tr("Повторить")
	next_button.text = tr("Дальше")
	next_button.icon = next_icon
	show()
	move_to_front()
	if artifact_texture != null:
		find_glow.play()
	_celebrate(score)


## Site preparation won: the find of the next level is shown as a dark
## silhouette ("it is down there").
func show_site_ready(artifact_name: String, score: int = 0, coins: int = 0, artifact_texture: Texture2D = null) -> void:
	_is_rescue = false
	title_label.text = tr("УЧАСТОК ГОТОВ!")
	subtitle_label.text = tr("Дальше — раскопки этой находки:")
	artifact_name_label.text = artifact_name
	artifact_name_label.show()
	artifact_preview.texture = ArtifactTextureUtil.fit_visible_alpha(artifact_texture)
	artifact_preview.visible = artifact_texture != null
	artifact_preview.modulate = Color(0.25, 0.17, 0.1, 0.9)
	progress_label.hide()
	score_label.text = tr("Счёт: %d") % score
	coins_label.text = tr("Монеты: +%d") % coins
	score_label.show()
	coins_label.visible = FeatureFlags.SHOW_COINS
	chapter_complete.hide()
	clean_button.hide()
	undo_button.hide()
	retry_button.text = tr("Повторить")
	next_button.text = tr("К раскопкам")
	next_button.icon = next_icon
	show()
	move_to_front()
	find_glow.stop()
	_celebrate(score)


func show_rescue(
	progress_text: String,
	can_free_undo: bool,
	can_rewarded_undo: bool,
	provider_available: bool,
	out_of_moves := false
) -> void:
	_is_rescue = true
	find_glow.stop()
	_stop_celebration()
	clean_button.hide()
	artifact_preview.modulate = Color.WHITE
	if out_of_moves:
		title_label.text = tr("ХОДЫ ЗАКОНЧИЛИСЬ")
		subtitle_label.text = tr("На сложной экспедиции ходы ограничены.")
	else:
		title_label.text = tr("РАСКОПКИ ЗАШЛИ В ТУПИК")
		subtitle_label.text = tr("Оставшиеся фигуры больше не помещаются.")
	artifact_name_label.hide()
	artifact_preview.hide()
	progress_label.text = progress_text
	progress_label.show()
	score_label.hide()
	coins_label.hide()
	chapter_complete.hide()
	update_rescue_undo(can_free_undo, can_rewarded_undo, provider_available)
	retry_button.text = tr("Повторить")
	next_button.text = tr("В меню")
	next_button.icon = menu_icon
	show()
	move_to_front()


## Endless Excavation run is over. `result` comes from GameSession
## (score, depth, lines, best_streak, best_score, best_depth, new_score_record).
func show_endless_result(result: Dictionary) -> void:
	# The right button reads "В меню" here, as in the rescue state.
	_is_rescue = true
	find_glow.stop()
	_stop_celebration()
	clean_button.hide()
	artifact_preview.modulate = Color.WHITE
	var new_record := bool(result.get("new_score_record", false))
	var daily := bool(result.get("daily", false))
	title_label.text = tr("РАСКОП ДНЯ ЗАВЕРШЁН") if daily else tr("РАСКОПКИ ЗАВЕРШЕНЫ")
	if daily:
		subtitle_label.text = (
			tr("Раскоп дня пройден! Возвращайтесь завтра")
			if bool(result.get("daily_done", false))
			else tr("Находки: %d / %d — попробуйте ещё раз") % [int(result.get("finds", 0)), int(result.get("daily_goal", 3))]
		)
	else:
		subtitle_label.text = tr("НОВЫЙ РЕКОРД!") if new_record else tr("Фигурам больше нет места")
	artifact_name_label.text = tr("Очки: %s") % GameSession.format_number(int(result.get("score", 0)))
	artifact_name_label.show()
	artifact_preview.hide()
	progress_label.text = tr("Глубина: %d м · Находки: %d · Лучшая серия: %d") % [
		int(result.get("depth", 0)),
		int(result.get("finds", 0)),
		int(result.get("best_streak", 0)),
	]
	progress_label.show()
	score_label.text = (
		tr("Лучший счёт дня: %s") % GameSession.format_number(int(result.get("daily_best", 0)))
		if daily
		else tr("Рекорд: %s · Лучшая глубина: %d м") % [
			GameSession.format_number(int(result.get("best_score", 0))),
			int(result.get("best_depth", 0)),
		]
	)
	score_label.show()
	coins_label.hide()
	chapter_complete.hide()
	undo_button.hide()
	retry_button.text = tr("Ещё раз")
	next_button.text = tr("В меню")
	next_button.icon = menu_icon
	show()
	move_to_front()


func show_loss() -> void:
	show_rescue(tr("Фрагменты: %d / %d") % [0, 0], false, false, false)


func update_rescue_undo(can_free_undo: bool, can_rewarded_undo: bool, provider_available: bool) -> void:
	undo_button.show()
	if can_free_undo:
		undo_button.text = tr("Отменить ход · бесплатно")
		undo_button.disabled = false
	elif can_rewarded_undo and provider_available:
		undo_button.text = tr("Отменить ход за рекламу")
		undo_button.disabled = false
	else:
		undo_button.text = tr("Отмена недоступна")
		undo_button.disabled = true


func _on_next_pressed() -> void:
	if _is_rescue:
		menu_requested.emit()
	else:
		next_requested.emit()


func close_popup() -> void:
	find_glow.stop()
	_stop_celebration()
	hide()


func _celebrate(score: int) -> void:
	_stop_celebration()
	final_score = score
	ribbon.show()
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	title_label.add_theme_color_override("font_outline_color", Color(0.35, 0.06, 0.04, 0.9))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	confetti.position = Vector2(size.x * 0.5, -30.0)
	confetti.emission_rect_extents = Vector2(size.x * 0.5, 10.0)
	confetti.restart()
	_set_score_text(0)
	buttons.modulate.a = 0.0
	buttons.pivot_offset = buttons.size * 0.5
	buttons.scale = Vector2.ONE * 0.9
	score_label.pivot_offset = score_label.size * 0.5
	_celebration = create_tween()
	_celebration.tween_callback(_play_count_sound).set_delay(0.25)
	_celebration.tween_method(_set_score_text, 0, score, score_count_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_celebration.tween_property(score_label, "scale", Vector2.ONE * 1.15, 0.08)
	_celebration.tween_property(score_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var buttons_in := create_tween().set_parallel(true)
	buttons_in.tween_property(buttons, "modulate:a", 1.0, 0.2).set_delay(buttons_delay)
	buttons_in.tween_property(buttons, "scale", Vector2.ONE, 0.25).set_delay(buttons_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_count_sound() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and final_score > 0:
		audio.call("play_sfx", &"score_count")


func _set_score_text(value: int) -> void:
	score_label.text = tr("Счёт: %d") % value


func _stop_celebration() -> void:
	if _celebration != null:
		_celebration.kill()
		_celebration = null
		_set_score_text(final_score)
	ribbon.hide()
	for name in ["font_color", "font_outline_color", "font_shadow_color"]:
		title_label.remove_theme_color_override(name)
	title_label.remove_theme_constant_override("outline_size")
	confetti.emitting = false
	score_label.scale = Vector2.ONE
	buttons.modulate.a = 1.0
	buttons.scale = Vector2.ONE


func _show_chapter_complete(info: Dictionary) -> void:
	if not bool(info.get("complete", false)):
		chapter_complete.hide()
		return
	var completion_title := String(info.get("completion_title", ""))
	chapter_title.text = (
		completion_title
		if not completion_title.is_empty()
		else tr("%s исследован") % String(info.get("title", ""))
	)
	chapter_progress.text = tr("Коллекция %d/%d") % [
		int(info.get("collected", 0)),
		int(info.get("total", 0)),
	]
	if int(info.get("reward_error", OK)) != OK:
		chapter_reward.text = tr("Награду главы не удалось сохранить")
	elif bool(info.get("reward_granted", false)):
		chapter_reward.text = tr("Награда главы: +%d монет") % int(info.get("reward_coins", 0))
	else:
		chapter_reward.text = tr("Награда главы уже получена")
	chapter_reward.visible = FeatureFlags.SHOW_COINS
	var unlocked := String(info.get("unlocked_difficulty", ""))
	if not unlocked.is_empty():
		chapter_reward.text = tr("Открыта сложность: %s!") % tr(unlocked)
		chapter_reward.visible = true
	chapter_complete.show()
