class_name ExcavationModel
extends RefCounted

const WIDTH := 8
const HEIGHT := 8

var _soil_depths: Array = []
var _artifact_owner_by_cell: Dictionary = {}
var _fragment_cells: Dictionary = {}
var _fragment_collected: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_soil_depths.clear()
	for y in HEIGHT:
		var row: Array[int] = []
		row.resize(WIDTH)
		row.fill(0)
		_soil_depths.append(row)
	_artifact_owner_by_cell.clear()
	_fragment_cells.clear()
	_fragment_collected.clear()


func load_expedition(definition: ExpeditionDefinition) -> PackedStringArray:
	reset()
	if definition == null:
		return PackedStringArray(["ExpeditionDefinition is null"])
	var errors := definition.validate()
	if not errors.is_empty():
		return errors

	for cell in definition.normal_soil_cells:
		_soil_depths[cell.y][cell.x] = 1
	for cell in definition.strong_soil_cells:
		_soil_depths[cell.y][cell.x] = 2
	for fragment in definition.artifact_fragments:
		var copied_cells: Array[Vector2i] = []
		copied_cells.assign(fragment.cells)
		_fragment_cells[fragment.id] = copied_cells
		_fragment_collected[fragment.id] = false
		for cell in fragment.cells:
			_artifact_owner_by_cell[cell] = fragment.id
	return errors


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func get_soil_depth(cell: Vector2i) -> int:
	if not is_inside(cell):
		return 0
	return _soil_depths[cell.y][cell.x]


func dig(cell: Vector2i, amount: int = 1) -> int:
	if not is_inside(cell) or amount <= 0:
		return 0
	var previous_depth := get_soil_depth(cell)
	var next_depth := maxi(0, previous_depth - amount)
	_soil_depths[cell.y][cell.x] = next_depth
	return previous_depth - next_depth


func is_excavated(cell: Vector2i) -> bool:
	return is_inside(cell) and get_soil_depth(cell) == 0


func get_artifact_fragment_id(cell: Vector2i) -> StringName:
	return _artifact_owner_by_cell.get(cell, &"")


func get_fragment_cells(fragment_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _fragment_cells.has(fragment_id):
		result.assign(_fragment_cells[fragment_id])
	return result


func fragment_is_complete(fragment_id: StringName) -> bool:
	if not _fragment_cells.has(fragment_id):
		return false
	for cell: Vector2i in _fragment_cells[fragment_id]:
		if get_soil_depth(cell) > 0:
			return false
	return true


func collect_newly_completed_fragments() -> Array[StringName]:
	var collected: Array[StringName] = []
	for fragment_id: StringName in _fragment_cells:
		if not _fragment_collected[fragment_id] and fragment_is_complete(fragment_id):
			_fragment_collected[fragment_id] = true
			collected.append(fragment_id)
	return collected


func is_fragment_collected(fragment_id: StringName) -> bool:
	return _fragment_collected.get(fragment_id, false)


func all_fragments_complete() -> bool:
	if _fragment_collected.is_empty():
		return false
	for collected: bool in _fragment_collected.values():
		if not collected:
			return false
	return true


func collected_fragment_count() -> int:
	var count := 0
	for collected: bool in _fragment_collected.values():
		if collected:
			count += 1
	return count


func fragment_count() -> int:
	return _fragment_cells.size()


func apply_hit_map(hit_map: Dictionary) -> Array[Vector2i]:
	return apply_hit_map_detailed(hit_map).changed_cells


func apply_hit_map_detailed(hit_map: Dictionary) -> Dictionary:
	var changed_cells: Array[Vector2i] = []
	var hits_applied := 0
	for cell: Vector2i in hit_map:
		var amount: int = hit_map[cell]
		var applied := dig(cell, amount)
		hits_applied += applied
		if applied > 0:
			changed_cells.append(cell)
	return {
		"changed_cells": changed_cells,
		"hits_applied": hits_applied,
	}


func capture_state() -> Dictionary:
	return {
		"soil_depths": _soil_depths.duplicate(true),
		"artifact_owner_by_cell": _artifact_owner_by_cell.duplicate(true),
		"fragment_cells": _fragment_cells.duplicate(true),
		"fragment_collected": _fragment_collected.duplicate(true),
	}


func restore_state(state: Dictionary) -> void:
	_soil_depths = state.get("soil_depths", []).duplicate(true)
	_artifact_owner_by_cell = state.get("artifact_owner_by_cell", {}).duplicate(true)
	_fragment_cells = state.get("fragment_cells", {}).duplicate(true)
	_fragment_collected = state.get("fragment_collected", {}).duplicate(true)


static func build_line_hit_map(rows: Array[int], columns: Array[int]) -> Dictionary:
	var hit_map: Dictionary = {}
	for y in rows:
		if y < 0 or y >= HEIGHT:
			continue
		for x in WIDTH:
			var cell := Vector2i(x, y)
			hit_map[cell] = hit_map.get(cell, 0) + 1
	for x in columns:
		if x < 0 or x >= WIDTH:
			continue
		for y in HEIGHT:
			var cell := Vector2i(x, y)
			hit_map[cell] = hit_map.get(cell, 0) + 1
	return hit_map
