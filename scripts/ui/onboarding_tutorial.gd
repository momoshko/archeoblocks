class_name OnboardingTutorial
extends Control

@export var game_session_path: NodePath
@export var tutorial_expedition_id: StringName = &"expedition_01"
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
@onready var tutorial_text: Label = %TutorialText
@onready var continue_button: Button = %ContinueButton
@onready var skip_button: Button = %SkipButton

var _session: GameSession
var _board: BoardView
var _tray: PieceTray
var _placement_index := 0
var _waiting_for_placement := false
var _placement_committed := false
var _pulse_tween: Tween
var _guided_mode := false
var _spotlight_target := SpotlightTarget.NONE

enum SpotlightTarget {
	NONE,
	ARTIFACT,
	TRAY_SLOT,
	PLACEMENT,
}


func _ready() -> void:
	hide()
	set_process(false)
	continue_button.pressed.connect(_on_continue_pressed)
	skip_button.pressed.connect(_finish)
	call_deferred("_setup")


func _process(_delta: float) -> void:
	_refresh_spotlight()


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
	if _session.expedition_definition.artifact_fragments.is_empty():
		_finish()
		return
	_guided_mode = _session.expedition_definition.id == tutorial_expedition_id
	_placement_index = 0
	_waiting_for_placement = false
	_placement_committed = false
	show()
	set_process(true)
	_tray.clear_hint()
	if _guided_mode:
		_session.set_tutorial_placement(required_slots[0], required_origins[0])
		tutorial_text.text = goal_text
		continue_button.text = "Понятно"
	else:
		_session.finish_tutorial()
		tutorial_text.text = "%s\n%s" % [
			_session.expedition_definition.objective_ru,
			_session.expedition_definition.instruction_ru,
		]
		continue_button.text = "Начать"
	continue_button.show()
	_set_spotlight_target(SpotlightTarget.ARTIFACT)


func _on_continue_pressed() -> void:
	if _guided_mode:
		_show_take_step()
	else:
		_finish()


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
	_set_spotlight_target(SpotlightTarget.TRAY_SLOT)


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
	_set_spotlight_target(SpotlightTarget.PLACEMENT)


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
	_set_spotlight_target(SpotlightTarget.ARTIFACT)


func _on_fragment_collected(_fragment_id: StringName) -> void:
	if visible:
		_finish()


func _on_expedition_restarted() -> void:
	_start_if_needed()


func _finish() -> void:
	_spotlight_target = SpotlightTarget.NONE
	set_process(false)
	if _session != null:
		_session.finish_tutorial()
	if _tray != null:
		_tray.clear_hint()
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	hide()


func _set_spotlight_target(target: SpotlightTarget) -> void:
	_spotlight_target = target
	_refresh_spotlight()
	if _pulse_tween != null:
		_pulse_tween.kill()
	spotlight_border.modulate = Color.WHITE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(spotlight_border, "modulate:a", 0.45, 0.45)
	_pulse_tween.tween_property(spotlight_border, "modulate:a", 1.0, 0.45)


func _refresh_spotlight() -> void:
	if not visible or _spotlight_target == SpotlightTarget.NONE:
		return
	var target_rect := Rect2()
	var margin := 4.0
	match _spotlight_target:
		SpotlightTarget.ARTIFACT:
			target_rect = _artifact_target_rect()
		SpotlightTarget.TRAY_SLOT:
			if _placement_index < required_slots.size():
				target_rect = _tray.get_slot_global_rect(required_slots[_placement_index])
			margin = 2.0
		SpotlightTarget.PLACEMENT:
			target_rect = _expected_cells_rect()
	_layout_spotlight(target_rect, margin)


func _artifact_target_rect() -> Rect2:
	for fragment in _session.expedition_definition.artifact_fragments:
		if not _session.excavation_model.is_fragment_collected(fragment.id):
			return _cells_global_rect(fragment.cells)
	return Rect2()


func _expected_cells_rect() -> Rect2:
	var definition := _tray.get_definition(required_slots[_placement_index])
	if definition == null:
		return Rect2()
	return _cells_global_rect(definition.translated_cells(required_origins[_placement_index]))


func _cells_global_rect(cells: Array[Vector2i]) -> Rect2:
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


func _layout_spotlight(target_rect: Rect2, margin: float) -> void:
	if target_rect.size == Vector2.ZERO:
		return
	var viewport_size := get_viewport_rect().size
	var inverse_canvas_transform := get_global_transform_with_canvas().affine_inverse()
	var local_start := inverse_canvas_transform * target_rect.position
	var local_end := inverse_canvas_transform * target_rect.end
	var rect := Rect2(local_start, local_end - local_start).grow(margin)
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
