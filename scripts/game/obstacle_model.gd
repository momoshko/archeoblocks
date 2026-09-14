class_name ObstacleModel
extends RefCounted

const WIDTH := 8
const HEIGHT := 8

enum Kind {
	STONE,
	ROOT,
}

const ROOT_DURABILITY := 1
const ROOT_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]

var _durability_by_cell: Dictionary = {}
var _kind_by_cell: Dictionary = {}


func reset() -> void:
	_durability_by_cell.clear()
	_kind_by_cell.clear()


func load_expedition(definition: ExpeditionDefinition) -> PackedStringArray:
	reset()
	if definition == null:
		return PackedStringArray(["ExpeditionDefinition is null"])
	var errors := definition.validate()
	if not errors.is_empty():
		return errors
	for obstacle in definition.stone_obstacles:
		set_obstacle(obstacle.cell, obstacle.durability, Kind.STONE)
	for root in definition.root_obstacles:
		set_obstacle(root.cell, ROOT_DURABILITY, Kind.ROOT)
	return errors


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func has_obstacle(cell: Vector2i) -> bool:
	return get_durability(cell) > 0


func get_durability(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return int(_durability_by_cell.get(cell, 0))


func get_kind(cell: Vector2i) -> int:
	if not has_obstacle(cell):
		return -1
	return int(_kind_by_cell.get(cell, Kind.STONE))


func is_stone(cell: Vector2i) -> bool:
	return get_kind(cell) == Kind.STONE


func is_root(cell: Vector2i) -> bool:
	return get_kind(cell) == Kind.ROOT


func set_obstacle(cell: Vector2i, durability: int, kind: int = Kind.STONE) -> bool:
	if not is_inside(cell) or durability <= 0:
		return false
	if kind != Kind.STONE and kind != Kind.ROOT:
		return false
	var existing_kind := get_kind(cell)
	if existing_kind >= 0 and existing_kind != kind:
		return false
	_durability_by_cell[cell] = durability
	_kind_by_cell[cell] = kind
	return true


func set_root(cell: Vector2i) -> bool:
	return set_obstacle(cell, ROOT_DURABILITY, Kind.ROOT)


func root_count() -> int:
	var count := 0
	for cell: Vector2i in _durability_by_cell:
		if is_root(cell):
			count += 1
	return count


func get_root_cells() -> Array[Vector2i]:
	var roots: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if is_root(cell):
				roots.append(cell)
	return roots


func find_root_growth_target(board: BoardModel) -> Dictionary:
	for source in get_root_cells():
		for direction in ROOT_DIRECTIONS:
			var destination := source + direction
			if can_grow_root_to(source, destination, board):
				return {"source": source, "destination": destination}
	return {}


func can_grow_root_to(source: Vector2i, destination: Vector2i, board: BoardModel) -> bool:
	if not is_root(source) or not is_inside(destination):
		return false
	if absi(destination.x - source.x) + absi(destination.y - source.y) != 1:
		return false
	return not has_obstacle(destination) and board.is_empty(destination)


func grow_root(source: Vector2i, destination: Vector2i, board: BoardModel) -> bool:
	if not can_grow_root_to(source, destination, board):
		return false
	return set_root(destination)


func can_place(board: BoardModel, shape: Array[Vector2i], origin: Vector2i) -> bool:
	if not board.can_place(shape, origin):
		return false
	for offset in shape:
		if has_obstacle(origin + offset):
			return false
	return true


func get_full_rows(board: BoardModel) -> Array[int]:
	var rows: Array[int] = []
	for y in HEIGHT:
		var is_full := true
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if board.is_empty(cell) and not has_obstacle(cell):
				is_full = false
				break
		if is_full:
			rows.append(y)
	return rows


func get_full_columns(board: BoardModel) -> Array[int]:
	var columns: Array[int] = []
	for x in WIDTH:
		var is_full := true
		for y in HEIGHT:
			var cell := Vector2i(x, y)
			if board.is_empty(cell) and not has_obstacle(cell):
				is_full = false
				break
		if is_full:
			columns.append(x)
	return columns


func has_legal_placement(board: BoardModel, shape: Array[Vector2i]) -> bool:
	for y in HEIGHT:
		for x in WIDTH:
			if can_place(board, shape, Vector2i(x, y)):
				return true
	return false


func count_legal_placements(board: BoardModel, shape: Array[Vector2i]) -> int:
	var count := 0
	for y in HEIGHT:
		for x in WIDTH:
			if can_place(board, shape, Vector2i(x, y)):
				count += 1
	return count


func occupied_count() -> int:
	return _durability_by_cell.size()


func apply_hit_map(hit_map: Dictionary) -> Dictionary:
	var overflow_hit_map: Dictionary = {}
	var damaged_cells: Array[Vector2i] = []
	var destroyed_cells: Array[Vector2i] = []
	var obstacle_hits_applied := 0
	var stone_hits_applied := 0
	var root_hits_applied := 0
	var damaged_stone_cells: Array[Vector2i] = []
	var destroyed_stone_cells: Array[Vector2i] = []
	var damaged_root_cells: Array[Vector2i] = []
	var destroyed_root_cells: Array[Vector2i] = []
	for cell: Vector2i in hit_map:
		var incoming_hits := maxi(0, int(hit_map[cell]))
		if incoming_hits <= 0:
			continue
		var durability := get_durability(cell)
		if durability > 0:
			var kind := get_kind(cell)
			var obstacle_hits := mini(durability, incoming_hits)
			var remaining_durability := durability - obstacle_hits
			incoming_hits -= obstacle_hits
			obstacle_hits_applied += obstacle_hits
			damaged_cells.append(cell)
			if kind == Kind.ROOT:
				root_hits_applied += obstacle_hits
				damaged_root_cells.append(cell)
			else:
				stone_hits_applied += obstacle_hits
				damaged_stone_cells.append(cell)
			if remaining_durability <= 0:
				_durability_by_cell.erase(cell)
				_kind_by_cell.erase(cell)
				destroyed_cells.append(cell)
				if kind == Kind.ROOT:
					destroyed_root_cells.append(cell)
				else:
					destroyed_stone_cells.append(cell)
			else:
				_durability_by_cell[cell] = remaining_durability
		if incoming_hits > 0:
			overflow_hit_map[cell] = incoming_hits
	return {
		"overflow_hit_map": overflow_hit_map,
		"damaged_cells": damaged_cells,
		"destroyed_cells": destroyed_cells,
		"obstacle_hits_applied": obstacle_hits_applied,
		"obstacles_destroyed": destroyed_cells.size(),
		"stone_hits_applied": stone_hits_applied,
		"stones_destroyed": destroyed_stone_cells.size(),
		"root_hits_applied": root_hits_applied,
		"roots_destroyed": destroyed_root_cells.size(),
		"damaged_stone_cells": damaged_stone_cells,
		"destroyed_stone_cells": destroyed_stone_cells,
		"damaged_root_cells": damaged_root_cells,
		"destroyed_root_cells": destroyed_root_cells,
	}


func capture_state() -> Dictionary:
	return {
		"durability_by_cell": _durability_by_cell.duplicate(true),
		"kind_by_cell": _kind_by_cell.duplicate(true),
	}


func restore_state(state: Dictionary) -> void:
	if state.has("durability_by_cell"):
		_durability_by_cell = state.get("durability_by_cell", {}).duplicate(true)
		_kind_by_cell = state.get("kind_by_cell", {}).duplicate(true)
	else:
		# Backward-compatible with snapshots/tests created before obstacle kinds existed.
		_durability_by_cell = state.duplicate(true)
		_kind_by_cell.clear()
		for cell: Vector2i in _durability_by_cell:
			_kind_by_cell[cell] = Kind.STONE
