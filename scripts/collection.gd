extends Control

@export var chapter_definition: ChapterDefinition
@export var chapter_two_definition: ChapterDefinition
@export var chapter_three_definition: ChapterDefinition

@onready var artifact_grid: GridContainer = $ContentCenter/PortraitContent/Layout/ArtifactGrid
@onready var chapter_title: Label = $ContentCenter/PortraitContent/Layout/ChapterTitle
@onready var collection_progress: Label = $ContentCenter/PortraitContent/Layout/CollectionProgress
@onready var chapter_two_title: Label = $ContentCenter/PortraitContent/Layout/ChapterTwoSection/ChapterTitle
@onready var chapter_two_progress: Label = $ContentCenter/PortraitContent/Layout/ChapterTwoSection/CollectionProgress
@onready var chapter_two_grid: GridContainer = $ContentCenter/PortraitContent/Layout/ChapterTwoSection/ArtifactGrid
@onready var chapter_three_title: Label = $ContentCenter/PortraitContent/Layout/ChapterThreeSection/ChapterTitle
@onready var chapter_three_progress: Label = $ContentCenter/PortraitContent/Layout/ChapterThreeSection/CollectionProgress
@onready var chapter_three_grid: GridContainer = $ContentCenter/PortraitContent/Layout/ChapterThreeSection/ArtifactGrid


func _ready() -> void:
	AudioManager.play_music_track(&"menu")
	%BackButton.pressed.connect(_back_to_menu)
	refresh_collection()


func refresh_collection() -> void:
	if chapter_definition == null:
		push_error("Collection requires a ChapterDefinition")
		return
	chapter_title.text = tr(chapter_definition.title_ru)
	_refresh_chapter(chapter_definition, artifact_grid, collection_progress)
	if chapter_two_definition != null:
		chapter_two_title.text = tr(chapter_two_definition.title_ru)
		_refresh_chapter(chapter_two_definition, chapter_two_grid, chapter_two_progress)
	if chapter_three_definition != null:
		chapter_three_title.text = tr(chapter_three_definition.title_ru)
		_refresh_chapter(chapter_three_definition, chapter_three_grid, chapter_three_progress)


## Dug-up finds that still need cleaning look dusty and show a brush badge;
## tapping one opens the restoration.
const DUSTY_TINT := Color(0.78, 0.66, 0.5)
const RESTORATION_SCENE := "res://scenes/screens/restoration_screen.tscn"
## Medal for the highest difficulty a find was dug up on (Difficulty.Level).
const MEDALS: Array[Texture2D] = [
	preload("res://assets/ui_art/medals/medal_bronze.png"),
	preload("res://assets/ui_art/medals/medal_silver.png"),
	preload("res://assets/ui_art/medals/medal_gold.png"),
]


func _refresh_chapter(
	definition: ChapterDefinition,
	grid: GridContainer,
	progress: Label
) -> void:
	var finds := definition.dig_expeditions()
	var completed_count := 0
	var cleaned_count := 0
	for expedition in finds:
		if ProgressStore.is_expedition_completed_any(expedition.id):
			completed_count += 1
			if ProgressStore.is_artifact_restored(expedition.artifact_id):
				cleaned_count += 1
	progress.text = tr("Коллекция: %d / %d · очищено: %d") % [completed_count, finds.size(), cleaned_count]
	var cards := grid.get_children()
	for index in cards.size():
		var card := cards[index] as Control
		card.visible = index < finds.size()
		if not card.visible:
			continue
		var preview := card.get_node("Layout/ArtifactVisual/ArtifactPreview") as TextureRect
		var name_label := card.get_node("Layout/ArtifactName") as Label
		var badge := card.get_node("Layout/ArtifactVisual/CleanBadge") as TextureRect
		var medal := card.get_node("Layout/ArtifactVisual/MedalBadge") as TextureRect
		preview.texture = null
		preview.hide()
		badge.hide()
		medal.hide()
		name_label.text = tr("Неизвестная находка")
		card.theme_type_variation = &"CollectionUnknown"
		card.tooltip_text = ""
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var expedition := finds[index]
		var best_level := ProgressStore.highest_difficulty_completed(expedition.id)
		if best_level < 0:
			continue
		medal.texture = MEDALS[best_level]
		medal.tooltip_text = tr(Difficulty.MEDAL_NAMES_RU[best_level])
		medal.show()
		card.theme_type_variation = &"CollectionKnown"
		preview.texture = ArtifactTextureUtil.fit_visible_alpha(expedition.full_artifact_texture)
		preview.visible = preview.texture != null
		name_label.text = tr(expedition.artifact_name_ru)
		var cleaned := ProgressStore.is_artifact_restored(expedition.artifact_id)
		preview.modulate = Color.WHITE if cleaned else DUSTY_TINT
		badge.visible = not cleaned
		if not cleaned:
			card.tooltip_text = tr("Нажмите, чтобы очистить находку")
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not card.gui_input.is_connected(_on_card_input):
			card.gui_input.connect(_on_card_input.bind(card))
		card.set_meta(&"expedition", expedition)


func _on_card_input(event: InputEvent, card: Control) -> void:
	var tapped: bool = (
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if not tapped or not card.has_meta(&"expedition"):
		return
	var expedition := card.get_meta(&"expedition") as ExpeditionDefinition
	if expedition == null or ProgressStore.is_artifact_restored(expedition.artifact_id):
		return
	RestorationScreen.pending_expedition = expedition
	RestorationScreen.pending_return_scene = scene_file_path
	ScreenCache.change_to(get_tree(), RESTORATION_SCENE)


func _back_to_menu() -> void:
	ScreenCache.change_to(get_tree(), "res://scenes/app/main.tscn")
