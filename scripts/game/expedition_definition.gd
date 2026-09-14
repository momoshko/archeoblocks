class_name ExpeditionDefinition
extends Resource

const BOARD_WIDTH := 8
const BOARD_HEIGHT := 8

@export var id: StringName
@export var title_ru: String
@export var card_title_ru: String
@export var debug_name: String
@export var artifact_id: StringName
@export var artifact_name_ru: String
@export var full_artifact_texture: Texture2D
@export var fragment_textures: Array[Texture2D] = []
@export var objective_ru := "Раскопайте все фрагменты артефакта"
@export var instruction_ru := "Собирайте строки и столбцы, чтобы снимать грунт"
@export var normal_soil_cells: Array[Vector2i] = []
@export var strong_soil_cells: Array[Vector2i] = []
@export var artifact_fragments: Array[ArtifactFragmentDefinition] = []
@export var stone_obstacles: Array[StoneObstacleDefinition] = []
@export var root_obstacles: Array[RootObstacleDefinition] = []
@export var opening_piece_set: Array[PieceDefinition] = []
@export var curated_piece_sequence: Array[PieceDefinition] = []
@export_range(0, 100, 1) var expected_moves_min := 0
@export_range(0, 100, 1) var expected_moves_max := 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_cells(normal_soil_cells, "normal_soil_cells", errors)
	_validate_cells(strong_soil_cells, "strong_soil_cells", errors)
	if not opening_piece_set.is_empty() and opening_piece_set.size() != 3:
		errors.append("opening_piece_set must be empty or contain exactly three pieces")
	if not curated_piece_sequence.is_empty() and curated_piece_sequence.size() % 3 != 0:
		errors.append("curated_piece_sequence must contain complete sets of three pieces")
	if expected_moves_max > 0 and expected_moves_min > expected_moves_max:
		errors.append("expected_moves_min must not exceed expected_moves_max")
	for piece in opening_piece_set:
		if piece == null:
			errors.append("opening_piece_set contains a null entry")
	for piece in curated_piece_sequence:
		if piece == null:
			errors.append("curated_piece_sequence contains a null entry")
	var obstacle_cells: Dictionary = {}
	for obstacle in stone_obstacles:
		if obstacle == null:
			errors.append("stone_obstacles contains a null entry")
			continue
		if not _is_inside(obstacle.cell):
			errors.append("stone obstacle has out-of-bounds cell %s" % obstacle.cell)
		elif obstacle_cells.has(obstacle.cell):
			errors.append("stone_obstacles repeats cell %s" % obstacle.cell)
		else:
			obstacle_cells[obstacle.cell] = true
		if obstacle.durability <= 0:
			errors.append("stone obstacle durability must be positive at %s" % obstacle.cell)
	for root in root_obstacles:
		if root == null:
			errors.append("root_obstacles contains a null entry")
			continue
		if not _is_inside(root.cell):
			errors.append("root obstacle has out-of-bounds cell %s" % root.cell)
		elif obstacle_cells.has(root.cell):
			errors.append("obstacles overlap at cell %s" % root.cell)
		else:
			obstacle_cells[root.cell] = true

	var fragment_ids: Dictionary = {}
	var cell_owners: Dictionary = {}
	if artifact_fragments.is_empty():
		errors.append("artifact_fragments must contain at least one fragment")
	for fragment in artifact_fragments:
		if fragment == null:
			errors.append("artifact_fragments contains a null entry")
			continue
		if fragment.id == &"":
			errors.append("artifact fragment id must not be empty")
		elif fragment_ids.has(fragment.id):
			errors.append("duplicate artifact fragment id: %s" % fragment.id)
		else:
			fragment_ids[fragment.id] = true
		if fragment.cells.is_empty():
			errors.append("artifact fragment %s must contain at least one cell" % fragment.id)
		var fragment_cells: Dictionary = {}
		for cell in fragment.cells:
			if not _is_inside(cell):
				errors.append("artifact fragment %s has out-of-bounds cell %s" % [fragment.id, cell])
				continue
			if fragment_cells.has(cell):
				errors.append("artifact fragment %s repeats cell %s" % [fragment.id, cell])
			fragment_cells[cell] = true
			if cell_owners.has(cell):
				errors.append(
					"artifact cell %s belongs to both %s and %s"
					% [cell, cell_owners[cell], fragment.id]
				)
			else:
				cell_owners[cell] = fragment.id
	if not fragment_textures.is_empty() and fragment_textures.size() != artifact_fragments.size():
		errors.append("fragment_textures must be empty or match artifact_fragments order and count")
	return errors


func get_fragment_texture(fragment_id: StringName) -> Texture2D:
	for index in artifact_fragments.size():
		var fragment := artifact_fragments[index]
		if fragment != null and fragment.id == fragment_id:
			if index < fragment_textures.size() and fragment_textures[index] != null:
				return fragment_textures[index]
			if artifact_fragments.size() == 1:
				return full_artifact_texture
			return null
	return null


func _validate_cells(cells: Array[Vector2i], field_name: String, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}
	for cell in cells:
		if not _is_inside(cell):
			errors.append("%s has out-of-bounds cell %s" % [field_name, cell])
		elif seen.has(cell):
			errors.append("%s repeats cell %s" % [field_name, cell])
		seen[cell] = true


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT
