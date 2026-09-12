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


func next_set() -> Array[PieceDefinition]:
	var result: Array[PieceDefinition] = []
	match _set_index:
		0:
			result.assign([SMALL_L, SMALL_T, LINE_3_HORIZONTAL])
		1:
			result.assign([SQUARE_2, DOMINO_VERTICAL, LINE_3_HORIZONTAL])
		_:
			result.assign([SINGLE, DOMINO_HORIZONTAL, LINE_3_VERTICAL])
	_set_index = (_set_index + 1) % 3
	return result


func reset() -> void:
	_set_index = 0

