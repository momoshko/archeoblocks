class_name PieceTray
extends HBoxContainer

signal drag_started(slot_index: int, definition: PieceDefinition, pointer_position: Vector2, is_touch: bool)
signal drag_moved(slot_index: int, pointer_position: Vector2)
signal drag_ended(slot_index: int, pointer_position: Vector2)

var _slots: Array[PieceSlot] = []


func _ready() -> void:
	for child in get_children():
		if child is PieceSlot:
			var slot_index := _slots.size()
			_slots.append(child)
			child.drag_started.connect(_on_slot_drag_started.bind(slot_index))
			child.drag_moved.connect(_on_slot_drag_moved.bind(slot_index))
			child.drag_ended.connect(_on_slot_drag_ended.bind(slot_index))
	assert(_slots.size() == 3, "PieceTray requires exactly three editor-authored PieceSlot nodes")


func load_set(definitions: Array[PieceDefinition]) -> void:
	assert(definitions.size() == _slots.size(), "PieceTray set must contain exactly three pieces")
	for index in _slots.size():
		_slots[index].set_definition(definitions[index])


func consume_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		_slots[slot_index].set_definition(null)


func is_slot_available(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size() and _slots[slot_index].is_available()


func get_definition(slot_index: int) -> PieceDefinition:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	return _slots[slot_index].get_definition()


func all_empty() -> bool:
	for slot in _slots:
		if slot.is_available():
			return false
	return true


func remaining_definitions() -> Array[PieceDefinition]:
	var definitions: Array[PieceDefinition] = []
	for slot in _slots:
		if slot.is_available():
			definitions.append(slot.get_definition())
	return definitions


func capture_state() -> Array[PieceDefinition]:
	var definitions: Array[PieceDefinition] = []
	for slot in _slots:
		definitions.append(slot.get_definition())
	return definitions


func restore_state(definitions: Array[PieceDefinition]) -> void:
	assert(definitions.size() == _slots.size(), "PieceTray state must contain exactly three slots")
	for index in _slots.size():
		_slots[index].set_definition(definitions[index])


func get_active_slot_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in _slots.size():
		if _slots[index].is_available():
			indices.append(index)
	return indices


func set_hint_slot(slot_index: int) -> void:
	for index in _slots.size():
		_slots[index].set_hint_highlight(index == slot_index)


func clear_hint() -> void:
	for slot in _slots:
		slot.set_hint_highlight(false)


func set_interaction_enabled(enabled: bool) -> void:
	for slot in _slots:
		slot.set_interaction_enabled(enabled)


func cancel_drag() -> void:
	for slot in _slots:
		slot.cancel_drag()


func _on_slot_drag_started(definition: PieceDefinition, pointer_position: Vector2, is_touch: bool, slot_index: int) -> void:
	drag_started.emit(slot_index, definition, pointer_position, is_touch)


func _on_slot_drag_moved(pointer_position: Vector2, slot_index: int) -> void:
	drag_moved.emit(slot_index, pointer_position)


func _on_slot_drag_ended(pointer_position: Vector2, slot_index: int) -> void:
	drag_ended.emit(slot_index, pointer_position)
