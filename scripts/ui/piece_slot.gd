class_name PieceSlot
extends PanelContainer

signal drag_started(definition: PieceDefinition, pointer_position: Vector2, is_touch: bool)
signal drag_moved(pointer_position: Vector2)
signal drag_ended(pointer_position: Vector2)

@export_range(12.0, 40.0, 1.0) var preview_cell_size := 26.0
@export_range(0.0, 12.0, 1.0) var preview_gap := 2.0
@export_range(0.0, 24.0, 1.0) var preview_padding := 5.0
@export var block_texture_set: BlockTextureSet

@onready var piece_name: Label = $SlotLayout/PieceName
@onready var piece_canvas: Control = $SlotLayout/PieceCanvas
@onready var hint_highlight: Panel = $HintHighlight

var _piece_cells: Array[TextureRect] = []
var _definition: PieceDefinition
var _available := false
var _interaction_enabled := true
var _dragging := false
var _touch_drag := false
var _touch_index := -1


func _ready() -> void:
	for child in piece_canvas.get_children():
		if child is TextureRect:
			_piece_cells.append(child)
	piece_canvas.resized.connect(_layout_piece_preview)
	_refresh_visual()
	call_deferred("_layout_piece_preview")


func set_definition(value: PieceDefinition) -> void:
	_definition = value
	_available = value != null
	_dragging = false
	_refresh_visual()


func get_definition() -> PieceDefinition:
	return _definition


func is_available() -> bool:
	return _available


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_update_mouse_filter()
	if not enabled:
		cancel_drag()


func cancel_drag() -> void:
	_dragging = false
	_touch_drag = false
	_touch_index = -1


func set_hint_highlight(enabled: bool) -> void:
	hint_highlight.visible = enabled


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	for piece_cell in _piece_cells:
		piece_cell.hide()
	if _definition == null:
		piece_name.text = "Использовано"
		modulate = Color(1.0, 1.0, 1.0, 0.45)
		_update_mouse_filter()
		return

	piece_name.text = _definition.display_name
	modulate = Color.WHITE
	_layout_piece_preview()
	_update_mouse_filter()


func _layout_piece_preview() -> void:
	if not is_node_ready() or _definition == null or _definition.cells.is_empty():
		return
	var minimum := _definition.cells[0]
	var maximum := _definition.cells[0]
	for cell in _definition.cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var dimensions := maximum - minimum + Vector2i.ONE
	var available_size := piece_canvas.size - Vector2.ONE * preview_padding * 2.0
	var fit_x := (available_size.x - preview_gap * (dimensions.x - 1)) / dimensions.x
	var fit_y := (available_size.y - preview_gap * (dimensions.y - 1)) / dimensions.y
	var cell_size := minf(preview_cell_size, minf(fit_x, fit_y))
	var step := cell_size + preview_gap
	var visual_size := Vector2(dimensions) * cell_size
	visual_size += Vector2(dimensions - Vector2i.ONE) * preview_gap
	var start := (piece_canvas.size - visual_size) * 0.5
	for index in mini(_piece_cells.size(), _definition.cells.size()):
		var piece_cell := _piece_cells[index]
		piece_cell.position = start + Vector2(_definition.cells[index] - minimum) * step
		piece_cell.size = Vector2.ONE * cell_size
		piece_cell.texture = BlockTextureResolver.texture_for_color(
			block_texture_set,
			_definition.cosmetic_color
		)
		piece_cell.modulate = Color.WHITE
		piece_cell.show()


func get_piece_visual_bounds() -> Rect2:
	var bounds := Rect2()
	var has_visible_cell := false
	for piece_cell in _piece_cells:
		if not piece_cell.visible:
			continue
		if not has_visible_cell:
			bounds = Rect2(piece_cell.position, piece_cell.size)
			has_visible_cell = true
		else:
			bounds = bounds.merge(Rect2(piece_cell.position, piece_cell.size))
	return bounds


func _update_mouse_filter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _available and _interaction_enabled else Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not _available or not _interaction_enabled or _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(event.global_position, false, -1)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_drag(event.position, true, event.index)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if _touch_drag:
		if event is InputEventScreenDrag and event.index == _touch_index:
			drag_moved.emit(event.position)
		elif event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
			_end_drag(event.position)
	else:
		if event is InputEventMouseMotion:
			drag_moved.emit(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag(event.position)


func _begin_drag(pointer_position: Vector2, is_touch: bool, touch_index: int) -> void:
	_dragging = true
	_touch_drag = is_touch
	_touch_index = touch_index
	drag_started.emit(_definition, pointer_position, is_touch)


func _end_drag(pointer_position: Vector2) -> void:
	_dragging = false
	_touch_drag = false
	_touch_index = -1
	drag_ended.emit(pointer_position)
