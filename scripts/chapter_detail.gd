extends Control

## Chapter page: one card per find with its steps
## Site clearing (if the find has one) -> Excavation -> Cleaning (restoration).
## A card opens its next step; a finished card replays the excavation.
## The next find opens when the previous one is dug up.

const RESTORATION_SCENE := "res://scenes/screens/restoration_screen.tscn"

@export var chapter_definition: ChapterDefinition
@export var prerequisite_chapter: ChapterDefinition
## Every game scene of the chapter (site levels and excavations), export-safe.
@export var expedition_scenes: Array[PackedScene] = []

@onready var chapter_number: Label = %ChapterNumber
@onready var chapter_title: Label = %ChapterTitle
@onready var chapter_subtitle: Label = %ChapterSubtitle
@onready var progress_label: Label = %ProgressLabel
@onready var reward_label: Label = %RewardLabel
@onready var find_cards: Array[FindCard] = [
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

## [{site: ExpeditionDefinition or null, dig: ExpeditionDefinition}] in chapter order.
var _finds: Array[Dictionary] = []


const COLUMN_WIDTH := 664.0


func _ready() -> void:
	AudioManager.play_music_track(&"menu")
	resized.connect(_fit_column)
	_fit_column()
	%BackButton.pressed.connect(_back_to_chapters)
	if chapter_definition != null and chapter_definition.background_texture != null:
		$Background.texture = chapter_definition.background_texture
	if chapter_definition == null:
		push_error("ChapterDetail requires a ChapterDefinition")
		return
	chapter_number.text = tr(chapter_definition.number_ru)
	chapter_title.text = tr(chapter_definition.title_ru)
	chapter_subtitle.text = tr(chapter_definition.subtitle_ru)
	_finds = finds_of(chapter_definition)
	for index in find_cards.size():
		find_cards[index].visible = index < _finds.size()
		if index < _finds.size():
			find_cards[index].pressed.connect(_open_find.bind(index))
	refresh_progress()


## Pairs every excavation with the site level right before it.
static func finds_of(chapter: ChapterDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending_site: ExpeditionDefinition = null
	for expedition in chapter.expeditions:
		if expedition == null:
			continue
		if expedition.is_site_preparation():
			pending_site = expedition
			continue
		result.append({"site": pending_site, "dig": expedition})
		pending_site = null
	return result


func refresh_progress() -> void:
	if chapter_definition == null:
		return
	var completed := ProgressStore.completed_expeditions()
	var dug := 0
	for find in _finds:
		if completed.has((find.dig as ExpeditionDefinition).id):
			dug += 1
	progress_label.text = tr("Находки: %d / %d") % [dug, _finds.size()]
	# Once a second difficulty exists, say which playthrough this is.
	if Difficulty.is_unlocked(Difficulty.Level.MEDIUM):
		progress_label.text += " · " + tr(Difficulty.name_ru(Difficulty.current()))
	var reward_claimed := ProgressStore.is_chapter_reward_claimed(chapter_definition.id)
	reward_label.visible = FeatureFlags.SHOW_COINS and chapter_definition.completion_reward_coins > 0
	reward_label.text = (
		tr("Награда главы получена: +%d монет") % chapter_definition.completion_reward_coins
		if reward_claimed
		else tr("Награда главы: +%d монет") % chapter_definition.completion_reward_coins
	)
	var chapter_unlocked := prerequisite_chapter == null or _is_chapter_complete(prerequisite_chapter, completed)
	for index in mini(find_cards.size(), _finds.size()):
		var find := _finds[index]
		var dig: ExpeditionDefinition = find.dig
		var site: ExpeditionDefinition = find.site
		var unlocked := chapter_unlocked and (
			index == 0 or completed.has((_finds[index - 1].dig as ExpeditionDefinition).id)
		)
		var dig_done := completed.has(dig.id)
		# Saves from before site levels existed: a dug find counts its site as done.
		var site_done := site == null or completed.has(site.id) or dig_done
		var cleaned := dig_done and ProgressStore.is_artifact_restored(dig.artifact_id)
		var states := [
			FindCard.Step.HIDDEN if site == null else (FindCard.Step.DONE if site_done else FindCard.Step.NEXT),
			FindCard.Step.DONE if dig_done else (FindCard.Step.NEXT if site_done else FindCard.Step.LOCKED),
			FindCard.Step.DONE if cleaned else (FindCard.Step.NEXT if dig_done else FindCard.Step.LOCKED),
		]
		var next_text := tr("Закрыто")
		if unlocked:
			if not site_done:
				next_text = tr("Дальше: расчистка")
			elif not dig_done:
				next_text = tr("Дальше: раскопка")
			elif not cleaned:
				next_text = tr("Дальше: очистка")
			else:
				next_text = tr("Готово")
		var card := find_cards[index]
		card.show_find(
			tr(dig.card_title_ru),
			dig.full_artifact_texture,
			dig_done,
			states,
			next_text,
			not unlocked
		)
		card.theme_type_variation = &"ChapterCardDone" if cleaned else &"ChapterCard"


## The next step of a find: site level, excavation, cleaning; then a replay.
func _open_find(index: int) -> void:
	if index < 0 or index >= _finds.size():
		return
	var completed := ProgressStore.completed_expeditions()
	var find := _finds[index]
	var dig: ExpeditionDefinition = find.dig
	var site: ExpeditionDefinition = find.site
	if site != null and not completed.has(site.id) and not completed.has(dig.id):
		_open_expedition(site)
	elif not completed.has(dig.id):
		_open_expedition(dig)
	elif not ProgressStore.is_artifact_restored(dig.artifact_id):
		RestorationScreen.pending_expedition = dig
		RestorationScreen.pending_return_scene = scene_file_path
		ScreenCache.change_to(get_tree(), RESTORATION_SCENE)
	else:
		_open_expedition(dig)


func _scene_for(expedition: ExpeditionDefinition) -> PackedScene:
	for scene in expedition_scenes:
		if scene != null and scene.resource_path == expedition.game_scene_path:
			return scene
	return null


## A chapter is done when every find is dug up (site levels are steps on the way).
func _is_chapter_complete(chapter: ChapterDefinition, completed: Dictionary) -> bool:
	var finds := chapter.dig_expeditions()
	if finds.is_empty():
		return false
	for expedition in finds:
		if not completed.has(expedition.id):
			return false
	return true


func _back_to_chapters() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/screens/expedition_select.tscn")


func _open_expedition(expedition: ExpeditionDefinition) -> void:
	var expedition_scene := _scene_for(expedition)
	if expedition_scene == null:
		push_error("No game scene for %s" % expedition.id)
		return
	get_tree().change_scene_to_packed(expedition_scene)


## On a wide (landscape) screen the cards stay a phone-width column in the
## middle instead of spreading into a long row.
func _fit_column() -> void:
	var column := %PortraitContent as Control
	var available := size.x - 56.0
	if available > COLUMN_WIDTH + 1.0:
		column.custom_minimum_size.x = COLUMN_WIDTH
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		column.custom_minimum_size.x = 0.0
		column.size_flags_horizontal = Control.SIZE_FILL
