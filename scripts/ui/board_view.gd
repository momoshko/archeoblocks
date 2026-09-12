class_name BoardView
extends PanelContainer

const BOARD_WIDTH := 8
const BOARD_HEIGHT := 8

@export_range(0.05, 1.0, 0.01) var clear_feedback_duration := 0.16

@onready var grid: GridContainer = $Grid

var _cell_views: Array[CellView] = []
var _preview_cells: Array[Vector2i] = []


func _ready() -> void:
	_cache_cell_views()
	reset_game_state()


func _cache_cell_views() -> void:
	_cell_views.clear()
	for child in grid.get_children():
		if child is CellView:
			_cell_views.append(child)
	assert(_cell_views.size() == BOARD_WIDTH * BOARD_HEIGHT, "BoardView requires 64 editor-authored CellView nodes")


func reset_game_state() -> void:
	for cell_view in _cell_views:
		cell_view.set_empty()
	_preview_cells.clear()


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_WIDTH and cell.y >= 0 and cell.y < BOARD_HEIGHT


func get_cell_view(cell: Vector2i) -> CellView:
	if not is_inside(cell):
		return null
	return _cell_views[cell.y * BOARD_WIDTH + cell.x]


func global_position_to_cell(pointer_global: Vector2) -> Vector2i:
	if _cell_views.size() < BOARD_WIDTH + 1:
		return Vector2i(-999, -999)
	var local_pointer: Vector2 = grid.get_global_transform().affine_inverse() * pointer_global
	var first_center := _cell_views[0].position + _cell_views[0].size * 0.5
	var right_center := _cell_views[1].position + _cell_views[1].size * 0.5
	var below_center := _cell_views[BOARD_WIDTH].position + _cell_views[BOARD_WIDTH].size * 0.5
	var step_x := right_center.x - first_center.x
	var step_y := below_center.y - first_center.y
	if is_zero_approx(step_x) or is_zero_approx(step_y):
		return Vector2i(-999, -999)
	return Vector2i(
		roundi((local_pointer.x - first_center.x) / step_x),
		roundi((local_pointer.y - first_center.y) / step_y)
	)


func get_cell_draw_size() -> Vector2:
	if _cell_views.is_empty():
		return Vector2(60.0, 60.0)
	return _cell_views[0].size


func get_cell_step() -> Vector2:
	if _cell_views.size() < BOARD_WIDTH + 1:
		return Vector2(65.0, 65.0)
	var first_center := _cell_views[0].position + _cell_views[0].size * 0.5
	var right_center := _cell_views[1].position + _cell_views[1].size * 0.5
	var below_center := _cell_views[BOARD_WIDTH].position + _cell_views[BOARD_WIDTH].size * 0.5
	return Vector2(right_center.x - first_center.x, below_center.y - first_center.y)


func get_cell_global_center(cell: Vector2i) -> Vector2:
	var cell_view := get_cell_view(cell)
	if cell_view == null:
		return Vector2.ZERO
	return cell_view.get_global_rect().get_center()


func show_placement_preview(cells: Array[Vector2i], is_valid: bool, cosmetic_color: Color) -> void:
	clear_placement_preview()
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_preview(is_valid, cosmetic_color)
			_preview_cells.append(cell)


func clear_placement_preview() -> void:
	for cell in _preview_cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.clear_preview()
	_preview_cells.clear()


func set_cells_occupied(cells: Array[Vector2i], cosmetic_color: Color) -> void:
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_occupied(cosmetic_color)


func clear_cells_with_feedback(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.start_clear_feedback(clear_feedback_duration)
	await get_tree().create_timer(clear_feedback_duration).timeout
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_empty()
