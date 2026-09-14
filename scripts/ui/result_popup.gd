class_name ResultPopup
extends Control

signal retry_requested
signal next_requested
signal undo_requested

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


func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	next_button.pressed.connect(func() -> void: next_requested.emit())
	undo_button.pressed.connect(func() -> void: undo_requested.emit())


func show_victory(
	artifact_name: String,
	score: int = 0,
	coins: int = 0,
	artifact_texture: Texture2D = null,
	chapter_info: Dictionary = {}
) -> void:
	title_label.text = "ЭКСПЕДИЦИЯ ЗАВЕРШЕНА!"
	subtitle_label.text = "Находка восстановлена"
	artifact_name_label.text = artifact_name
	artifact_name_label.show()
	artifact_preview.texture = ArtifactTextureUtil.fit_visible_alpha(artifact_texture)
	artifact_preview.visible = artifact_texture != null
	progress_label.hide()
	score_label.text = "Счёт: %d" % score
	coins_label.text = "Монеты: +%d" % coins
	score_label.show()
	coins_label.show()
	_show_chapter_complete(chapter_info)
	undo_button.hide()
	retry_button.text = "Повторить"
	next_button.text = "Дальше"
	show()
	move_to_front()


func show_rescue(progress_text: String, can_free_undo: bool, can_rewarded_undo: bool, provider_available: bool) -> void:
	title_label.text = "РАСКОПКИ ЗАШЛИ В ТУПИК"
	subtitle_label.text = "Оставшиеся фигуры больше не помещаются."
	artifact_name_label.hide()
	artifact_preview.hide()
	progress_label.text = progress_text
	progress_label.show()
	score_label.hide()
	coins_label.hide()
	chapter_complete.hide()
	update_rescue_undo(can_free_undo, can_rewarded_undo, provider_available)
	retry_button.text = "Повторить"
	next_button.text = "В меню"
	show()
	move_to_front()


func show_loss() -> void:
	show_rescue("Фрагменты: 0 / 0", false, false, false)


func update_rescue_undo(can_free_undo: bool, can_rewarded_undo: bool, provider_available: bool) -> void:
	undo_button.show()
	if can_free_undo:
		undo_button.text = "Отменить ход · бесплатно"
		undo_button.disabled = false
	elif can_rewarded_undo and provider_available:
		undo_button.text = "🎬 Смотреть рекламу → отменить ход"
		undo_button.disabled = false
	else:
		undo_button.text = "Отмена недоступна"
		undo_button.disabled = true


func close_popup() -> void:
	hide()


func _show_chapter_complete(info: Dictionary) -> void:
	if not bool(info.get("complete", false)):
		chapter_complete.hide()
		return
	var completion_title := String(info.get("completion_title", ""))
	chapter_title.text = (
		completion_title
		if not completion_title.is_empty()
		else "%s исследован" % String(info.get("title", ""))
	)
	chapter_progress.text = "Коллекция %d/%d" % [
		int(info.get("collected", 0)),
		int(info.get("total", 0)),
	]
	if int(info.get("reward_error", OK)) != OK:
		chapter_reward.text = "Награду главы не удалось сохранить"
	elif bool(info.get("reward_granted", false)):
		chapter_reward.text = "Награда главы: +%d монет" % int(info.get("reward_coins", 0))
	else:
		chapter_reward.text = "Награда главы уже получена"
	chapter_complete.show()
