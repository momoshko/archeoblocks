class_name PieceDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var cells: Array[Vector2i] = []
@export var cosmetic_color := Color(0.2, 0.55, 0.32, 1.0)


func get_anchor_cell() -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var minimum := cells[0]
	var maximum := cells[0]
	for cell in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var center := (Vector2(minimum) + Vector2(maximum)) * 0.5
	var best_cell := cells[0]
	var best_distance := Vector2(best_cell).distance_squared_to(center)
	for cell in cells:
		var distance := Vector2(cell).distance_squared_to(center)
		if distance < best_distance:
			best_cell = cell
			best_distance = distance
	return best_cell


func translated_cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(origin + cell)
	return result

