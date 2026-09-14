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
	%BackButton.pressed.connect(_back_to_menu)
	refresh_collection()


func refresh_collection() -> void:
	if chapter_definition == null:
		push_error("Collection requires a ChapterDefinition")
		return
	chapter_title.text = chapter_definition.title_ru
	_refresh_chapter(chapter_definition, artifact_grid, collection_progress)
	if chapter_two_definition != null:
		chapter_two_title.text = chapter_two_definition.title_ru
		_refresh_chapter(chapter_two_definition, chapter_two_grid, chapter_two_progress)
	if chapter_three_definition != null:
		chapter_three_title.text = chapter_three_definition.title_ru
		_refresh_chapter(chapter_three_definition, chapter_three_grid, chapter_three_progress)


func _refresh_chapter(
	definition: ChapterDefinition,
	grid: GridContainer,
	progress: Label
) -> void:
	var completed_count := 0
	for expedition in definition.expeditions:
		if expedition != null and ProgressStore.is_expedition_completed(expedition.id):
			completed_count += 1
	progress.text = "Коллекция: %d / %d" % [
		completed_count,
		definition.expeditions.size(),
	]
	var cards := grid.get_children()
	for index in cards.size():
		var card := cards[index] as Control
		card.visible = index < definition.expeditions.size()
		if not card.visible:
			continue
		var preview := card.get_node("Layout/ArtifactVisual/ArtifactPreview") as TextureRect
		var name_label := card.get_node("Layout/ArtifactName") as Label
		preview.texture = null
		preview.hide()
		name_label.text = "Неизвестная находка"
		var expedition := definition.expeditions[index]
		if expedition == null or not ProgressStore.is_expedition_completed(expedition.id):
			continue
		preview.texture = ArtifactTextureUtil.fit_visible_alpha(expedition.full_artifact_texture)
		preview.visible = preview.texture != null
		name_label.text = expedition.artifact_name_ru


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/app/main.tscn")
