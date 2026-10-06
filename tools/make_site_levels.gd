extends SceneTree

## Builds the site preparation levels (goal clear_site) from tools/site_levels.json:
## one before every excavation except the onboarding one (1-1).
##   godot --headless --path . -s res://tools/make_site_levels.gd
## Writes resources/expeditions/site_<dig id>.tres and
## scenes/screens/game_screen_site_<dig id>.tscn, then puts each site level in
## its chapter right before its excavation and re-links the "Next" chain of the
## game scenes (excavation -> next site -> next excavation ...).
## Run again after editing the JSON; files are overwritten.

const JSON_PATH := "res://tools/site_levels.json"


func _init() -> void:
	var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	var chapters: Array[ChapterDefinition] = []
	for path in CampaignRoute.CHAPTER_PATHS:
		chapters.append(load(path) as ChapterDefinition)
	var made := 0
	for chapter in chapters:
		var digs: Array[ExpeditionDefinition] = []
		for expedition in chapter.expeditions:
			if not expedition.is_site_preparation():
				digs.append(expedition)
		var ordered: Array[ExpeditionDefinition] = []
		for dig in digs:
			if specs.has(String(dig.id)):
				var site := _build_site(dig, specs[String(dig.id)])
				var error := ResourceSaver.save(site, _site_resource_path(dig))
				if error != OK:
					push_error("save failed: %s" % _site_resource_path(dig))
				_write_scene(dig, chapter)
				ordered.append(load(_site_resource_path(dig)) as ExpeditionDefinition)
				made += 1
			ordered.append(dig)
		chapter.expeditions = ordered
		ResourceSaver.save(chapter, chapter.resource_path)
	_relink_scenes(chapters)
	print("site levels: %d" % made)
	quit()


func _site_resource_path(dig: ExpeditionDefinition) -> String:
	return "res://resources/expeditions/site_%s.tres" % dig.id


func _site_scene_path(dig: ExpeditionDefinition) -> String:
	return "res://scenes/screens/game_screen_site_%s.tscn" % dig.id


func _build_site(dig: ExpeditionDefinition, spec: Dictionary) -> ExpeditionDefinition:
	var site := ExpeditionDefinition.new()
	site.id = StringName("%s_site" % dig.id)
	site.goal = ExpeditionDefinition.GOAL_CLEAR_SITE
	var prefix := dig.title_ru.get_slice(" — ", 0).strip_edges()
	site.title_ru = "%s — Расчистка участка" % prefix
	site.card_title_ru = "Расчистка"
	site.debug_name = "%s - site" % dig.debug_name
	site.artifact_id = dig.artifact_id
	site.artifact_name_ru = dig.artifact_name_ru
	site.full_artifact_texture = dig.full_artifact_texture
	site.piece_generation = dig.piece_generation
	site.game_scene_path = _site_scene_path(dig)
	var blocked := {}
	var stones: Array[StoneObstacleDefinition] = []
	for entry: Array in spec.get("stones", []):
		var stone := StoneObstacleDefinition.new()
		stone.cell = Vector2i(int(entry[0]), int(entry[1]))
		stone.durability = int(entry[2])
		stones.append(stone)
		blocked[stone.cell] = true
	var roots: Array[RootObstacleDefinition] = []
	for entry: Array in spec.get("roots", []):
		var root_definition := RootObstacleDefinition.new()
		root_definition.cell = Vector2i(int(entry[0]), int(entry[1]))
		roots.append(root_definition)
		blocked[root_definition.cell] = true
	site.stone_obstacles = stones
	site.root_obstacles = roots
	var strong := {}
	for entry: Array in spec.get("strong", []):
		strong[Vector2i(int(entry[0]), int(entry[1]))] = true
	var soil := {}
	for rect: Array in spec.get("soil", []):
		for y in range(int(rect[1]), int(rect[3]) + 1):
			for x in range(int(rect[0]), int(rect[2]) + 1):
				soil[Vector2i(x, y)] = true
	var normal_cells: Array[Vector2i] = []
	var strong_cells: Array[Vector2i] = []
	for cell: Vector2i in soil:
		if blocked.has(cell):
			continue
		if strong.has(cell):
			strong_cells.append(cell)
		else:
			normal_cells.append(cell)
	site.normal_soil_cells = normal_cells
	site.strong_soil_cells = strong_cells
	var parts: PackedStringArray = ["снимите весь грунт"]
	if not stones.is_empty():
		parts.append("разбейте завалы")
	if not roots.is_empty():
		parts.append("срежьте корни")
	site.objective_ru = "Расчистите участок: " + ", ".join(parts)
	site.instruction_ru = "Собирайте линии через грунт и завалы — потом здесь начнутся раскопки."
	if spec.has("expected_moves"):
		site.expected_moves_min = int(spec.expected_moves[0])
		site.expected_moves_max = int(spec.expected_moves[1])
	var errors := site.validate()
	if not errors.is_empty():
		push_error("%s: %s" % [site.id, ", ".join(errors)])
	return site


func _write_scene(dig: ExpeditionDefinition, chapter: ChapterDefinition) -> void:
	var node_name := "GameScreenSite" + String(dig.id).to_pascal_case()
	var text := "[gd_scene load_steps=4 format=3]\n\n"
	text += '[ext_resource type="PackedScene" path="res://scenes/screens/game_screen.tscn" id="1_game"]\n'
	text += '[ext_resource type="Resource" path="%s" id="2_expedition"]\n' % _site_resource_path(dig)
	text += '[ext_resource type="Resource" path="%s" id="3_chapter"]\n\n' % chapter.resource_path
	text += '[node name="%s" instance=ExtResource("1_game")]\n' % node_name
	text += 'next_expedition_scene_path = "%s"\n\n' % dig.game_scene_path
	text += '[node name="GameSession" parent="." index="8"]\n'
	text += 'expedition_definition = ExtResource("2_expedition")\n'
	text += 'chapter_definition = ExtResource("3_chapter")\n'
	var file := FileAccess.open(_site_scene_path(dig), FileAccess.WRITE)
	file.store_string(text)


## Every excavation's "Next" leads to the following level of its chapter; the
## last one keeps its link (back to the chapter page).
func _relink_scenes(chapters: Array[ChapterDefinition]) -> void:
	for chapter in chapters:
		_relink_chapter(chapter.expeditions)


func _relink_chapter(order: Array[ExpeditionDefinition]) -> void:
	for index in order.size() - 1:
		var expedition := order[index]
		if expedition.is_site_preparation():
			continue
		var next_path := order[index + 1].game_scene_path
		var path := expedition.game_scene_path
		var text := FileAccess.get_file_as_string(path)
		var regex := RegEx.create_from_string('next_expedition_scene_path = "[^"]*"\\n')
		if regex.search(text) == null:
			if next_path.is_empty():
				continue
			# The base scene (1-1) has no override line yet: add one after the root node.
			var root_line := RegEx.create_from_string("(\\[node name=\"[^\"]+\"[^\\]]*instance[^\\]]*\\]\\n)").search(text)
			if root_line == null:
				push_error("cannot relink %s" % path)
				continue
			text = text.insert(root_line.get_end(), 'next_expedition_scene_path = "%s"\n' % next_path)
		else:
			text = regex.sub(text, 'next_expedition_scene_path = "%s"\n' % next_path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
