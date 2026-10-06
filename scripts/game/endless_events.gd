class_name EndlessEvents
extends RefCounted

## Events of Endless Excavation (pure logic, no nodes):
## - dig spots: now and then a cell gets soil with a find from the player's
##   collection under it; it must be dug up (a line through it) within a few
##   moves, or the soil caves in and the find is lost;
## - deeper layers drop stones and let roots sprout on empty cells;
## - the Daily Dig: the same pieces for everyone today, the goal is a number of
##   finds.
## GameSession applies the returned events to the models and the board.

const SPOT_PREFIX := "spot_"

var finds_found := 0
var daily := false
## fragment id -> {cell: Vector2i, moves_left: int, deep: bool, find: ExpeditionDefinition}
var spots: Dictionary = {}

var _definition: EndlessDefinition
var _rng := RandomNumberGenerator.new()
var _lines_since_spot := 0
var _moves_since_stone := 0
var _moves_since_root := 0
var _spot_counter := 0
var _pool: Array[ExpeditionDefinition] = []


func reset(definition: EndlessDefinition, seed_value: int, is_daily: bool, pool: Array[ExpeditionDefinition]) -> void:
	_definition = definition
	daily = is_daily
	_rng.seed = seed_value ^ 0x5eed
	_pool = pool
	finds_found = 0
	spots.clear()
	_lines_since_spot = 0
	_moves_since_stone = 0
	_moves_since_root = 0
	_spot_counter = 0


func lines_per_spot() -> int:
	return _definition.daily_find_every_lines if daily else _definition.find_every_lines


func daily_goal() -> int:
	return _definition.daily_goal_finds


func is_daily_goal_reached() -> bool:
	return daily and finds_found >= daily_goal()


## One move is over (lines cleared, soil dug). Returns what happens on the board:
## {type: "spot_expired", id, cell} / {type: "spot_new", id, cell, depth, find} /
## {type: "stone", cell, durability} / {type: "root", cell}.
func after_move(
	line_count: int,
	depth: int,
	board: BoardModel,
	obstacles: ObstacleModel,
	excavation: ExcavationModel
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id: StringName in spots.keys():
		var spot: Dictionary = spots[id]
		spot.moves_left = int(spot.moves_left) - 1
		if int(spot.moves_left) <= 0:
			events.append({"type": "spot_expired", "id": id, "cell": spot.cell})
			spots.erase(id)

	_lines_since_spot += line_count
	if _lines_since_spot >= lines_per_spot() and spots.size() < _definition.max_spots and not _pool.is_empty():
		var cell := _pick_free_cell(board, obstacles, excavation)
		if cell.x >= 0:
			_lines_since_spot = 0
			_spot_counter += 1
			var id := StringName("%s%d" % [SPOT_PREFIX, _spot_counter])
			var deep := depth >= _definition.deep_spot_from_depth
			var find := _pool[_rng.randi_range(0, _pool.size() - 1)]
			spots[id] = {"cell": cell, "moves_left": _definition.spot_moves, "deep": deep, "find": find}
			events.append({"type": "spot_new", "id": id, "cell": cell, "depth": 2 if deep else 1, "find": find})

	var layer := _definition.layer_for_depth(depth)
	if layer != null and layer.stone_every_moves > 0:
		_moves_since_stone += 1
		if _moves_since_stone >= layer.stone_every_moves:
			var cell := _pick_free_cell(board, obstacles, excavation)
			if cell.x >= 0:
				_moves_since_stone = 0
				events.append({"type": "stone", "cell": cell, "durability": layer.stone_durability})
	if layer != null and layer.root_every_moves > 0 and obstacles.root_count() < layer.max_roots:
		_moves_since_root += 1
		if _moves_since_root >= layer.root_every_moves:
			var cell := _pick_free_cell(board, obstacles, excavation)
			if cell.x >= 0:
				_moves_since_root = 0
				events.append({"type": "root", "cell": cell})
	return events


## The spot was dug up: returns its data (find, deep) and counts the find.
func on_spot_found(id: StringName) -> Dictionary:
	if not spots.has(id):
		return {}
	var spot: Dictionary = spots[id]
	spots.erase(id)
	finds_found += 1
	return spot


func spot_bonus(spot: Dictionary) -> int:
	return _definition.spot_bonus * (2 if bool(spot.get("deep", false)) else 1)


## A random empty cell: no block, no obstacle, no soil; away from the board edge
## when possible, so the spot can be reached by both a row and a column.
func _pick_free_cell(board: BoardModel, obstacles: ObstacleModel, excavation: ExcavationModel) -> Vector2i:
	var inner: Array[Vector2i] = []
	var edge: Array[Vector2i] = []
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if not board.is_empty(cell) or obstacles.has_obstacle(cell) or excavation.get_soil_depth(cell) > 0:
				continue
			if x == 0 or y == 0 or x == BoardModel.WIDTH - 1 or y == BoardModel.HEIGHT - 1:
				edge.append(cell)
			else:
				inner.append(cell)
	var pool := inner if not inner.is_empty() else edge
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[_rng.randi_range(0, pool.size() - 1)]
