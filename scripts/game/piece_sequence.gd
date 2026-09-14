class_name PieceSequence
extends RefCounted

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


func configure(curated_pieces: Array[PieceDefinition]) -> void:
	_curated_pieces.assign(curated_pieces)
	reset()


func next_set() -> Array[PieceDefinition]:
	var result := peek_next_set()
	_set_index = (_set_index + 1) % _set_count()
	return result


func peek_next_set() -> Array[PieceDefinition]:
	var result: Array[PieceDefinition] = []
	if not _curated_pieces.is_empty():
		var start := _set_index * 3
		result.assign(_curated_pieces.slice(start, start + 3))
		return result
	match _set_index:
		0:
			result.assign([SMALL_L, SMALL_T, LINE_3_HORIZONTAL])
		1:
			result.assign([SQUARE_2, DOMINO_VERTICAL, LINE_3_HORIZONTAL])
		_:
			result.assign([SINGLE, DOMINO_HORIZONTAL, LINE_3_VERTICAL])
	return result


func reset() -> void:
	_set_index = 0


func capture_position() -> int:
	return _set_index


func restore_position(position: int) -> void:
	_set_index = posmod(position, _set_count())


func _set_count() -> int:
	if _curated_pieces.is_empty():
		return 3
	return maxi(1, int(_curated_pieces.size() / 3))
