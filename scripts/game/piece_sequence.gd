class_name PieceSequence
extends RefCounted

## Sets of three pieces for the tray.
##
## With a PieceGenerationConfig (campaign expeditions): the resource-authored
## `curated_piece_sequence` is played once as a scripted start, then every set is
## drawn from the chapter weights. A set depends only on (seed, set number, board),
## so Undo, Hint planning and difficulty checks always see the same pieces.
## If none of the three pieces fits the board, the set is re-rolled; after
## `fairness_attempts` the fallback piece (single block) is put in.
##
## Without a config (old prototypes, tests): the curated triples, or the three
## M1 sets, repeat in a loop as before.

const SMALL_L: PieceDefinition = preload("res://resources/pieces/small_l.tres")
const SMALL_T: PieceDefinition = preload("res://resources/pieces/small_t.tres")
const LINE_3_HORIZONTAL: PieceDefinition = preload("res://resources/pieces/line_3_horizontal.tres")
const SQUARE_2: PieceDefinition = preload("res://resources/pieces/square_2.tres")
const DOMINO_VERTICAL: PieceDefinition = preload("res://resources/pieces/domino_vertical.tres")
const SINGLE: PieceDefinition = preload("res://resources/pieces/single.tres")
const DOMINO_HORIZONTAL: PieceDefinition = preload("res://resources/pieces/domino_horizontal.tres")
const LINE_3_VERTICAL: PieceDefinition = preload("res://resources/pieces/line_3_vertical.tres")

var _set_index := 0
var _curated_pieces: Array[PieceDefinition] = []
var _generation: PieceGenerationConfig
var _seed := 0


func configure(
	curated_pieces: Array[PieceDefinition],
	generation: PieceGenerationConfig = null,
	seed_value: int = 0
) -> void:
	_curated_pieces.assign(curated_pieces)
	_generation = generation
	_seed = seed_value
	reset()


func is_generated() -> bool:
	return _generation != null


## Endless mode: deeper layers switch the weights mid-run. The seed and the set
## number stay, so the sequence remains reproducible for a given run.
func set_generation(generation: PieceGenerationConfig) -> void:
	if generation != null:
		_generation = generation


func generation_config() -> PieceGenerationConfig:
	return _generation


func seed_value() -> int:
	return _seed


func curated_pieces() -> Array[PieceDefinition]:
	return _curated_pieces


## Next set; pass the current board so a set that cannot be placed is re-rolled.
func next_set(board: BoardModel = null, obstacles: ObstacleModel = null) -> Array[PieceDefinition]:
	var result := peek_next_set(board, obstacles)
	_set_index += 1
	if _generation == null:
		_set_index = posmod(_set_index, _loop_count())
	return result


func peek_next_set(board: BoardModel = null, obstacles: ObstacleModel = null) -> Array[PieceDefinition]:
	return set_at(_set_index, board, obstacles)


func set_at(index: int, board: BoardModel = null, obstacles: ObstacleModel = null) -> Array[PieceDefinition]:
	var result: Array[PieceDefinition] = []
	var curated_sets := int(_curated_pieces.size() / 3)
	if _generation == null:
		if curated_sets > 0:
			var start := posmod(index, curated_sets) * 3
			result.assign(_curated_pieces.slice(start, start + 3))
			return result
		return _m1_set(posmod(index, 3))
	if index < curated_sets:
		result.assign(_curated_pieces.slice(index * 3, index * 3 + 3))
		return result
	return _generate(index, board, obstacles)


func reset() -> void:
	_set_index = 0


func capture_position() -> int:
	return _set_index


func restore_position(position: int) -> void:
	_set_index = maxi(0, position) if _generation != null else posmod(position, _loop_count())


## Stable seed from an expedition id (FNV-1a over UTF-8, same on every platform).
static func seed_for(key: String) -> int:
	var hash_value := 2166136261
	for byte in key.to_utf8_buffer():
		hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF
	return hash_value


func _generate(index: int, board: BoardModel, obstacles: ObstacleModel) -> Array[PieceDefinition]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for("%d:%d" % [_seed, index])
	var candidate: Array[PieceDefinition] = []
	for attempt in _generation.fairness_attempts + 1:
		candidate = _draw_set(rng)
		if board == null or _any_fits(candidate, board, obstacles):
			return candidate
	var fallback := _generation.fallback_piece
	if fallback != null and _fits(fallback, board, obstacles):
		candidate[rng.randi_range(0, 2)] = fallback
	return candidate


func _draw_set(rng: RandomNumberGenerator) -> Array[PieceDefinition]:
	var result: Array[PieceDefinition] = []
	var counts: Dictionary = {}
	var draws := 0
	while result.size() < 3:
		var piece := _weighted_pick(rng)
		if piece == null:
			break
		draws += 1
		if int(counts.get(piece.id, 0)) >= _generation.max_same_piece and draws < 50:
			continue
		counts[piece.id] = int(counts.get(piece.id, 0)) + 1
		result.append(piece)
	return result


func _weighted_pick(rng: RandomNumberGenerator) -> PieceDefinition:
	var total := 0.0
	var count := mini(_generation.pieces.size(), _generation.weights.size())
	for index in count:
		total += maxf(_generation.weights[index], 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for index in count:
		roll -= maxf(_generation.weights[index], 0.0)
		if roll < 0.0:
			return _generation.pieces[index]
	return _generation.pieces[count - 1]


func _any_fits(pieces: Array[PieceDefinition], board: BoardModel, obstacles: ObstacleModel) -> bool:
	for piece in pieces:
		if _fits(piece, board, obstacles):
			return true
	return false


func _fits(piece: PieceDefinition, board: BoardModel, obstacles: ObstacleModel) -> bool:
	if piece == null:
		return false
	if obstacles != null:
		return obstacles.has_legal_placement(board, piece.cells)
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if board.can_place(piece.cells, Vector2i(x, y)):
				return true
	return false


func _loop_count() -> int:
	if _curated_pieces.is_empty():
		return 3
	return maxi(1, int(_curated_pieces.size() / 3))


func _m1_set(index: int) -> Array[PieceDefinition]:
	var result: Array[PieceDefinition] = []
	match index:
		0:
			result.assign([SMALL_L, SMALL_T, LINE_3_HORIZONTAL])
		1:
			result.assign([SQUARE_2, DOMINO_VERTICAL, LINE_3_HORIZONTAL])
		_:
			result.assign([SINGLE, DOMINO_HORIZONTAL, LINE_3_VERTICAL])
	return result
