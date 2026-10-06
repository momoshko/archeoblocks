class_name EndlessLayer
extends Resource

## One depth layer of Endless Excavation (see EndlessDefinition).

## Shown when the player reaches this layer ("Глина", "Катакомбы").
@export var title_ru := ""
## The layer starts at this depth in metres.
@export_range(0, 999, 1) var from_depth := 0
## Which pieces come and how often while the player is in this layer.
@export var piece_generation: PieceGenerationConfig
## A stone drops on an empty cell every this many moves (0 = never).
@export_range(0, 100, 1) var stone_every_moves := 0
@export_range(1, 3, 1) var stone_durability := 1
## A root sprouts on an empty cell every this many moves (0 = never), while
## fewer than max_roots roots are on the board.
@export_range(0, 100, 1) var root_every_moves := 0
@export_range(0, 8, 1) var max_roots := 0
## Picture behind the board while the player is in this layer. Empty: keep the current one.
@export var background_texture: Texture2D


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if title_ru.strip_edges().is_empty():
		errors.append("endless layer needs a title")
	if piece_generation == null:
		errors.append("endless layer %s needs piece_generation" % title_ru)
	else:
		errors.append_array(piece_generation.validate())
	return errors
