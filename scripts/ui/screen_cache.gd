class_name ScreenCache
extends RefCounted

## Screens stay loaded after their first use, so opening them again is instant.
## Godot frees a scene (and its textures, fonts, shaders) as soon as nothing
## holds it; without this every return to a menu loaded everything again.
## warm_up() loads the menus and the game screen once at startup, while the
## loading screen is still shown. Check: tools/perf_navigation.gd.

const MAIN_SCENE := "res://scenes/app/main.tscn"
const WARM_UP: Array[String] = [
	MAIN_SCENE,
	"res://scenes/screens/settings.tscn",
	"res://scenes/screens/expedition_select.tscn",
	"res://scenes/screens/collection.tscn",
	"res://scenes/screens/chapter_detail_01.tscn",
	"res://scenes/screens/chapter_detail_02.tscn",
	"res://scenes/screens/chapter_detail_03.tscn",
	"res://scenes/screens/endless_screen.tscn",
]

static var _scenes: Dictionary = {}
static var _warmed_up := false


static func get_scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		var scene := load(path) as PackedScene
		if scene == null:
			return null
		_scenes[path] = scene
	return _scenes[path]


## Use instead of SceneTree.change_scene_to_file().
static func change_to(tree: SceneTree, path: String) -> Error:
	var scene := get_scene(path)
	if scene == null:
		push_error("ScreenCache: cannot load %s" % path)
		return ERR_CANT_OPEN
	return tree.change_scene_to_packed(scene)


## Loads the common screens once (first main menu, before its first frame).
static func warm_up() -> void:
	if _warmed_up:
		return
	_warmed_up = true
	CampaignRoute.chapters()
	for path in WARM_UP:
		get_scene(path)
