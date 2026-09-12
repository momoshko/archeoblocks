class_name BoardModel
extends RefCounted

const WIDTH := 8
const HEIGHT := 8

var _cells: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	_cells.clear()
	for y in HEIGHT:
		var row: Array = []
		row.resize(WIDTH)
		row.fill(null)
		_cells.append(row)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func is_empty(cell: Vector2i) -> bool:
	return is_inside(cell) and _cells[cell.y][cell.x] == null


func can_place(shape: Array[Vector2i], origin: Vector2i) -> bool:
	for offset in shape:
		if not is_empty(origin + offset):
			return false
	return not shape.is_empty()


func place(shape: Array[Vector2i], origin: Vector2i, cosmetic_value: Variant = true) -> Array[Vector2i]:
	var placed_cells: Array[Vector2i] = []
	if not can_place(shape, origin):
		return placed_cells
	for offset in shape:
		var cell := origin + offset
		_cells[cell.y][cell.x] = cosmetic_value
		placed_cells.append(cell)
	return placed_cells


func get_full_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in HEIGHT:
		var is_full := true
		for x in WIDTH:
			if _cells[y][x] == null:
				is_full = false
				break
		if is_full:
			rows.append(y)
	return rows


func get_full_columns() -> Array[int]:
	var columns: Array[int] = []
	for x in WIDTH:
		var is_full := true
		for y in HEIGHT:
			if _cells[y][x] == null:
				is_full = false
				break
		if is_full:
			columns.append(x)
	return columns


func clear_lines(rows: Array[int], columns: Array[int]) -> Array[Vector2i]:
	var cleared_lookup: Dictionary = {}
	for y in rows:
		if y < 0 or y >= HEIGHT:
			continue
		for x in WIDTH:
			cleared_lookup[Vector2i(x, y)] = true
	for x in columns:
		if x < 0 or x >= WIDTH:
			continue
		for y in HEIGHT:
			cleared_lookup[Vector2i(x, y)] = true

	var cleared_cells: Array[Vector2i] = []
	for cell: Vector2i in cleared_lookup:
		_cells[cell.y][cell.x] = null
		cleared_cells.append(cell)
	return cleared_cells


func has_legal_placement(shape: Array[Vector2i]) -> bool:
	for y in HEIGHT:
		for x in WIDTH:
			if can_place(shape, Vector2i(x, y)):
				return true
	return false


func get_value(cell: Vector2i) -> Variant:
	if not is_inside(cell):
		return null
	return _cells[cell.y][cell.x]


func occupied_count() -> int:
	var count := 0
	for y in HEIGHT:
		for x in WIDTH:
			if _cells[y][x] != null:
				count += 1
	return count

