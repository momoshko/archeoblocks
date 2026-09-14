extends Control

@export var chapter_definition: ChapterDefinition
@export var prerequisite_chapter: ChapterDefinition
@export_file("*.tscn") var expedition_scene_paths: PackedStringArray = []

@onready var chapter_number: Label = %ChapterNumber
@onready var chapter_title: Label = %ChapterTitle
@onready var chapter_subtitle: Label = %ChapterSubtitle
@onready var progress_label: Label = %ProgressLabel
@onready var reward_label: Label = %RewardLabel
@onready var expedition_buttons: Array[Button] = [
	%Expedition01,
	%Expedition02,
	%Expedition03,
	%Expedition04,
	%Expedition05,
	%Expedition06,
	%Expedition07,
	%Expedition08,
	%Expedition09,
	%Expedition10,
]


func _ready() -> void:
	%BackButton.pressed.connect(_back_to_chapters)
	if chapter_definition == null:
		push_error("ChapterDetail requires a ChapterDefinition")
		return
	chapter_number.text = chapter_definition.number_ru
	chapter_title.text = chapter_definition.title_ru
	chapter_subtitle.text = chapter_definition.subtitle_ru
	for index in expedition_buttons.size():
		var has_expedition := index < chapter_definition.expeditions.size()
		expedition_buttons[index].visible = has_expedition
		if has_expedition and index < expedition_scene_paths.size():
			expedition_buttons[index].pressed.connect(_open_expedition.bind(expedition_scene_paths[index]))
	refresh_progress()


func refresh_progress() -> void:
	if chapter_definition == null:
		return
	var completed := ProgressStore.completed_expeditions()
	var completed_count := 0
	for expedition in chapter_definition.expeditions:
		if expedition != null and completed.has(expedition.id):
			completed_count += 1
	progress_label.text = "Пройдено: %d / %d" % [
		completed_count,
		chapter_definition.expeditions.size(),
	]
	var reward_claimed := ProgressStore.is_chapter_reward_claimed(chapter_definition.id)
	reward_label.visible = chapter_definition.completion_reward_coins > 0
	reward_label.text = (
		"Награда главы: ✓ +%d монет" % chapter_definition.completion_reward_coins
		if reward_claimed
		else "Награда главы: +%d монет" % chapter_definition.completion_reward_coins
	)
	var chapter_unlocked := prerequisite_chapter == null or _is_chapter_complete(prerequisite_chapter, completed)
	for index in expedition_buttons.size():
		var button := expedition_buttons[index]
		if index >= chapter_definition.expeditions.size():
			button.hide()
			continue
		var expedition := chapter_definition.expeditions[index]
		var is_completed := completed.has(expedition.id)
		var is_unlocked := chapter_unlocked and (is_completed or index == 0)
		if chapter_unlocked and index > 0:
			is_unlocked = is_unlocked or completed.has(chapter_definition.expeditions[index - 1].id)
		var state_text := "Закрыто"
		if is_completed:
			state_text = "✓ Пройдено"
		elif is_unlocked:
			state_text = "Открыто"
		button.text = "%s\n%s" % [expedition.card_title_ru, state_text]
		button.disabled = not is_unlocked or index >= expedition_scene_paths.size()


func _is_chapter_complete(chapter: ChapterDefinition, completed: Dictionary) -> bool:
	if chapter.expeditions.is_empty():
		return false
	for expedition in chapter.expeditions:
		if expedition == null or not completed.has(expedition.id):
			return false
	return true


func _back_to_chapters() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/expedition_select.tscn")


func _open_expedition(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
