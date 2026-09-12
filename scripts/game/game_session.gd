class_name GameSession
extends Node

signal no_moves_reached

@export var board_view_path: NodePath
@export var piece_tray_path: NodePath
@export var drag_preview_path: NodePath
@export var moves_label_path: NodePath
@export var no_moves_label_path: NodePath
@export var pause_popup_path: NodePath
@export var result_popup_path: NodePath
@export_range(60.0, 100.0, 1.0) var touch_drag_lift := 82.0
@export_range(0.0, 30.0, 1.0) var mouse_drag_lift := 8.0

var board_model := BoardModel.new()
var piece_sequence := PieceSequence.new()
var moves := 0

@onready var board_view: BoardView = get_node(board_view_path)
@onready var piece_tray: PieceTray = get_node(piece_tray_path)
@onready var drag_preview: DragPiecePreview = get_node(drag_preview_path)
@onready var moves_label: Label = get_node(moves_label_path)
@onready var no_moves_label: Label = get_node(no_moves_label_path)
@onready var pause_popup: Control = get_node(pause_popup_path)
@onready var result_popup: Control = get_node(result_popup_path)

var _active_slot := -1
var _active_definition: PieceDefinition
var _active_is_touch := false
var _active_origin := Vector2i.ZERO
var _active_cells: Array[Vector2i] = []
var _active_is_valid := false
var _input_blocked := false
var _busy := false
var _no_moves := false


func _ready() -> void:
	piece_tray.drag_started.connect(_on_drag_started)
	piece_tray.drag_moved.connect(_on_drag_moved)
	piece_tray.drag_ended.connect(_on_drag_ended)
	board_model.reset()
	board_view.reset_game_state()
	piece_sequence.reset()
	piece_tray.load_set(piece_sequence.next_set())
	_update_moves_label()
	no_moves_label.hide()


func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	if blocked:
		cancel_active_drag()
	piece_tray.set_interaction_enabled(not blocked and not _busy and not _no_moves)


func cancel_active_drag() -> void:
	piece_tray.cancel_drag()
	board_view.clear_placement_preview()
	drag_preview.clear()
	_clear_active_drag()


func _on_drag_started(slot_index: int, definition: PieceDefinition, pointer_position: Vector2, is_touch: bool) -> void:
	if not _can_interact() or not piece_tray.is_slot_available(slot_index):
		piece_tray.cancel_drag()
		return
	_active_slot = slot_index
	_active_definition = definition
	_active_is_touch = is_touch
	drag_preview.show_definition(
		definition,
		board_view.get_cell_draw_size(),
		board_view.get_cell_step()
	)
	_update_active_drag(pointer_position)


func _on_drag_moved(slot_index: int, pointer_position: Vector2) -> void:
	if slot_index != _active_slot or _active_definition == null:
		return
	if not _can_interact():
		cancel_active_drag()
		return
	_update_active_drag(pointer_position)


func _on_drag_ended(slot_index: int, pointer_position: Vector2) -> void:
	if slot_index != _active_slot or _active_definition == null:
		return
	_update_active_drag(pointer_position)
	var origin := _active_origin
	var is_valid := _active_is_valid and _can_interact()
	board_view.clear_placement_preview()
	drag_preview.clear()
	_clear_active_drag()
	if is_valid:
		try_place_piece(slot_index, origin)


func _update_active_drag(pointer_position: Vector2) -> void:
	var lift := touch_drag_lift if _active_is_touch else mouse_drag_lift
	var preview_position := pointer_position + Vector2(0.0, -lift)
	drag_preview.global_position = preview_position
	var anchor_board_cell := board_view.global_position_to_cell(preview_position)
	_active_origin = anchor_board_cell - _active_definition.get_anchor_cell()
	_active_cells = _active_definition.translated_cells(_active_origin)
	_active_is_valid = board_model.can_place(_active_definition.cells, _active_origin)
	board_view.show_placement_preview(_active_cells, _active_is_valid, _active_definition.cosmetic_color)
	drag_preview.set_valid(_active_is_valid)


func try_place_piece(slot_index: int, origin: Vector2i) -> bool:
	if not _can_interact() or not piece_tray.is_slot_available(slot_index):
		return false
	var definition := piece_tray.get_definition(slot_index)
	if definition == null or not board_model.can_place(definition.cells, origin):
		return false
	_commit_placement(slot_index, definition, origin, definition.translated_cells(origin))
	return true


func _commit_placement(
	slot_index: int,
	definition: PieceDefinition,
	origin: Vector2i,
	target_cells: Array[Vector2i]
) -> void:
	_busy = true
	piece_tray.set_interaction_enabled(false)
	var placed_cells := board_model.place(definition.cells, origin, definition.id)
	if placed_cells.is_empty():
		_busy = false
		piece_tray.set_interaction_enabled(_can_interact())
		return

	board_view.set_cells_occupied(target_cells, definition.cosmetic_color)
	piece_tray.consume_slot(slot_index)
	moves += 1
	_update_moves_label()

	var full_rows := board_model.get_full_rows()
	var full_columns := board_model.get_full_columns()
	if not full_rows.is_empty() or not full_columns.is_empty():
		var cleared_cells := board_model.clear_lines(full_rows, full_columns)
		await board_view.clear_cells_with_feedback(cleared_cells)

	if piece_tray.all_empty():
		piece_tray.load_set(piece_sequence.next_set())
	refresh_no_moves_state()
	_busy = false
	piece_tray.set_interaction_enabled(_can_interact())


func refresh_no_moves_state() -> void:
	_no_moves = true
	for definition in piece_tray.remaining_definitions():
		if board_model.has_legal_placement(definition.cells):
			_no_moves = false
			break
	no_moves_label.visible = _no_moves
	if _no_moves:
		no_moves_reached.emit()


func is_no_moves_state() -> bool:
	return _no_moves


func _update_moves_label() -> void:
	moves_label.text = "Ходы: %d" % moves


func _can_interact() -> bool:
	return (
		not _input_blocked
		and not _busy
		and not _no_moves
		and not pause_popup.visible
		and not result_popup.visible
	)


func _clear_active_drag() -> void:
	_active_slot = -1
	_active_definition = null
	_active_is_touch = false
	_active_origin = Vector2i.ZERO
	_active_cells.clear()
	_active_is_valid = false
