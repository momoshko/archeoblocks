class_name CampaignRoute
extends RefCounted

## Ordered campaign chapters. "Play" continues from the first unfinished expedition.
const CHAPTER_PATHS: Array[String] = [
	"res://resources/chapters/ancient_courtyard.tres",
	"res://resources/chapters/ruined_shrine.tres",
	"res://resources/chapters/overgrown_catacombs.tres",
]
const EXPEDITION_SELECT_SCENE := "res://scenes/screens/expedition_select.tscn"

## Loaded once and kept: Godot frees a resource (and all its artifact pictures)
## as soon as nothing holds it, so without this every menu visit decoded ~80
## textures again (0.3-0.7 s per screen, see tools/perf_navigation.gd).
static var _chapters: Array[ChapterDefinition] = []


static func chapters() -> Array[ChapterDefinition]:
	if _chapters.is_empty():
		for path in CHAPTER_PATHS:
			var chapter := load(path) as ChapterDefinition
			if chapter != null:
				_chapters.append(chapter)
	return _chapters.duplicate()


## The first expedition the player has not completed yet, or null when the
## whole campaign is complete.
static func next_expedition() -> ExpeditionDefinition:
	var completed := ProgressStore.completed_expeditions()
	for chapter in chapters():
		for index in chapter.expeditions.size():
			var expedition := chapter.expeditions[index]
			if expedition == null or completed.has(expedition.id):
				continue
			# A site level whose excavation is already done (old saves) is skipped.
			if expedition.is_site_preparation() and index + 1 < chapter.expeditions.size():
				var dig := chapter.expeditions[index + 1]
				if dig != null and completed.has(dig.id):
					continue
			return expedition
	return null


## Scene of the first expedition the player has not completed yet,
## or an empty string when the whole campaign is complete.
static func next_expedition_scene_path() -> String:
	var expedition := next_expedition()
	return expedition.game_scene_path if expedition != null else ""


## Where the main "Play" button leads.
static func play_scene_path() -> String:
	var next_path := next_expedition_scene_path()
	return next_path if not next_path.is_empty() else EXPEDITION_SELECT_SCENE


static func has_progress() -> bool:
	return not ProgressStore.completed_expeditions().is_empty()
