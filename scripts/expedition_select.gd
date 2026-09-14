extends Control

const CHAPTER_ONE_DETAIL := "res://scenes/screens/chapter_detail_01.tscn"
const CHAPTER_TWO_DETAIL := "res://scenes/screens/chapter_detail_02.tscn"
const CHAPTER_THREE_DETAIL := "res://scenes/screens/chapter_detail_03.tscn"

@export var chapter_one_definition: ChapterDefinition
@export var chapter_two_definition: ChapterDefinition
@export var chapter_three_definition: ChapterDefinition

@onready var chapter_one_button: Button = %ChapterOneButton
@onready var chapter_two_button: Button = %ChapterTwoButton
@onready var chapter_three_button: Button = %ChapterThreeButton


func _ready() -> void:
	%BackButton.pressed.connect(_back_to_menu)
	chapter_one_button.pressed.connect(_open_chapter.bind(CHAPTER_ONE_DETAIL))
	chapter_two_button.pressed.connect(_open_chapter.bind(CHAPTER_TWO_DETAIL))
	chapter_three_button.pressed.connect(_open_chapter.bind(CHAPTER_THREE_DETAIL))
	refresh_progress()


func refresh_progress() -> void:
	if chapter_one_definition == null or chapter_two_definition == null or chapter_three_definition == null:
		push_error("ExpeditionSelect requires all available chapter definitions")
		return
	var chapter_one_complete := _is_chapter_complete(chapter_one_definition)
	var chapter_two_complete := _is_chapter_complete(chapter_two_definition)
	_configure_chapter_button(chapter_one_button, chapter_one_definition, true)
	_configure_chapter_button(chapter_two_button, chapter_two_definition, chapter_one_complete)
	chapter_three_button.visible = true
	_configure_chapter_button(chapter_three_button, chapter_three_definition, chapter_two_complete)


func _configure_chapter_button(
	button: Button,
	chapter: ChapterDefinition,
	is_available: bool
) -> void:
	var completed := _completed_count(chapter)
	var total := chapter.expeditions.size()
	var state := "Закрыто"
	if completed == total and total > 0:
		state = "✓ Пройдено"
	elif is_available:
		state = "Открыто"
	var reward_line := "\nНаграда: +%d монет" % chapter.completion_reward_coins if chapter.completion_reward_coins > 0 else ""
	button.text = "%s\n%s\nПрогресс: %d / %d%s\n%s" % [
		chapter.number_ru,
		chapter.title_ru,
		completed,
		total,
		reward_line,
		state,
	]
	button.disabled = not is_available


func _completed_count(chapter: ChapterDefinition) -> int:
	var count := 0
	for expedition in chapter.expeditions:
		if expedition != null and ProgressStore.is_expedition_completed(expedition.id):
			count += 1
	return count


func _is_chapter_complete(chapter: ChapterDefinition) -> bool:
	return not chapter.expeditions.is_empty() and _completed_count(chapter) == chapter.expeditions.size()


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")


func _open_chapter(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
