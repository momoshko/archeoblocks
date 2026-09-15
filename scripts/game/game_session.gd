class_name GameSession
extends Node

const HINT_SPACE_LINE_4: PieceDefinition = preload("res://resources/pieces/line_4_horizontal.tres")
const HINT_SPACE_LARGE_L: PieceDefinition = preload("res://resources/pieces/large_l.tres")
const HINT_SPACE_PLUS_5: PieceDefinition = preload("res://resources/pieces/plus_5.tres")

signal no_moves_reached
signal fragment_collected(fragment_id: StringName)
signal victory_reached
signal score_changed(value: int)
signal help_state_changed
signal piece_placed(slot_index: int, origin: Vector2i)
signal expedition_restarted

@export var expedition_definition: ExpeditionDefinition
@export var chapter_definition: ChapterDefinition
@export var help_config: HelpConfig
@export var score_config: ScoreConfig
@export var economy_config: EconomyConfig
@export var board_view_path: NodePath
@export var piece_tray_path: NodePath
@export var drag_preview_path: NodePath
@export var moves_label_path: NodePath
@export var score_label_path: NodePath
@export var fragment_progress_path: NodePath
@export var expedition_title_path: NodePath
@export var objective_text_path: NodePath
@export var instruction_text_path: NodePath
@export var no_moves_label_path: NodePath
@export var pause_popup_path: NodePath
@export var result_popup_path: NodePath
@export var undo_button_path: NodePath
@export var hint_button_path: NodePath
@export var action_feedback_path: NodePath
@export var artifact_discovery_feedback_path: NodePath
@export var rewarded_action_service_path: NodePath
@export_range(60.0, 100.0, 1.0) var touch_drag_lift := 82.0
@export_range(0.0, 30.0, 1.0) var mouse_drag_lift := 8.0

var board_model := BoardModel.new()
var obstacle_model := ObstacleModel.new()
var excavation_model := ExcavationModel.new()
var piece_sequence := PieceSequence.new()
var help_state := HelpState.new()
var hint_planner := HintPlanner.new()
var moves := 0
var score := 0
var coins_earned := 0

@onready var board_view: BoardView = get_node(board_view_path)
@onready var piece_tray: PieceTray = get_node(piece_tray_path)
@onready var drag_preview: DragPiecePreview = get_node(drag_preview_path)
@onready var moves_label: Label = get_node(moves_label_path)
@onready var score_label: Label = get_node(score_label_path)
@onready var fragment_progress: Label = get_node(fragment_progress_path)
@onready var expedition_title: Label = get_node(expedition_title_path)
@onready var objective_text: Label = get_node(objective_text_path)
@onready var instruction_text: Label = get_node(instruction_text_path)
@onready var no_moves_label: Label = get_node(no_moves_label_path)
@onready var pause_popup: Control = get_node(pause_popup_path)
@onready var result_popup: ResultPopup = get_node(result_popup_path)
@onready var undo_button: Button = get_node(undo_button_path)
@onready var hint_button: Button = get_node(hint_button_path)
@onready var action_feedback: ActionFeedback = get_node(action_feedback_path)
@onready var artifact_discovery_feedback: ArtifactDiscoveryFeedback = get_node(artifact_discovery_feedback_path)
@onready var reward_service: RewardedActionService = get_node(rewarded_action_service_path)

var _active_slot := -1
var _active_definition: PieceDefinition
var _active_is_touch := false
var _active_origin := Vector2i.ZERO
var _active_cells: Array[Vector2i] = []
var _active_is_valid := false
var _input_blocked := false
var _busy := false
var _no_moves := false
var _reward_request_pending := false
var _last_snapshot: TurnSnapshot
var _idle_seconds := 0.0
var _hint_nudge_tween: Tween
var _hint_presentation_tween: Tween
var _victory_bonus_awarded := false
var _root_threat_source := Vector2i(-1, -1)
var _root_threat_cell := Vector2i(-1, -1)
var _web_test_unlimited_hints := false
var _tutorial_active := false
var _tutorial_required_slot := -1
var _tutorial_required_origin := Vector2i(-999, -999)

enum HintCandidatePriority {
	IMMEDIATE_LOSS,
	SHORT_SURVIVES,
	PLAN_SURVIVES,
	IMMEDIATE_VICTORY,
}


func _ready() -> void:
	piece_tray.drag_started.connect(_on_drag_started)
	piece_tray.drag_moved.connect(_on_drag_moved)
	piece_tray.drag_ended.connect(_on_drag_ended)
	undo_button.pressed.connect(request_undo)
	hint_button.pressed.connect(request_hint)
	result_popup.undo_requested.connect(request_undo)
	help_state.changed.connect(_update_help_ui)
	reward_service.reward_granted.connect(_on_reward_granted)
	reward_service.reward_failed.connect(_on_reward_failed)
	restart_expedition()


func _process(delta: float) -> void:
	if not _can_interact() or hint_button.disabled or not _has_any_legal_move():
		_stop_hint_nudge()
		return
	_idle_seconds += delta
	if _idle_seconds >= help_config.idle_hint_seconds:
		_start_hint_nudge()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_web_debug_hint_toggle_allowed(OS.has_feature("web"), OS.is_debug_build()):
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_H
		and event.ctrl_pressed
		and event.alt_pressed
	):
		_web_test_unlimited_hints = not _web_test_unlimited_hints
		action_feedback.show_message(
			"TEST: бесплатные подсказки ВКЛ"
			if _web_test_unlimited_hints
			else "TEST: бесплатные подсказки ВЫКЛ"
		)
		_update_help_ui()
		get_viewport().set_input_as_handled()


static func is_web_debug_hint_toggle_allowed(is_web: bool, is_debug: bool) -> bool:
	return is_web and is_debug


static func should_use_debug_unlimited_hints(
		is_web: bool,
		is_debug: bool,
		configured_unlimited: bool,
		web_runtime_unlimited: bool
) -> bool:
	if not is_debug:
		return false
	if is_web:
		return web_runtime_unlimited
	return configured_unlimited


func restart_expedition() -> bool:
	cancel_active_drag()
	_stop_hint_nudge()
	action_feedback.clear()
	artifact_discovery_feedback.clear()
	result_popup.close_popup()
	board_model.reset()
	obstacle_model.reset()
	board_view.reset_game_state()
	var validation_errors := excavation_model.load_expedition(expedition_definition)
	if not validation_errors.is_empty():
		for error in validation_errors:
			push_error("Invalid ExpeditionDefinition: " + error)
		_input_blocked = true
		piece_tray.set_interaction_enabled(false)
		return false
	var obstacle_errors := obstacle_model.load_expedition(expedition_definition)
	if not obstacle_errors.is_empty():
		for error in obstacle_errors:
			push_error("Invalid obstacle data: " + error)
		_input_blocked = true
		piece_tray.set_interaction_enabled(false)
		return false

	piece_sequence.configure(expedition_definition.curated_piece_sequence)
	if expedition_definition.opening_piece_set.size() == 3:
		piece_tray.load_set(expedition_definition.opening_piece_set)
	else:
		piece_tray.load_set(piece_sequence.next_set())
	help_state.reset(help_config)
	moves = 0
	score = 0
	coins_earned = 0
	_victory_bonus_awarded = false
	_root_threat_source = Vector2i(-1, -1)
	_root_threat_cell = Vector2i(-1, -1)
	_last_snapshot = null
	_busy = false
	_no_moves = false
	_reward_request_pending = false
	_input_blocked = false
	_idle_seconds = 0.0
	_update_moves_label()
	_update_score_label()
	no_moves_label.hide()
	expedition_title.text = expedition_definition.title_ru
	objective_text.text = expedition_definition.objective_ru
	instruction_text.text = expedition_definition.instruction_ru
	_update_fragment_progress()
	_sync_excavation_view()
	_sync_obstacle_view()
	_update_root_threat()
	board_view.play_artifact_targets_intro()
	piece_tray.set_interaction_enabled(true)
	_update_help_ui()
	expedition_restarted.emit()
	return true


func set_input_blocked(blocked: bool) -> void:
	_input_blocked = blocked
	_register_interaction()
	if blocked:
		_prepare_for_modal()
	piece_tray.set_interaction_enabled(not blocked and not _busy and not _no_moves)


func set_tutorial_placement(slot_index: int, origin: Vector2i) -> void:
	_tutorial_active = true
	_tutorial_required_slot = slot_index
	_tutorial_required_origin = origin
	piece_tray.set_required_slot(slot_index)
	piece_tray.set_interaction_enabled(_can_interact())
	_update_help_ui()


func finish_tutorial() -> void:
	_tutorial_active = false
	_tutorial_required_slot = -1
	_tutorial_required_origin = Vector2i(-999, -999)
	piece_tray.clear_required_slot()
	piece_tray.set_interaction_enabled(_can_interact())
	_update_help_ui()


func cancel_active_drag() -> void:
	piece_tray.cancel_drag()
	board_view.clear_placement_preview()
	drag_preview.clear()
	_clear_active_drag()
	_clear_hint_feedback()


func _on_drag_started(slot_index: int, definition: PieceDefinition, pointer_position: Vector2, is_touch: bool) -> void:
	_register_interaction()
	if not _can_interact() or not piece_tray.is_slot_available(slot_index):
		piece_tray.cancel_drag()
		return
	if _tutorial_active and slot_index != _tutorial_required_slot:
		piece_tray.cancel_drag()
		return
	if not obstacle_model.has_legal_placement(board_model, definition.cells):
		_clear_hint_feedback()
		piece_tray.cancel_drag()
		action_feedback.show_message("Нет места для этой фигуры")
		if not _has_any_legal_move():
			evaluate_play_state()
		return
	_active_slot = slot_index
	_active_definition = definition
	_active_is_touch = is_touch
	# Keep the pointer-down drag authoritative while removing informational Hint visuals.
	_clear_hint_feedback()
	drag_preview.show_definition(definition, board_view.get_cell_draw_size(), board_view.get_cell_step())
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
	_active_is_valid = obstacle_model.can_place(board_model, _active_definition.cells, _active_origin)
	if _tutorial_active:
		_active_is_valid = _active_is_valid and _active_origin == _tutorial_required_origin
	var artifact_hit_cells: Array[Vector2i] = []
	if _active_is_valid:
		artifact_hit_cells = _predict_artifact_hit_cells(_active_definition, _active_origin)
	board_view.show_placement_preview(
		_active_cells,
		_active_is_valid,
		_active_definition.cosmetic_color,
		artifact_hit_cells
	)
	drag_preview.set_valid(_active_is_valid)


func _predict_artifact_hit_cells(definition: PieceDefinition, origin: Vector2i) -> Array[Vector2i]:
	var simulated_board := BoardModel.new()
	simulated_board.restore_state(board_model.capture_state())
	var simulated_obstacles := ObstacleModel.new()
	simulated_obstacles.restore_state(obstacle_model.capture_state())
	if not simulated_obstacles.can_place(simulated_board, definition.cells, origin):
		return []
	if simulated_board.place(definition.cells, origin, definition.cosmetic_color).is_empty():
		return []
	var hit_map := ExcavationModel.build_line_hit_map(
		simulated_obstacles.get_full_rows(simulated_board),
		simulated_obstacles.get_full_columns(simulated_board)
	)
	var obstacle_result := simulated_obstacles.apply_hit_map(hit_map)
	var excavation_hit_map: Dictionary = obstacle_result.overflow_hit_map
	var result: Array[Vector2i] = []
	for cell: Vector2i in excavation_hit_map:
		var fragment_id := excavation_model.get_artifact_fragment_id(cell)
		if (
			excavation_model.get_soil_depth(cell) > 0
			and fragment_id != &""
			and not excavation_model.is_fragment_collected(fragment_id)
		):
			result.append(cell)
	return result


func try_place_piece(slot_index: int, origin: Vector2i) -> bool:
	if not _can_interact() or not piece_tray.is_slot_available(slot_index):
		return false
	if _tutorial_active and (slot_index != _tutorial_required_slot or origin != _tutorial_required_origin):
		return false
	var definition := piece_tray.get_definition(slot_index)
	if definition == null or not obstacle_model.can_place(board_model, definition.cells, origin):
		return false
	_last_snapshot = _create_snapshot()
	_commit_placement(slot_index, definition, origin, definition.translated_cells(origin))
	return true


func _commit_placement(slot_index: int, definition: PieceDefinition, origin: Vector2i, target_cells: Array[Vector2i]) -> void:
	_register_interaction()
	_busy = true
	piece_tray.set_interaction_enabled(false)
	var placed_cells := board_model.place(definition.cells, origin, definition.cosmetic_color)
	if placed_cells.is_empty():
		_last_snapshot = null
		_busy = false
		piece_tray.set_interaction_enabled(_can_interact())
		return

	board_view.set_cells_occupied(target_cells, definition.cosmetic_color)
	moves += 1
	_add_score(score_config.successful_placement)
	_update_moves_label()
	piece_placed.emit(slot_index, origin)

	var full_rows := obstacle_model.get_full_rows(board_model)
	var full_columns := obstacle_model.get_full_columns(board_model)
	var line_count := full_rows.size() + full_columns.size()
	var roots_destroyed_this_turn := 0
	if line_count > 0:
		var cleared_cells := board_model.get_line_cells(full_rows, full_columns)
		await board_view.clear_cells_with_feedback(cleared_cells)
		board_model.clear_lines(full_rows, full_columns)
		var line_score := score_config.score_for_lines(line_count)
		_add_score(line_score)
		action_feedback.show_message(_line_feedback_text(line_count, line_score), line_count >= 2)

		var hit_map := ExcavationModel.build_line_hit_map(full_rows, full_columns)
		var obstacle_result := obstacle_model.apply_hit_map(hit_map)
		var destroyed_stones: Array[Vector2i] = obstacle_result.destroyed_stone_cells
		var destroyed_roots: Array[Vector2i] = obstacle_result.destroyed_root_cells
		roots_destroyed_this_turn = destroyed_roots.size()
		if not destroyed_stones.is_empty():
			action_feedback.show_message("ЗАВАЛ РАЗБИТ!", true)
			await board_view.show_stone_hit_feedback(
				obstacle_result.damaged_stone_cells,
				destroyed_stones
			)
		if not destroyed_roots.is_empty():
			action_feedback.show_message("КОРНИ СРЕЗАНЫ!", true)
			await board_view.show_root_hit_feedback(destroyed_roots)
		_sync_obstacle_view()
		var dig_result := excavation_model.apply_hit_map_detailed(obstacle_result.overflow_hit_map)
		var changed_excavation_cells: Array[Vector2i] = dig_result.changed_cells
		_update_excavation_view(changed_excavation_cells, true)
		_add_score(dig_result.hits_applied * score_config.excavation_hit)

		var new_fragments := excavation_model.collect_newly_completed_fragments()
		if not new_fragments.is_empty():
			var fragment_cells: Array[Vector2i] = []
			var fragment_artwork: Array[Texture2D] = []
			for fragment_id in new_fragments:
				fragment_cells.append_array(excavation_model.get_fragment_cells(fragment_id))
				var fragment_texture := expedition_definition.get_fragment_texture(fragment_id)
				if fragment_texture != null:
					fragment_artwork.append(fragment_texture)
				fragment_collected.emit(fragment_id)
			var fragment_score := new_fragments.size() * score_config.new_fragment
			_add_score(fragment_score)
			_update_fragment_progress()
			action_feedback.show_message("ФРАГМЕНТ НАЙДЕН! +%d" % fragment_score, true)
			await board_view.show_fragment_found_feedback(fragment_cells)
			_sync_excavation_view()
			await artifact_discovery_feedback.show_discoveries(
				fragment_artwork,
				expedition_definition.artifact_name_ru
			)

	if excavation_model.all_fragments_complete():
		if not _victory_bonus_awarded:
			_victory_bonus_awarded = true
			_add_score(score_config.complete_artifact)
		coins_earned = economy_config.base_victory_coins
		action_feedback.show_message("НАХОДКА ВОССТАНОВЛЕНА! +%d" % score_config.complete_artifact, true)
		_finish_victory()
		return

	await _resolve_root_growth(roots_destroyed_this_turn > 0)
	piece_tray.consume_slot(slot_index)
	_busy = false
	evaluate_play_state()
	_update_help_ui()


func evaluate_play_state() -> void:
	if piece_tray.all_empty():
		piece_tray.load_set(piece_sequence.next_set())
	var active_definitions := piece_tray.remaining_definitions()
	_no_moves = _is_no_moves_state(board_model, active_definitions, obstacle_model)
	no_moves_label.visible = _no_moves
	if _no_moves:
		_input_blocked = true
		piece_tray.set_interaction_enabled(false)
		_show_rescue_popup()
		no_moves_reached.emit()
	else:
		_input_blocked = false
		piece_tray.set_interaction_enabled(not _busy and not pause_popup.visible)
	_update_help_ui()


func refresh_no_moves_state() -> void:
	evaluate_play_state()


func is_no_moves_state() -> bool:
	return _no_moves


func get_root_threat_source() -> Vector2i:
	return _root_threat_source


func get_root_threat_cell() -> Vector2i:
	return _root_threat_cell


func has_turn_snapshot() -> bool:
	return _last_snapshot != null


func request_undo() -> bool:
	_register_interaction()
	if _last_snapshot == null or _reward_request_pending:
		return false
	if help_state.free_undos_remaining > 0:
		help_state.consume_free_undo()
		_perform_undo()
		return true
	if help_state.rewarded_undos_remaining <= 0 or not reward_service.is_available():
		_update_help_ui()
		return false
	_reward_request_pending = true
	piece_tray.set_interaction_enabled(false)
	var request_id := reward_service.request_reward(RewardedActionService.RewardType.UNDO)
	if request_id < 0:
		_reward_request_pending = false
		_update_help_ui()
		return false
	return true


func request_hint() -> bool:
	_register_interaction()
	var hint := find_best_hint()
	if _no_moves or _reward_request_pending or hint.is_empty():
		_update_help_ui()
		return false
	if is_debug_unlimited_hints_enabled():
		_show_hint(hint)
		_update_help_ui()
		return true
	if help_state.free_hints_remaining > 0:
		help_state.consume_free_hint()
		_show_hint(hint)
		return true
	if help_state.rewarded_hints_remaining <= 0 or not reward_service.is_available():
		_update_help_ui()
		return false
	_reward_request_pending = true
	piece_tray.set_interaction_enabled(false)
	var request_id := reward_service.request_reward(RewardedActionService.RewardType.HINT)
	if request_id < 0:
		_reward_request_pending = false
		_update_help_ui()
		return false
	return true


func find_best_hint() -> Dictionary:
	if _no_moves:
		return {}
	return hint_planner.find_best(self)


func reset_idle_hint_timer() -> void:
	_register_interaction()


func is_hint_nudge_active() -> bool:
	return _hint_nudge_tween != null and _hint_nudge_tween.is_running()


func is_hint_presentation_active() -> bool:
	return _hint_presentation_tween != null and _hint_presentation_tween.is_running()


func is_debug_unlimited_hints_enabled() -> bool:
	return should_use_debug_unlimited_hints(
		OS.has_feature("web"),
		OS.is_debug_build(),
		help_config.debug_unlimited_hints,
		_web_test_unlimited_hints
	)


func _create_snapshot() -> TurnSnapshot:
	var snapshot := TurnSnapshot.new()
	snapshot.board_state = board_model.capture_state()
	snapshot.obstacle_state = obstacle_model.capture_state()
	snapshot.excavation_state = excavation_model.capture_state()
	snapshot.tray_state = piece_tray.capture_state()
	snapshot.sequence_position = piece_sequence.capture_position()
	snapshot.moves = moves
	snapshot.score = score
	snapshot.root_threat_source = _root_threat_source
	snapshot.root_threat_cell = _root_threat_cell
	snapshot.transient_counters = {
		"coins_earned": coins_earned,
		"victory_bonus_awarded": _victory_bonus_awarded,
	}
	return snapshot


func _perform_undo() -> void:
	var snapshot := _last_snapshot
	_last_snapshot = null
	board_model.restore_state(snapshot.board_state)
	obstacle_model.restore_state(snapshot.obstacle_state)
	excavation_model.restore_state(snapshot.excavation_state)
	piece_tray.restore_state(snapshot.tray_state)
	piece_sequence.restore_position(snapshot.sequence_position)
	moves = snapshot.moves
	score = snapshot.score
	_root_threat_source = snapshot.root_threat_source
	_root_threat_cell = snapshot.root_threat_cell
	coins_earned = snapshot.transient_counters.get("coins_earned", 0)
	_victory_bonus_awarded = snapshot.transient_counters.get("victory_bonus_awarded", false)
	_busy = false
	_no_moves = false
	_input_blocked = false
	result_popup.close_popup()
	no_moves_label.hide()
	action_feedback.clear()
	board_view.reset_game_state()
	_sync_excavation_view()
	_sync_board_occupancy_view()
	_sync_obstacle_view()
	_sync_root_warning()
	_update_moves_label()
	_update_score_label()
	_update_fragment_progress()
	piece_tray.set_interaction_enabled(true)
	_update_help_ui()


func _on_reward_granted(_request_id: int, reward_type: int) -> void:
	_reward_request_pending = false
	match reward_type:
		RewardedActionService.RewardType.UNDO:
			if _last_snapshot != null and help_state.consume_rewarded_undo():
				_perform_undo()
		RewardedActionService.RewardType.HINT:
			if not _no_moves and not find_best_hint().is_empty() and help_state.consume_rewarded_hint():
				_show_best_hint()
	piece_tray.set_interaction_enabled(_can_interact())
	_update_help_ui()


func _on_reward_failed(_request_id: int, _reward_type: int) -> void:
	_reward_request_pending = false
	action_feedback.show_message("Награда недоступна")
	piece_tray.set_interaction_enabled(_can_interact())
	_update_help_ui()


func _show_best_hint() -> void:
	var hint := find_best_hint()
	if hint.is_empty():
		return
	_show_hint(hint)


func _show_hint(hint: Dictionary) -> void:
	cancel_active_drag()
	piece_tray.set_hint_slot(hint.slot_index)
	var definition := piece_tray.get_definition(hint.slot_index)
	var artifact_hit_cells: Array[Vector2i] = []
	var hint_color := Color.WHITE
	if definition != null:
		artifact_hit_cells = _predict_artifact_hit_cells(definition, hint.origin)
		hint_color = definition.cosmetic_color
	board_view.show_hint_cells(hint.cells, artifact_hit_cells, hint_color)
	if OS.is_debug_build():
		print(
			"HINT piece=%s origin=%s class=%s victory=%s survives=%s immediate_loss=%s tray_complete=%s depth=%d terminal=%s continuation=%d explored=%d planning_ms=%.2f cache=%s refill=%s fragments=%d artifact_hits=%d artifact_cells=%d excavation_hits=%d obstacle_hits=%d obstacles_destroyed=%d roots_hit=%d roots_destroyed=%d growth_prevented=%s root_grew=%s blocked=%d viability=%d lines=%d value=%d"
			% [
				definition.id if definition != null else &"unknown",
				hint.origin,
				hint.get("safety_class", "UNKNOWN"),
				hint.completes_expedition,
				hint.survives,
				hint.immediate_loss,
				hint.get("current_tray_possible", false),
				hint.get("planning_depth_reached", 1),
				hint.get("predicted_terminal", "unknown"),
				hint.get("best_continuation_value", 0),
				hint.get("explored_states", 0),
				hint.get("planning_time_ms", 0.0),
				hint.get("cache_hit", false),
				hint.used_refill,
				hint.completed_fragments,
				hint.artifact_hits,
				hint.artifact_cells_affected,
				hint.excavation_hits,
				hint.obstacle_hits,
				hint.obstacles_destroyed,
				hint.root_hits,
				hint.roots_destroyed,
				hint.root_growth_prevented,
				hint.root_new_growth,
				hint.blocked_remaining_pieces,
				hint.remaining_legal_moves,
				hint.line_count,
				hint.value,
			]
		)
	_hint_presentation_tween = create_tween()
	_hint_presentation_tween.tween_interval(help_config.hint_display_seconds)
	_hint_presentation_tween.tween_callback(_finish_hint_presentation)


func _finish_hint_presentation() -> void:
	_hint_presentation_tween = null
	piece_tray.clear_hint()
	board_view.clear_hint_cells()


func _evaluate_hint_candidate(slot_index: int, definition: PieceDefinition, origin: Vector2i) -> Dictionary:
	return _simulate_hint_move(_capture_hint_search_state(), slot_index, definition, origin)


func _capture_hint_search_state() -> Dictionary:
	return {
		"board_state": board_model.capture_state(),
		"obstacle_state": obstacle_model.capture_state(),
		"excavation_state": excavation_model.capture_state(),
		"tray_state": piece_tray.capture_state(),
		"sequence_position": piece_sequence.capture_position(),
		"refill_generation": 0,
		"root_threat_source": _root_threat_source,
		"root_threat_cell": _root_threat_cell,
		"victory": false,
		"no_moves": false,
	}


func _enumerate_hint_moves(state: Dictionary, simulation_limit: int = -1) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if state.get("victory", false) or state.get("no_moves", false):
		return results
	var board := BoardModel.new()
	board.restore_state(state.board_state)
	var obstacles := ObstacleModel.new()
	obstacles.restore_state(state.obstacle_state)
	var excavation := ExcavationModel.new()
	excavation.restore_state(state.excavation_state)
	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	var seen_piece_ids: Dictionary = {}
	var specifications: Array[Dictionary] = []
	for slot_index in tray.size():
		var definition := tray[slot_index]
		if definition == null:
			continue
		# Equal definitions in different slots produce gameplay-equivalent successors.
		# Keep the first slot so the visible recommendation remains deterministic.
		if seen_piece_ids.has(definition.id):
			continue
		seen_piece_ids[definition.id] = true
		for y in BoardModel.HEIGHT:
			for x in BoardModel.WIDTH:
				var origin := Vector2i(x, y)
				if not obstacles.can_place(board, definition.cells, origin):
					continue
				specifications.append({
					"slot_index": slot_index,
					"definition": definition,
					"origin": origin,
					"pre_rank": _hint_move_pre_rank(board, obstacles, excavation, definition, origin),
				})
	if simulation_limit >= 0 and specifications.size() > simulation_limit:
		specifications.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			if int(first.pre_rank) != int(second.pre_rank):
				return int(first.pre_rank) > int(second.pre_rank)
			if int(first.slot_index) != int(second.slot_index):
				return int(first.slot_index) < int(second.slot_index)
			var first_origin: Vector2i = first.origin
			var second_origin: Vector2i = second.origin
			return first_origin.y < second_origin.y or (
				first_origin.y == second_origin.y and first_origin.x < second_origin.x
			)
		)
		specifications.resize(simulation_limit)
	for specification in specifications:
		var definition: PieceDefinition = specification.definition
		var slot_index: int = specification.slot_index
		var origin: Vector2i = specification.origin
		var quality := _simulate_hint_move(state, slot_index, definition, origin)
		quality["slot_index"] = slot_index
		quality["origin"] = origin
		quality["cells"] = definition.translated_cells(origin)
		results.append(quality)
	return results


func _hint_move_pre_rank(
	board: BoardModel,
	obstacles: ObstacleModel,
	excavation: ExcavationModel,
	definition: PieceDefinition,
	origin: Vector2i
) -> int:
	var placed_lookup: Dictionary = {}
	var adjacency := 0
	for offset: Vector2i in definition.cells:
		var cell: Vector2i = origin + offset
		placed_lookup[cell] = true
		for direction: Vector2i in ObstacleModel.ROOT_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if board.is_inside(neighbor) and (
				not board.is_empty(neighbor) or obstacles.has_obstacle(neighbor)
			):
				adjacency += 1
	var rows: Array[int] = []
	var columns: Array[int] = []
	for y in BoardModel.HEIGHT:
		var row_full := true
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			if board.is_empty(cell) and not obstacles.has_obstacle(cell) and not placed_lookup.has(cell):
				row_full = false
				break
		if row_full:
			rows.append(y)
	for x in BoardModel.WIDTH:
		var column_full := true
		for y in BoardModel.HEIGHT:
			var cell := Vector2i(x, y)
			if board.is_empty(cell) and not obstacles.has_obstacle(cell) and not placed_lookup.has(cell):
				column_full = false
				break
		if column_full:
			columns.append(x)
	var artifact_hits := 0
	var obstacle_hits := 0
	var hit_map := ExcavationModel.build_line_hit_map(rows, columns)
	for cell: Vector2i in hit_map:
		var incoming_hits: int = hit_map[cell]
		var durability := obstacles.get_durability(cell)
		obstacle_hits += mini(incoming_hits, durability)
		var excavation_hits := maxi(0, incoming_hits - durability)
		var fragment_id := excavation.get_artifact_fragment_id(cell)
		if fragment_id != &"" and not excavation.is_fragment_collected(fragment_id):
			artifact_hits += mini(excavation_hits, excavation.get_soil_depth(cell))
	return artifact_hits * 1000000 + obstacle_hits * 100000 + (rows.size() + columns.size()) * 10000 + adjacency


func _simulate_hint_move(
	state: Dictionary,
	slot_index: int,
	definition: PieceDefinition,
	origin: Vector2i
) -> Dictionary:
	var simulated_board := BoardModel.new()
	simulated_board.restore_state(state.board_state)
	var simulated_obstacles := ObstacleModel.new()
	simulated_obstacles.restore_state(state.obstacle_state)
	var simulated_excavation := ExcavationModel.new()
	simulated_excavation.restore_state(state.excavation_state)
	if definition == null or not simulated_obstacles.can_place(simulated_board, definition.cells, origin):
		return {
			"value": -2147483648,
			"completes_expedition": false,
			"survives": false,
			"immediate_loss": true,
			"invalid": true,
		}

	simulated_board.place(definition.cells, origin, definition.cosmetic_color)
	var rows := simulated_obstacles.get_full_rows(simulated_board)
	var columns := simulated_obstacles.get_full_columns(simulated_board)
	var line_count := rows.size() + columns.size()
	var hit_map := ExcavationModel.build_line_hit_map(rows, columns)
	var obstacle_result := simulated_obstacles.apply_hit_map(hit_map)
	var excavation_hit_map: Dictionary = obstacle_result.overflow_hit_map
	var artifact_cells_affected := 0
	var artifact_excavation_hits := 0
	var artifact_hit_cells: Array[Vector2i] = []
	for cell: Vector2i in excavation_hit_map:
		var soil_depth := simulated_excavation.get_soil_depth(cell)
		var applied_hits := mini(soil_depth, int(excavation_hit_map[cell]))
		if applied_hits <= 0:
			continue
		var fragment_id := simulated_excavation.get_artifact_fragment_id(cell)
		if fragment_id != &"" and not simulated_excavation.is_fragment_collected(fragment_id):
			artifact_cells_affected += 1
			artifact_excavation_hits += applied_hits
			artifact_hit_cells.append(cell)
	var dig_result := simulated_excavation.apply_hit_map_detailed(excavation_hit_map)
	var excavation_hits: int = dig_result.hits_applied
	var general_excavation_hits := excavation_hits - artifact_excavation_hits
	var completed_fragments := simulated_excavation.collect_newly_completed_fragments().size()
	var completes_expedition := simulated_excavation.all_fragments_complete()
	simulated_board.clear_lines(rows, columns)

	var roots_destroyed := int(obstacle_result.roots_destroyed)
	var root_growth_prevented := false
	var root_new_growth := false
	var threat_source: Vector2i = state.get("root_threat_source", Vector2i(-1, -1))
	var threat_cell: Vector2i = state.get("root_threat_cell", Vector2i(-1, -1))
	if (
		not completes_expedition
		and roots_destroyed == 0
		and simulated_obstacles.root_count() > 0
		and _is_valid_board_cell(threat_source)
		and _is_valid_board_cell(threat_cell)
	):
		root_new_growth = simulated_obstacles.grow_root(threat_source, threat_cell, simulated_board)
		root_growth_prevented = not root_new_growth

	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	if slot_index >= 0 and slot_index < tray.size():
		tray[slot_index] = null
	var used_refill := _tray_is_empty(tray)
	var sequence_position := int(state.sequence_position)
	var refill_generation := int(state.get("refill_generation", 0))
	if used_refill and not completes_expedition:
		var refill := _search_refill(sequence_position)
		tray.assign(refill.definitions)
		sequence_position = int(refill.sequence_position)
		refill_generation += 1

	var next_threat_source := Vector2i(-1, -1)
	var next_threat_cell := Vector2i(-1, -1)
	if not completes_expedition:
		var next_threat := simulated_obstacles.find_root_growth_target(simulated_board)
		if not next_threat.is_empty():
			next_threat_source = next_threat.source
			next_threat_cell = next_threat.destination

	var definitions := _active_definitions_from_tray(tray)
	var is_no_moves := (
		not completes_expedition
		and _is_no_moves_state(simulated_board, definitions, simulated_obstacles)
	)
	var survives := not completes_expedition and not is_no_moves
	var immediate_loss := not completes_expedition and is_no_moves
	var remaining_legal_moves := 0
	var blocked_remaining_pieces := 0
	for remaining_definition in definitions:
		var legal_count := simulated_obstacles.count_legal_placements(simulated_board, remaining_definition.cells)
		remaining_legal_moves += legal_count
		if legal_count == 0:
			blocked_remaining_pieces += 1
	var free_cells := BoardModel.WIDTH * BoardModel.HEIGHT - simulated_board.occupied_count() - simulated_obstacles.occupied_count()
	var score_components := {
		"victory": help_config.hint_expedition_victory_bonus if completes_expedition else 0,
		"completed_fragments": completed_fragments * help_config.hint_fragment_completed_weight,
		"artifact_excavation": artifact_excavation_hits * help_config.hint_artifact_excavation_weight,
		"artifact_cells": artifact_cells_affected * help_config.hint_artifact_cell_weight,
		"general_excavation": general_excavation_hits * help_config.hint_excavation_weight,
		"obstacle_damage": int(obstacle_result.stone_hits_applied) * help_config.hint_obstacle_damage_weight,
		"obstacles_destroyed": int(obstacle_result.stones_destroyed) * help_config.hint_obstacle_destroyed_weight,
		"root_damage": int(obstacle_result.root_hits_applied) * help_config.hint_root_damage_weight,
		"roots_destroyed": roots_destroyed * help_config.hint_root_destroyed_weight,
		"root_growth_prevented": help_config.hint_root_growth_prevented_weight if root_growth_prevented else 0,
		"root_new_growth": -help_config.hint_root_new_growth_penalty if root_new_growth else 0,
		"playability": remaining_legal_moves * help_config.hint_remaining_placement_weight,
		"blocked_pieces": -blocked_remaining_pieces * help_config.hint_blocked_piece_penalty,
		"lines": line_count * line_count * help_config.hint_line_weight,
		"free_cells": free_cells * help_config.hint_free_cell_weight,
	}
	var value := 0
	for component_value in score_components.values():
		value += int(component_value)
	var next_state := {
		"board_state": simulated_board.capture_state(),
		"obstacle_state": simulated_obstacles.capture_state(),
		"excavation_state": simulated_excavation.capture_state(),
		"tray_state": tray,
		"sequence_position": sequence_position,
		"refill_generation": refill_generation,
		"root_threat_source": next_threat_source,
		"root_threat_cell": next_threat_cell,
		"victory": completes_expedition,
		"no_moves": is_no_moves,
	}
	return {
		"line_count": line_count,
		"excavation_hits": excavation_hits,
		"obstacle_hits": int(obstacle_result.obstacle_hits_applied),
		"obstacles_destroyed": int(obstacle_result.obstacles_destroyed),
		"root_hits": int(obstacle_result.root_hits_applied),
		"roots_destroyed": roots_destroyed,
		"root_growth_prevented": root_growth_prevented,
		"root_new_growth": root_new_growth,
		"general_excavation_hits": general_excavation_hits,
		"artifact_hits": artifact_excavation_hits,
		"artifact_cells_affected": artifact_cells_affected,
		"artifact_excavation_hits": artifact_excavation_hits,
		"artifact_hit_cells": artifact_hit_cells,
		"completed_fragments": completed_fragments,
		"completes_expedition": completes_expedition,
		"survives": survives,
		"immediate_loss": immediate_loss,
		"used_refill": used_refill,
		"post_move_piece_count": definitions.size(),
		"remaining_legal_moves": remaining_legal_moves,
		"blocked_remaining_pieces": blocked_remaining_pieces,
		"free_cells": free_cells,
		"score_components": score_components,
		"value": value,
		"next_state": next_state,
	}


func _hint_candidate_priority(quality: Dictionary) -> int:
	if quality.get("completes_expedition", false):
		return HintCandidatePriority.IMMEDIATE_VICTORY
	if quality.get("plan_survives", false):
		return HintCandidatePriority.PLAN_SURVIVES
	if quality.get("survives", false):
		return HintCandidatePriority.SHORT_SURVIVES
	return HintCandidatePriority.IMMEDIATE_LOSS


func _search_refill(sequence_position: int) -> Dictionary:
	var simulated_sequence := PieceSequence.new()
	simulated_sequence.configure(expedition_definition.curated_piece_sequence)
	simulated_sequence.restore_position(sequence_position)
	var definitions := simulated_sequence.next_set()
	return {
		"definitions": definitions,
		"sequence_position": simulated_sequence.capture_position(),
	}


func _tray_is_empty(tray: Array[PieceDefinition]) -> bool:
	for definition in tray:
		if definition != null:
			return false
	return true


func _active_definitions_from_tray(tray: Array[PieceDefinition]) -> Array[PieceDefinition]:
	var definitions: Array[PieceDefinition] = []
	for definition in tray:
		if definition != null:
			definitions.append(definition)
	return definitions


func _evaluate_hint_leaf(state: Dictionary) -> int:
	var simulated_board := BoardModel.new()
	simulated_board.restore_state(state.board_state)
	var simulated_obstacles := ObstacleModel.new()
	simulated_obstacles.restore_state(state.obstacle_state)
	var simulated_excavation := ExcavationModel.new()
	simulated_excavation.restore_state(state.excavation_state)
	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	var definitions := _active_definitions_from_tray(tray)

	var legal_placements := 0
	var blocked_pieces := 0
	for definition in definitions:
		var legal_count := simulated_obstacles.count_legal_placements(
			simulated_board,
			definition.cells
		)
		legal_placements += legal_count
		if legal_count == 0:
			blocked_pieces += 1

	var artifact_depth_remaining := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			var fragment_id := simulated_excavation.get_artifact_fragment_id(cell)
			if fragment_id != &"" and not simulated_excavation.is_fragment_collected(fragment_id):
				artifact_depth_remaining += simulated_excavation.get_soil_depth(cell)

	var representative_space := 0
	for representative in [HINT_SPACE_LINE_4, HINT_SPACE_LARGE_L, HINT_SPACE_PLUS_5]:
		if simulated_obstacles.has_legal_placement(simulated_board, representative.cells):
			representative_space += 1
	var free_cells := (
		BoardModel.WIDTH * BoardModel.HEIGHT
		- simulated_board.occupied_count()
		- simulated_obstacles.occupied_count()
	)
	var obstacle_durability := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			obstacle_durability += simulated_obstacles.get_durability(Vector2i(x, y))
	var has_root_threat := (
		_is_valid_board_cell(state.get("root_threat_source", Vector2i(-1, -1)))
		and _is_valid_board_cell(state.get("root_threat_cell", Vector2i(-1, -1)))
	)

	return (
		simulated_excavation.collected_fragment_count()
		* help_config.hint_fragment_completed_weight
		- artifact_depth_remaining * help_config.hint_leaf_artifact_depth_weight
		+ legal_placements * help_config.hint_leaf_legal_placement_weight
		- blocked_pieces * help_config.hint_blocked_piece_penalty
		+ _largest_connected_free_region(simulated_board, simulated_obstacles)
		* help_config.hint_leaf_connected_region_weight
		+ representative_space * help_config.hint_leaf_large_piece_space_weight
		+ free_cells * help_config.hint_free_cell_weight
		- simulated_obstacles.root_count() * help_config.hint_root_damage_weight
		- obstacle_durability * maxi(1, help_config.hint_obstacle_damage_weight / 4)
		- (help_config.hint_root_new_growth_penalty / 2 if has_root_threat else 0)
	)


func _largest_connected_free_region(board: BoardModel, obstacles: ObstacleModel) -> int:
	var visited: Dictionary = {}
	var largest := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var start := Vector2i(x, y)
			if visited.has(start) or not board.is_empty(start) or obstacles.has_obstacle(start):
				continue
			var region_size := 0
			var pending: Array[Vector2i] = [start]
			visited[start] = true
			while not pending.is_empty():
				var cell: Vector2i = pending.pop_back()
				region_size += 1
				for direction: Vector2i in ObstacleModel.ROOT_DIRECTIONS:
					var neighbor: Vector2i = cell + direction
					if (
						board.is_inside(neighbor)
						and not visited.has(neighbor)
						and board.is_empty(neighbor)
						and not obstacles.has_obstacle(neighbor)
					):
						visited[neighbor] = true
						pending.append(neighbor)
			largest = maxi(largest, region_size)
	return largest


func _hint_search_state_key(state: Dictionary) -> String:
	var board_state: Array = state.board_state
	var obstacle_state: Dictionary = state.obstacle_state
	var obstacle_durability: Dictionary = obstacle_state.get("durability_by_cell", {})
	var obstacle_kinds: Dictionary = obstacle_state.get("kind_by_cell", {})
	var excavation_state: Dictionary = state.excavation_state
	var soil_depths: Array = excavation_state.get("soil_depths", [])
	var artifact_owner_by_cell: Dictionary = excavation_state.get("artifact_owner_by_cell", {})
	var parts := PackedStringArray()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			parts.append("1" if board_state[y][x] != null else "0")
			parts.append("%d:%d" % [
				int(obstacle_kinds.get(cell, -1)),
				int(obstacle_durability.get(cell, 0)),
			])
			parts.append(str(soil_depths[y][x]))
			parts.append("a:%s" % str(artifact_owner_by_cell.get(cell, &"")))
	var fragment_state: Dictionary = excavation_state.get("fragment_collected", {})
	var fragment_ids: Array[String] = []
	for fragment_id in fragment_state:
		fragment_ids.append(str(fragment_id))
	fragment_ids.sort()
	for fragment_id in fragment_ids:
		parts.append("f:%s:%d" % [fragment_id, int(bool(fragment_state[StringName(fragment_id)]))])
	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	for definition in tray:
		parts.append("p:%s" % ("-" if definition == null else str(definition.id)))
	parts.append("s:%d" % int(state.sequence_position))
	parts.append("g:%d" % int(state.get("refill_generation", 0)))
	parts.append("rs:%s" % str(state.get("root_threat_source", Vector2i(-1, -1))))
	parts.append("rc:%s" % str(state.get("root_threat_cell", Vector2i(-1, -1))))
	parts.append("v:%d" % int(bool(state.get("victory", false))))
	parts.append("n:%d" % int(bool(state.get("no_moves", false))))
	return "|".join(parts)


func debug_apply_hint_for_validation(hint: Dictionary) -> Dictionary:
	# This mutating shortcut exists only for deterministic headless campaign validation.
	# Production builds must use the normal drag/placement path.
	if not OS.is_debug_build() or hint.is_empty():
		return {}
	var slot_index := int(hint.get("slot_index", -1))
	var definition := piece_tray.get_definition(slot_index)
	if definition == null:
		return {}
	var result := _simulate_hint_move(
		_capture_hint_search_state(),
		slot_index,
		definition,
		hint.get("origin", Vector2i(-1, -1))
	)
	if result.get("invalid", false):
		return {}
	var state: Dictionary = result.next_state
	board_model.restore_state(state.board_state)
	obstacle_model.restore_state(state.obstacle_state)
	excavation_model.restore_state(state.excavation_state)
	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	piece_tray.restore_state(tray)
	piece_sequence.restore_position(int(state.sequence_position))
	_root_threat_source = state.root_threat_source
	_root_threat_cell = state.root_threat_cell
	moves += 1
	_no_moves = bool(state.no_moves)
	_input_blocked = _no_moves or bool(state.victory)
	_busy = false
	_clear_hint_feedback()
	board_view.reset_game_state()
	_sync_excavation_view()
	_sync_board_occupancy_view()
	_sync_obstacle_view()
	_sync_root_warning()
	_update_moves_label()
	_update_fragment_progress()
	no_moves_label.visible = _no_moves
	piece_tray.set_interaction_enabled(not _input_blocked)
	_update_help_ui()
	return result


func _is_no_moves_state(
	model: BoardModel,
	definitions: Array[PieceDefinition],
	obstacles: ObstacleModel = null
) -> bool:
	return not definitions.is_empty() and not _has_legal_move(model, definitions, obstacles)


func _has_legal_move(
	model: BoardModel,
	definitions: Array[PieceDefinition],
	obstacles: ObstacleModel = null
) -> bool:
	var active_obstacles := obstacles if obstacles != null else obstacle_model
	for definition in definitions:
		if active_obstacles.has_legal_placement(model, definition.cells):
			return true
	return false


func _has_any_legal_move() -> bool:
	return _has_legal_move(board_model, piece_tray.remaining_definitions(), obstacle_model)


func _show_rescue_popup() -> void:
	_prepare_for_modal()
	result_popup.show_rescue(
		_fragment_progress_text(),
		_last_snapshot != null and help_state.free_undos_remaining > 0,
		_last_snapshot != null and help_state.rewarded_undos_remaining > 0,
		reward_service.is_available()
	)


func _update_help_ui() -> void:
	var has_snapshot := _last_snapshot != null
	if has_snapshot and help_state.free_undos_remaining > 0:
		undo_button.text = "Отменить · %d" % help_state.free_undos_remaining
		undo_button.disabled = false
	elif has_snapshot and help_state.rewarded_undos_remaining > 0 and reward_service.is_available():
		undo_button.text = "Отменить 🎬"
		undo_button.disabled = false
	else:
		undo_button.text = "Отмена недоступна"
		undo_button.disabled = true

	var has_legal_hint := not _no_moves and _has_any_legal_move()
	if has_legal_hint and is_debug_unlimited_hints_enabled():
		hint_button.text = "Подсказка ∞ · DEBUG"
		hint_button.disabled = false
	elif has_legal_hint and help_state.free_hints_remaining > 0:
		hint_button.text = "Подсказка · %d" % help_state.free_hints_remaining
		hint_button.disabled = false
	elif has_legal_hint and help_state.rewarded_hints_remaining > 0 and reward_service.is_available():
		hint_button.text = "Подсказка 🎬"
		hint_button.disabled = false
	elif has_legal_hint:
		hint_button.text = "Подсказки закончились"
		hint_button.disabled = true
	else:
		hint_button.text = "Подсказка недоступна"
		hint_button.disabled = true
	if _tutorial_active:
		undo_button.text = "Следуйте обучению"
		undo_button.disabled = true
		hint_button.text = "Следуйте обучению"
		hint_button.disabled = true

	if _no_moves and result_popup.visible:
		result_popup.update_rescue_undo(
			has_snapshot and help_state.free_undos_remaining > 0,
			has_snapshot and help_state.rewarded_undos_remaining > 0,
			reward_service.is_available()
		)
	help_state_changed.emit()


func _add_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	_update_score_label()
	score_changed.emit(score)


func _update_moves_label() -> void:
	moves_label.text = "Ходы: %d" % moves


func _update_score_label() -> void:
	score_label.text = "Счёт: %d" % score


func _fragment_progress_text() -> String:
	return "Фрагменты: %d / %d" % [
		excavation_model.collected_fragment_count(),
		excavation_model.fragment_count(),
	]


func _update_fragment_progress() -> void:
	fragment_progress.text = _fragment_progress_text()


func _sync_excavation_view() -> void:
	var emphasize_remaining := excavation_model.collected_fragment_count() > 0
	for y in ExcavationModel.HEIGHT:
		for x in ExcavationModel.WIDTH:
			var cell := Vector2i(x, y)
			var fragment_id := excavation_model.get_artifact_fragment_id(cell)
			board_view.set_excavation_cell(
				cell,
				excavation_model.get_soil_depth(cell),
				fragment_id != &"",
				excavation_model.is_fragment_collected(fragment_id),
				emphasize_remaining,
				false
			)


func _sync_board_occupancy_view() -> void:
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			var cell := Vector2i(x, y)
			var value: Variant = board_model.get_value(cell)
			if value != null:
				var color: Color = value if typeof(value) == TYPE_COLOR else Color(0.176, 0.514, 0.31)
				board_view.set_cells_occupied([cell], color)


func _sync_obstacle_view() -> void:
	for y in ObstacleModel.HEIGHT:
		for x in ObstacleModel.WIDTH:
			var cell := Vector2i(x, y)
			if obstacle_model.is_stone(cell):
				board_view.clear_root_obstacle(cell)
				var durability := obstacle_model.get_durability(cell)
				board_view.set_stone_obstacle(cell, durability)
			elif obstacle_model.is_root(cell):
				board_view.clear_stone_obstacle(cell)
				board_view.set_root_obstacle(cell)
			else:
				board_view.clear_stone_obstacle(cell)
				board_view.clear_root_obstacle(cell)


func _resolve_root_growth(root_destroyed_this_turn: bool) -> bool:
	board_view.clear_root_growth_warning()
	var grew := false
	if (
		not root_destroyed_this_turn
		and obstacle_model.root_count() > 0
		and _is_valid_board_cell(_root_threat_source)
		and _is_valid_board_cell(_root_threat_cell)
	):
		grew = obstacle_model.grow_root(
			_root_threat_source,
			_root_threat_cell,
			board_model
		)
		if grew:
			await board_view.show_root_growth_feedback(_root_threat_source, _root_threat_cell)
	_sync_obstacle_view()
	_update_root_threat()
	return grew


func _update_root_threat() -> void:
	var threat := obstacle_model.find_root_growth_target(board_model)
	if threat.is_empty():
		_root_threat_source = Vector2i(-1, -1)
		_root_threat_cell = Vector2i(-1, -1)
	else:
		_root_threat_source = threat.source
		_root_threat_cell = threat.destination
	_sync_root_warning()


func _sync_root_warning() -> void:
	board_view.clear_root_growth_warning()
	if _is_valid_board_cell(_root_threat_cell):
		board_view.show_root_growth_warning(_root_threat_cell)


func _is_valid_board_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BoardModel.WIDTH and cell.y >= 0 and cell.y < BoardModel.HEIGHT


func _update_excavation_view(cells: Array[Vector2i], show_feedback: bool) -> void:
	var emphasize_remaining := excavation_model.collected_fragment_count() > 0
	for cell in cells:
		var fragment_id := excavation_model.get_artifact_fragment_id(cell)
		board_view.set_excavation_cell(
			cell,
			excavation_model.get_soil_depth(cell),
			fragment_id != &"",
			excavation_model.is_fragment_collected(fragment_id),
			emphasize_remaining,
			show_feedback
		)


func _finish_victory() -> void:
	_busy = false
	_no_moves = false
	_input_blocked = true
	no_moves_label.hide()
	piece_tray.set_interaction_enabled(false)
	_prepare_for_modal()
	var progress_error := ProgressStore.mark_expedition_completed(expedition_definition.id)
	if progress_error != OK:
		push_warning("Could not save expedition progress: %s" % error_string(progress_error))
	var chapter_info: Dictionary = {}
	if (
		progress_error == OK
		and chapter_definition != null
		and chapter_definition.is_finale(expedition_definition.id)
	):
		var chapter_ids := chapter_definition.expedition_ids()
		var chapter_complete := true
		for expedition_id in chapter_ids:
			if not ProgressStore.is_expedition_completed(expedition_id):
				chapter_complete = false
				break
		if chapter_complete:
			var reward_result := ProgressStore.claim_chapter_reward(
				chapter_definition.id,
				chapter_ids,
				chapter_definition.completion_reward_coins
			)
			if reward_result.error != OK:
				push_warning("Could not save chapter reward: %s" % error_string(reward_result.error))
			chapter_info = {
				"complete": true,
				"title": chapter_definition.title_ru,
				"completion_title": chapter_definition.completion_title_ru,
				"collected": chapter_ids.size(),
				"total": chapter_ids.size(),
				"reward_coins": chapter_definition.completion_reward_coins,
				"reward_granted": bool(reward_result.granted),
				"reward_error": int(reward_result.error),
			}
	result_popup.show_victory(
		expedition_definition.artifact_name_ru,
		score,
		coins_earned,
		expedition_definition.full_artifact_texture,
		chapter_info
	)
	victory_reached.emit()
	_update_help_ui()


func _prepare_for_modal() -> void:
	cancel_active_drag()
	action_feedback.clear()
	artifact_discovery_feedback.clear()
	board_view.clear_transient_feedback()


func _line_feedback_text(line_count: int, points: int) -> String:
	if line_count == 1:
		return "ЛИНИЯ! +%d" % points
	return "%d ЛИНИИ! +%d" % [line_count, points]


func _register_interaction() -> void:
	_idle_seconds = 0.0
	_stop_hint_nudge()


func _start_hint_nudge() -> void:
	if _hint_nudge_tween != null and _hint_nudge_tween.is_running():
		return
	_hint_nudge_tween = create_tween().set_loops()
	_hint_nudge_tween.tween_property(hint_button, "modulate", Color(1.0, 0.9, 0.55, 0.72), 0.65)
	_hint_nudge_tween.tween_property(hint_button, "modulate", Color.WHITE, 0.65)


func _stop_hint_nudge() -> void:
	if _hint_nudge_tween != null:
		_hint_nudge_tween.kill()
		_hint_nudge_tween = null
	if is_instance_valid(hint_button):
		hint_button.modulate = Color.WHITE


func _clear_hint_feedback() -> void:
	if _hint_presentation_tween != null:
		_hint_presentation_tween.kill()
		_hint_presentation_tween = null
	piece_tray.clear_hint()
	board_view.clear_hint_cells()


func _can_interact() -> bool:
	return (
		not _input_blocked
		and not _busy
		and not _no_moves
		and not _reward_request_pending
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
