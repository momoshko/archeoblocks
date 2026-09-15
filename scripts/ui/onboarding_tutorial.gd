class_name OnboardingTutorial
extends Control

@export var game_session_path: NodePath
@export var artifact_cell := Vector2i(3, 3)
@export var required_slots := PackedInt32Array([0, 1, 2])
@export var required_origins: Array[Vector2i] = [
	Vector2i(0, 3),
	Vector2i(3, 3),
	Vector2i(6, 3),
]
@export_multiline var goal_text := "Главная цель — раскопать артефакт.\nГотовые линии снимают грунт."
@export var take_texts := PackedStringArray([
	"Возьми подсвеченную фигуру.",
	"Теперь возьми вторую фигуру.",
	"Осталось закрыть линию этой фигурой.",
])
@export var place_texts := PackedStringArray([
	"Поставь её в начало строки.",
	"Продолжи заполнять ту же строку.",
	"Заполни последние клетки строки.",
])
@export_multiline var excavation_text := "Отлично! Линия снимает грунт\nи открывает спрятанную находку."

@onready var dim_top: ColorRect = %DimTop
@onready var dim_bottom: ColorRect = %DimBottom
@onready var dim_left: ColorRect = %DimLeft
@onready var dim_right: ColorRect = %DimRight
@onready var spotlight_border: Panel = %SpotlightBorder
@onready var pointer: Label = %Pointer
@onready var tutorial_text: Label = %TutorialText
@onready var continue_button: Button = %ContinueButton

var _session: GameSession
var _board: BoardView
var _tray: PieceTray
var _placement_index := 0
var _waiting_for_placement := false
var _placement_committed := false
var _pulse_tween: Tween


func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue_pressed)
	call_deferred("_setup")


func _setup() -> void:
	_session = get_node_or_null(game_session_path) as GameSession
	if _session == null:
		push_error("OnboardingTutorial requires a GameSession")
		return
	_board = _session.board_view
	_tray = _session.piece_tray
	_session.piece_placed.connect(_on_piece_placed)
	_session.fragment_collected.connect(_on_fragment_collected)
	_session.expedition_restarted.connect(_on_expedition_restarted)
	_tray.drag_started.connect(_on_drag_started)
	_tray.drag_ended.connect(_on_drag_ended)
	_start_if_needed()


func _start_if_needed() -> void:
	if ProgressStore.is_expedition_completed(_session.expedition_definition.id):
		_finish()
		return
	_placement_index = 0
	_waiting_for_placement = false
	_placement_committed = false
	show()
	_session.set_tutorial_placement(required_slots[0], required_origins[0])
	_tray.clear_hint()
	tutorial_text.text = goal_text
	continue_button.show()
	_show_spotlight(_board.get_cell_view(artifact_cell).get_global_rect())


func _on_continue_pressed() -> void:
	_show_take_step()


func _show_take_step() -> void:
	if _placement_index >= required_slots.size() or _placement_index >= required_origins.size():
		return
	_waiting_for_placement = false
	_placement_committed = false
	var slot_index := required_slots[_placement_index]
	_session.set_tutorial_placement(slot_index, required_origins[_placement_index])
	_tray.set_hint_slot(slot_index)
	tutorial_text.text = take_texts[_placement_index]
	continue_button.hide()
	_show_spotlight(_tray.get_slot_global_rect(slot_index))


func _on_drag_started(
	slot_index: int,
	_definition: PieceDefinition,
	_pointer_position: Vector2,
	_is_touch: bool
) -> void:
	if not visible or _placement_index >= required_slots.size():
		return
	if slot_index != required_slots[_placement_index]:
		return
	_waiting_for_placement = true
	_placement_committed = false
	_tray.clear_hint()
	tutorial_text.text = place_texts[_placement_index]
	_show_spotlight(_expected_cells_rect())


func _on_drag_ended(slot_index: int, _pointer_position: Vector2) -> void:
	if not visible or not _waiting_for_placement:
		return
	if slot_index != required_slots[_placement_index]:
		return
	var attempted_index := _placement_index
	call_deferred("_restore_take_step_if_needed", attempted_index)


func _restore_take_step_if_needed(attempted_index: int) -> void:
	await get_tree().process_frame
	if (
		visible
		and _placement_index == attempted_index
		and _waiting_for_placement
		and not _placement_committed
	):
		_show_take_step()


func _on_piece_placed(slot_index: int, origin: Vector2i) -> void:
	if not visible or _placement_index >= required_slots.size():
		return
	if slot_index != required_slots[_placement_index] or origin != required_origins[_placement_index]:
		return
	_placement_committed = true
	_waiting_for_placement = false
	_placement_index += 1
	if _placement_index < required_slots.size():
		_show_take_step()
	else:
		_show_excavation_step()


func _show_excavation_step() -> void:
	_tray.clear_hint()
	tutorial_text.text = excavation_text
	continue_button.hide()
	_show_spotlight(_board.get_cell_view(artifact_cell).get_global_rect())


func _on_fragment_collected(_fragment_id: StringName) -> void:
	if visible:
		_finish()


func _on_expedition_restarted() -> void:
	_start_if_needed()


func _finish() -> void:
	if _session != null:
		_session.finish_tutorial()
	if _tray != null:
		_tray.clear_hint()
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	hide()


func _expected_cells_rect() -> Rect2:
	var definition := _tray.get_definition(required_slots[_placement_index])
	if definition == null:
		return Rect2()
	var cells := definition.translated_cells(required_origins[_placement_index])
	var result := Rect2()
	var has_rect := false
	for cell in cells:
		var cell_view := _board.get_cell_view(cell)
		if cell_view == null:
			continue
		var cell_rect := cell_view.get_global_rect()
		result = cell_rect if not has_rect else result.merge(cell_rect)
		has_rect = true
	return result


func _show_spotlight(target_rect: Rect2) -> void:
	if target_rect.size == Vector2.ZERO:
		return
	var viewport_size := get_viewport_rect().size
	var rect := target_rect.grow(12.0)
	rect.position.x = clampf(rect.position.x, 0.0, viewport_size.x)
	rect.position.y = clampf(rect.position.y, 0.0, viewport_size.y)
	rect.size.x = minf(rect.size.x, viewport_size.x - rect.position.x)
	rect.size.y = minf(rect.size.y, viewport_size.y - rect.position.y)

	dim_top.position = Vector2.ZERO
	dim_top.size = Vector2(viewport_size.x, rect.position.y)
	dim_bottom.position = Vector2(0.0, rect.end.y)
	dim_bottom.size = Vector2(viewport_size.x, maxf(0.0, viewport_size.y - rect.end.y))
	dim_left.position = Vector2(0.0, rect.position.y)
	dim_left.size = Vector2(rect.position.x, rect.size.y)
	dim_right.position = Vector2(rect.end.x, rect.position.y)
	dim_right.size = Vector2(maxf(0.0, viewport_size.x - rect.end.x), rect.size.y)
	spotlight_border.position = rect.position
	spotlight_border.size = rect.size
	pointer.position = Vector2(rect.get_center().x - 24.0, maxf(4.0, rect.position.y - 58.0))

	if _pulse_tween != null:
		_pulse_tween.kill()
	spotlight_border.modulate = Color.WHITE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(spotlight_border, "modulate:a", 0.45, 0.45)
	_pulse_tween.tween_property(spotlight_border, "modulate:a", 1.0, 0.45)
