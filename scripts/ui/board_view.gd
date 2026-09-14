class_name BoardView
extends PanelContainer

const BOARD_WIDTH := 8
const BOARD_HEIGHT := 8

@export_range(0.05, 1.0, 0.01) var clear_feedback_duration := 0.16
@export_range(0.05, 1.0, 0.01) var stone_hit_feedback_duration := 0.22
@export_range(0.05, 1.0, 0.01) var root_hit_feedback_duration := 0.24
@export_range(0.2, 0.4, 0.01) var root_growth_feedback_duration := 0.28

@onready var grid: GridContainer = $BoardContentCenter/Grid

var _cell_views: Array[CellView] = []
var _preview_cells: Array[Vector2i] = []
var _preview_artifact_targets: Array[Vector2i] = []
var _hint_artifact_targets: Array[Vector2i] = []
var _artifact_intro_played := false
var _root_warning_cell := Vector2i(-1, -1)


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
		cell_view.reset_visual_state()
	_preview_cells.clear()
	_preview_artifact_targets.clear()
	_artifact_intro_played = false
	_root_warning_cell = Vector2i(-1, -1)


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


func show_placement_preview(
	cells: Array[Vector2i],
	is_valid: bool,
	cosmetic_color: Color,
	artifact_hit_cells: Array[Vector2i] = []
) -> void:
	clear_placement_preview()
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_preview(is_valid, cosmetic_color)
			_preview_cells.append(cell)
	if is_valid:
		for cell in artifact_hit_cells:
			var target_view := get_cell_view(cell)
			if target_view != null:
				target_view.set_artifact_target_emphasized(true)
				_preview_artifact_targets.append(cell)


func clear_placement_preview() -> void:
	for cell in _preview_cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.clear_preview()
	_preview_cells.clear()
	for cell in _preview_artifact_targets:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_artifact_target_emphasized(false)
	_preview_artifact_targets.clear()


func set_cells_occupied(cells: Array[Vector2i], cosmetic_color: Color) -> void:
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_occupied(cosmetic_color)


func set_stone_obstacle(cell: Vector2i, durability: int) -> void:
	var cell_view := get_cell_view(cell)
	if cell_view != null:
		cell_view.set_stone_obstacle(durability)


func clear_stone_obstacle(cell: Vector2i) -> void:
	var cell_view := get_cell_view(cell)
	if cell_view != null:
		cell_view.clear_stone_obstacle()


func set_root_obstacle(cell: Vector2i) -> void:
	var cell_view := get_cell_view(cell)
	if cell_view != null:
		cell_view.set_root_obstacle()


func clear_root_obstacle(cell: Vector2i) -> void:
	var cell_view := get_cell_view(cell)
	if cell_view != null:
		cell_view.clear_root_obstacle()


func show_stone_hit_feedback(
	damaged_cells: Array[Vector2i],
	destroyed_cells: Array[Vector2i]
) -> void:
	for cell in damaged_cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.play_stone_hit_feedback(
				destroyed_cells.has(cell),
				stone_hit_feedback_duration
			)
	if damaged_cells.is_empty():
		return
	await get_tree().create_timer(stone_hit_feedback_duration).timeout
	for cell in destroyed_cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.clear_stone_obstacle()


func show_root_hit_feedback(destroyed_cells: Array[Vector2i]) -> void:
	for cell in destroyed_cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.play_root_hit_feedback(true, root_hit_feedback_duration)
	if destroyed_cells.is_empty():
		return
	await get_tree().create_timer(root_hit_feedback_duration).timeout
	for cell in destroyed_cells:
		clear_root_obstacle(cell)


func show_root_growth_feedback(source: Vector2i, destination: Vector2i) -> void:
	var source_view := get_cell_view(source)
	var destination_view := get_cell_view(destination)
	if source_view != null:
		source_view.play_root_growth_source_feedback(root_growth_feedback_duration)
	if destination_view != null:
		destination_view.set_root_obstacle()
		destination_view.play_root_growth_appear(root_growth_feedback_duration)
	await get_tree().create_timer(root_growth_feedback_duration).timeout


func show_root_growth_warning(cell: Vector2i) -> void:
	clear_root_growth_warning()
	var cell_view := get_cell_view(cell)
	if cell_view != null:
		cell_view.set_root_growth_warning(true)
		_root_warning_cell = cell


func clear_root_growth_warning() -> void:
	var cell_view := get_cell_view(_root_warning_cell)
	if cell_view != null:
		cell_view.set_root_growth_warning(false)
	_root_warning_cell = Vector2i(-1, -1)


func set_excavation_cell(
	cell: Vector2i,
	soil_depth: int,
	has_artifact: bool,
	fragment_collected := false,
	emphasize_remaining := false,
	show_feedback := false
) -> void:
	var cell_view := get_cell_view(cell)
	if cell_view == null:
		return
	cell_view.set_excavation_state(
		soil_depth,
		has_artifact,
		fragment_collected,
		emphasize_remaining
	)
	if show_feedback:
		cell_view.play_dig_feedback()


func show_fragment_found_feedback(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.start_fragment_found_feedback()
	await get_tree().create_timer(0.32).timeout
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.finish_fragment_found_feedback()


func show_hint_cells(
	cells: Array[Vector2i],
	artifact_hit_cells: Array[Vector2i] = [],
	cosmetic_color: Color = Color.WHITE
) -> void:
	clear_hint_cells()
	for cell in cells:
		var cell_view := get_cell_view(cell)
		if cell_view != null:
			cell_view.set_hint_highlight(true, cosmetic_color)
	for cell in artifact_hit_cells:
		var target_view := get_cell_view(cell)
		if target_view != null:
			target_view.set_artifact_target_emphasized(true)
			_hint_artifact_targets.append(cell)


func clear_hint_cells() -> void:
	for cell_view in _cell_views:
		cell_view.set_hint_highlight(false)
	for cell in _hint_artifact_targets:
		var target_view := get_cell_view(cell)
		if target_view != null:
			target_view.set_artifact_target_emphasized(false)
	_hint_artifact_targets.clear()


func play_artifact_targets_intro() -> void:
	if _artifact_intro_played:
		return
	_artifact_intro_played = true
	for cell_view in _cell_views:
		cell_view.play_artifact_target_intro()


func has_artifact_targets_intro_played() -> bool:
	return _artifact_intro_played


func clear_transient_feedback() -> void:
	clear_placement_preview()
	clear_hint_cells()
	for cell_view in _cell_views:
		cell_view.clear_transient_feedback()


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
