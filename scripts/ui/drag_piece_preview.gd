class_name DragPiecePreview
extends Control

@export_range(0.0, 24.0, 1.0) var cell_inset := 8.0
@export_range(0.1, 1.0, 0.05) var preview_alpha := 0.92
@export var invalid_modulate := Color(1.0, 0.48, 0.42, 0.92)
@export var block_texture_set: BlockTextureSet

var _visual_cells: Array[TextureRect] = []
var _definition: PieceDefinition


func _ready() -> void:
	for child in get_children():
		if child is TextureRect:
			_visual_cells.append(child)
	hide()


func show_definition(definition: PieceDefinition, board_cell_size: Vector2, board_cell_step: Vector2) -> void:
	_definition = definition
	for visual_cell in _visual_cells:
		visual_cell.hide()
	var anchor := definition.get_anchor_cell()
	var draw_size := Vector2(
		maxf(20.0, board_cell_size.x - cell_inset),
		maxf(20.0, board_cell_size.y - cell_inset)
	)
	for index in mini(_visual_cells.size(), definition.cells.size()):
		var visual_cell := _visual_cells[index]
		visual_cell.position = Vector2(definition.cells[index] - anchor) * board_cell_step - draw_size * 0.5
		visual_cell.size = draw_size
		visual_cell.texture = BlockTextureResolver.texture_for_color(
			block_texture_set,
			definition.cosmetic_color
		)
		visual_cell.modulate = _valid_modulate()
		visual_cell.show()
	show()


func set_valid(is_valid: bool) -> void:
	for visual_cell in _visual_cells:
		if visual_cell.visible:
			visual_cell.modulate = _valid_modulate() if is_valid else invalid_modulate


func clear() -> void:
	_definition = null
	hide()


func _valid_modulate() -> Color:
	return Color(1.0, 1.0, 1.0, preview_alpha)
