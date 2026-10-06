class_name PieceGenerationConfig
extends Resource

## Weighted random refills for an expedition (used by PieceSequence).
## One config per chapter lives in resources/config/pieces_chapter_*.tres.
## A bigger weight means the piece comes more often; 0 removes it.

@export var pieces: Array[PieceDefinition] = []
@export var weights: PackedFloat32Array = PackedFloat32Array()
## At most this many copies of the same piece in one set of three.
@export_range(1, 3, 1) var max_same_piece := 2
## How many times a set is re-rolled when none of its pieces fits the board.
@export_range(0, 50, 1) var fairness_attempts := 12
## Put into the set when re-rolling did not help (usually the single block).
@export var fallback_piece: PieceDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if pieces.is_empty():
		errors.append("piece generation needs at least one piece")
	if weights.size() != pieces.size():
		errors.append("piece generation weights must match pieces (%d vs %d)" % [weights.size(), pieces.size()])
	var total := 0.0
	for index in pieces.size():
		if pieces[index] == null:
			errors.append("piece generation contains a null piece")
		if index < weights.size():
			if weights[index] < 0.0:
				errors.append("piece generation weight must not be negative")
			total += weights[index]
	if total <= 0.0:
		errors.append("piece generation weights must add up to more than zero")
	return errors
