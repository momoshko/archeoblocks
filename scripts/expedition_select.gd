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
	AudioManager.play_music_track(&"menu")
	%BackButton.pressed.connect(_back_to_menu)
	chapter_one_button.pressed.connect(_open_chapter.bind(CHAPTER_ONE_DETAIL))
	chapter_two_button.pressed.connect(_open_chapter.bind(CHAPTER_TWO_DETAIL))
	chapter_three_button.pressed.connect(_open_chapter.bind(CHAPTER_THREE_DETAIL))
	%DifficultyPicker.difficulty_changed.connect(func(_level: int) -> void: refresh_progress())
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
	var total := chapter.dig_expeditions().size()
	var state := tr("Закрыто")
	if completed == total and total > 0:
		state = tr("Пройдено")
	elif is_available:
		state = tr("Открыто")
	var reward_line := (
		"\n" + tr("Награда: +%d монет") % chapter.completion_reward_coins
		if FeatureFlags.SHOW_COINS and chapter.completion_reward_coins > 0
		else ""
	)
	button.text = "%s\n%s\n%s%s\n%s" % [
		tr(chapter.number_ru),
		tr(chapter.title_ru),
		tr("Находки: %d / %d") % [completed, total],
		reward_line,
		state,
	]
	button.disabled = not is_available
	# The padlock badge (LockIcon) lives in the scene, inside every card.
	var lock := button.get_node_or_null("LockIcon") as CanvasItem
	if lock != null:
		lock.visible = not is_available
	# Completed chapters use the olive-accent card (theme variation).
	button.theme_type_variation = &"ChapterCardDone" if completed == total and total > 0 else &"ChapterCard"


## Finds dug up (site levels are steps on the way, not counted).
func _completed_count(chapter: ChapterDefinition) -> int:
	var completed := ProgressStore.completed_expeditions()
	var count := 0
	for expedition in chapter.dig_expeditions():
		if completed.has(expedition.id):
			count += 1
	return count


func _is_chapter_complete(chapter: ChapterDefinition) -> bool:
	var finds := chapter.dig_expeditions()
	return not finds.is_empty() and _completed_count(chapter) == finds.size()


func _back_to_menu() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/app/main.tscn")


func _open_chapter(scene_path: String) -> void:
	ScreenCache.change_to(get_tree(), scene_path)
