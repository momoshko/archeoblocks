class_name DragPiecePreview
extends Control

@export_range(0.0, 24.0, 1.0) var cell_inset := 14.0
@export_range(0.1, 1.0, 0.05) var preview_alpha := 0.78
@export var invalid_color := Color(0.85, 0.18, 0.12, 0.78)

var _visual_cells: Array[ColorRect] = []
var _definition: PieceDefinition


func _ready() -> void:
	for child in get_children():
		if child is ColorRect:
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
		visual_cell.color = _valid_color()
		visual_cell.show()
	show()


func set_valid(is_valid: bool) -> void:
	for visual_cell in _visual_cells:
		if visual_cell.visible:
			visual_cell.color = _valid_color() if is_valid else invalid_color


func clear() -> void:
	_definition = null
	hide()


func _valid_color() -> Color:
	if _definition == null:
		return Color.WHITE
	return Color(
		_definition.cosmetic_color.r,
		_definition.cosmetic_color.g,
		_definition.cosmetic_color.b,
		preview_alpha
	)

