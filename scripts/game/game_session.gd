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
signal turn_undone
## Presentation cue for sound/haptics: kind is a short name such as &"place",
## strength carries a count where it matters (lines cleared).
signal feedback_event(kind: StringName, strength: int)
## Endless Excavation: the run ended (no piece fits). Keys: score, depth, lines,
## best_streak, best_score, best_depth, new_score_record, new_depth_record.
signal endless_run_finished(result: Dictionary)
## Endless Excavation: the dig went one metre deeper.
signal depth_changed(depth: int)

@export var expedition_definition: ExpeditionDefinition
@export var chapter_definition: ChapterDefinition
## Set only on the Endless Excavation screen: no victory, the run lasts until no
## piece fits; Undo and Hint are off. expedition_definition stays empty there.
@export var endless_definition: EndlessDefinition
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
## Endless HUD (optional; only the endless screen has these labels).
@export var record_label_path: NodePath
@export var depth_label_path: NodePath
@export var streak_label_path: NodePath
@export var finds_label_path: NodePath
@export_range(60.0, 100.0, 1.0) var touch_drag_lift := 82.0
@export_range(0.0, 30.0, 1.0) var mouse_drag_lift := 8.0

var board_model := BoardModel.new()
var obstacle_model := ObstacleModel.new()
var excavation_model := ExcavationModel.new()
var piece_sequence := PieceSequence.new()
var help_state := HelpState.new()
var hint_planner := HintPlanner.new()
## The next Hint is planned in the background after every move, a few ms per
## frame, so pressing Hint is instant and the game never stalls (a full plan is
## ~0.5 s of work; Web builds have no threads). Tests may switch it off.
var prefetch_hints := true
var _hint_prefetch_planner := HintPlanner.new()
var _hint_prefetch_running := false
var _hint_prefetch_dirty := true
var _hint_waiting_for_plan := false
var moves := 0
var score := 0
## Difficulty.Level of the current campaign attempt.
var difficulty := 1
## Hard: moves allowed on this level (0 = no limit).
var move_limit := 0
var _out_of_moves := false
var coins_earned := 0
## Endless Excavation run state.
var streak := StreakTracker.new()
var total_lines := 0
var depth := 0
## Tests set this to replay a known run; 0 = a new random seed every run.
var endless_seed_override := 0
## Campaign: every attempt gets new pieces (the map stays hand-made). Headless
## runs (tests, the difficulty probe) keep the expedition's own seed so results
## repeat; set this to force either way.
static var random_campaign_pieces := DisplayServer.get_name() != "headless"
## Tests set this to replay a known attempt; 0 = decided by random_campaign_pieces.
var campaign_seed_override := 0
var _attempt_seed := 0

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
@onready var record_label: Label = get_node_or_null(record_label_path) as Label
@onready var depth_label: Label = get_node_or_null(depth_label_path) as Label
@onready var streak_label: Label = get_node_or_null(streak_label_path) as Label
@onready var finds_label: Label = get_node_or_null(finds_label_path) as Label

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
# Incremented by restart and undo. A turn that resumes after an animation await
# stops when the generation changed, so it never mutates a newer board state.
var _turn_generation := 0
var _layer_index := 0
var _endless_seed := 0
var _best_score_at_start := 0
var _record_announced := false
var _last_endless_result: Dictionary = {}
## Endless events: dig spots with finds, stones/roots by depth, Daily Dig.
var endless_events := EndlessEvents.new()
## Set by the endless screen before restart: the Daily Dig (shared pieces, a find goal).
var daily_mode := false
## Tests set a date key ("YYYY-MM-DD"); empty = today on this device.
var daily_date_override := ""
var _daily_key := ""
var _daily_goal_announced := false

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
	hint_button.pressed.connect(_on_hint_button_pressed)
	result_popup.undo_requested.connect(request_undo)
	help_state.changed.connect(_update_help_ui)
	reward_service.reward_granted.connect(_on_reward_granted)
	reward_service.reward_failed.connect(_on_reward_failed)
	restart_expedition()


func _process(delta: float) -> void:
	if is_endless():
		return
	if (
		_hint_prefetch_dirty
		and prefetch_hints
		and not _hint_prefetch_running
		and not _no_moves
		and not hint_button.disabled
		and _can_interact()
	):
		_hint_prefetch_dirty = false
		_prefetch_hint()
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


func is_endless() -> bool:
	return endless_definition != null


func restart_expedition() -> bool:
	_turn_generation += 1
	cancel_active_drag()
	_stop_hint_nudge()
	action_feedback.clear()
	artifact_discovery_feedback.clear()
	result_popup.close_popup()
	board_model.reset()
	obstacle_model.reset()
	board_view.reset_game_state()
	if is_endless():
		return _restart_endless()
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

	difficulty = Difficulty.current()
	Difficulty.apply_to_models(excavation_model, obstacle_model, difficulty)
	move_limit = Difficulty.move_limit(expedition_definition, difficulty)
	_attempt_seed = _campaign_attempt_seed()
	var opening: Array[PieceDefinition] = []
	opening.assign(expedition_definition.opening_piece_set)
	var curated: Array[PieceDefinition] = []
	curated.assign(expedition_definition.curated_piece_sequence)
	if _attempt_seed != expedition_definition.resolved_piece_seed():
		_shuffle_scripted_pieces(opening, curated, _attempt_seed)
	piece_sequence.configure(
		curated,
		Difficulty.piece_generation_for(expedition_definition.piece_generation, difficulty),
		_attempt_seed
	)
	if opening.size() == 3:
		piece_tray.load_set(opening)
	else:
		piece_tray.load_set(piece_sequence.next_set(board_model, obstacle_model))
	help_state.reset(Difficulty.help_config_for(help_config, difficulty))
	moves = 0
	score = 0
	coins_earned = 0
	_victory_bonus_awarded = false
	_root_threat_source = Vector2i(-1, -1)
	_root_threat_cell = Vector2i(-1, -1)
	_last_snapshot = null
	_busy = false
	_no_moves = false
	_out_of_moves = false
	_reward_request_pending = false
	_input_blocked = false
	_idle_seconds = 0.0
	_update_moves_label()
	_update_score_label()
	no_moves_label.hide()
	expedition_title.text = short_title(tr(expedition_definition.title_ru))
	expedition_title.tooltip_text = tr(expedition_definition.title_ru)
	objective_text.text = tr(expedition_definition.objective_ru)
	instruction_text.text = tr(expedition_definition.instruction_ru)
	_update_fragment_progress()
	_sync_excavation_view()
	_sync_obstacle_view()
	_update_root_threat()
	board_view.play_artifact_targets_intro()
	piece_tray.set_interaction_enabled(true)
	_update_help_ui()
	_on_hint_state_changed()
	expedition_restarted.emit()
	return true


func _restart_endless() -> bool:
	excavation_model.reset()
	var errors := endless_definition.validate()
	if not errors.is_empty():
		for error in errors:
			push_error("Invalid EndlessDefinition: " + error)
		_input_blocked = true
		piece_tray.set_interaction_enabled(false)
		return false
	_daily_key = daily_date_override if not daily_date_override.is_empty() else ProgressStore.date_key(Time.get_date_dict_from_system())
	if daily_mode:
		_endless_seed = EndlessDefinition.daily_seed(_daily_key)
	else:
		_endless_seed = endless_seed_override if endless_seed_override != 0 else int(randi() | 1)
	_daily_goal_announced = false
	obstacle_model.reset()
	board_view.clear_countdowns()
	endless_events.reset(endless_definition, _endless_seed, daily_mode, _collection_finds())
	_layer_index = 0
	total_lines = 0
	depth = 0
	streak.configure(
		endless_definition.streak_grace_moves,
		endless_definition.streak_step,
		endless_definition.streak_max_multiplier
	)
	_best_score_at_start = ProgressStore.get_endless_best_score()
	_record_announced = false
	_last_endless_result = {}
	piece_sequence.configure([], endless_definition.layers[0].piece_generation, _endless_seed)
	piece_tray.load_set(piece_sequence.next_set(board_model, obstacle_model))
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
	_out_of_moves = false
	_reward_request_pending = false
	_input_blocked = false
	_idle_seconds = 0.0
	_update_moves_label()
	_update_score_label()
	no_moves_label.hide()
	expedition_title.text = tr("Раскоп дня") if daily_mode else tr(endless_definition.title_ru)
	objective_text.text = (
		tr("Откопайте %d находки: они появляются под грунтом после линий") % endless_definition.daily_goal_finds
		if daily_mode
		else tr(endless_definition.instruction_ru)
	)
	instruction_text.text = ""
	fragment_progress.text = ""
	_update_endless_hud()
	_sync_excavation_view()
	_sync_obstacle_view()
	_sync_root_warning()
	piece_tray.set_interaction_enabled(true)
	_update_help_ui()
	_on_hint_state_changed()
	expedition_restarted.emit()
	return true


func get_endless_seed() -> int:
	return _endless_seed


func get_last_endless_result() -> Dictionary:
	return _last_endless_result


func is_input_blocked() -> bool:
	return _input_blocked


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
		action_feedback.show_message(tr("Нет места для этой фигуры"))
		feedback_event.emit(&"invalid", 0)
		if not _has_any_legal_move():
			evaluate_play_state()
		return
	_active_slot = slot_index
	_active_definition = definition
	_active_is_touch = is_touch
	# Keep the pointer-down drag authoritative while removing informational Hint visuals.
	_clear_hint_feedback()
	drag_preview.show_definition(definition, board_view.get_cell_draw_size(), board_view.get_cell_step())
	feedback_event.emit(&"pick", 0)
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
	var dropped_on_board := false
	for cell in _active_cells:
		if board_model.is_inside(cell):
			dropped_on_board = true
			break
	board_view.clear_placement_preview()
	drag_preview.clear()
	_clear_active_drag()
	if is_valid:
		try_place_piece(slot_index, origin)
	elif dropped_on_board:
		feedback_event.emit(&"invalid", 0)


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


static func _cells_centre(cells: Array[Vector2i]) -> Vector2:
	var centre := Vector2.ZERO
	for cell in cells:
		centre += Vector2(cell)
	return centre / maxf(1.0, float(cells.size()))


func _commit_placement(slot_index: int, definition: PieceDefinition, origin: Vector2i, target_cells: Array[Vector2i]) -> void:
	_register_interaction()
	var generation := _turn_generation
	_busy = true
	piece_tray.set_interaction_enabled(false)
	_update_help_ui()
	var placed_cells := board_model.place(definition.cells, origin, definition.cosmetic_color)
	if placed_cells.is_empty():
		_last_snapshot = null
		_busy = false
		piece_tray.set_interaction_enabled(_can_interact())
		return

	board_view.set_cells_occupied(target_cells, definition.cosmetic_color)
	board_view.play_landing(target_cells)
	feedback_event.emit(&"place", 0)
	moves += 1
	_add_score(score_config.successful_placement)
	_update_moves_label()
	_on_hint_state_changed()
	piece_placed.emit(slot_index, origin)

	var full_rows := obstacle_model.get_full_rows(board_model)
	var full_columns := obstacle_model.get_full_columns(board_model)
	var line_count := full_rows.size() + full_columns.size()
	var roots_destroyed_this_turn := 0
	var streak_multiplier := 1.0
	if is_endless():
		streak_multiplier = streak.register_move(line_count)
	if line_count > 0:
		var cleared_cells := board_model.get_line_cells(full_rows, full_columns)
		feedback_event.emit(&"line_clear", line_count)
		await board_view.clear_cells_with_feedback(cleared_cells, _cells_centre(target_cells))
		if generation != _turn_generation:
			return
		board_model.clear_lines(full_rows, full_columns)
		var line_score := roundi(score_config.score_for_lines(line_count) * streak_multiplier)
		_add_score(line_score)
		if streak_multiplier > 1.0:
			action_feedback.show_message(
				tr("СЕРИЯ %s! +%d") % [_format_multiplier(streak_multiplier), line_score], true
			)
			feedback_event.emit(&"streak", streak.streak)
		else:
			action_feedback.show_message(_line_feedback_text(line_count, line_score), line_count >= 2)
		if is_endless():
			_advance_endless_depth(line_count, streak_multiplier)

		var hit_map := ExcavationModel.build_line_hit_map(full_rows, full_columns)
		var obstacle_result := obstacle_model.apply_hit_map(hit_map)
		var destroyed_stones: Array[Vector2i] = obstacle_result.destroyed_stone_cells
		var destroyed_roots: Array[Vector2i] = obstacle_result.destroyed_root_cells
		roots_destroyed_this_turn = destroyed_roots.size()
		var damaged_stones: Array[Vector2i] = obstacle_result.damaged_stone_cells
		if not destroyed_stones.is_empty():
			feedback_event.emit(&"stone_break", destroyed_stones.size())
		elif not damaged_stones.is_empty():
			feedback_event.emit(&"stone_hit", damaged_stones.size())
		if not destroyed_stones.is_empty():
			action_feedback.show_message(tr("ЗАВАЛ РАЗБИТ!"), true)
			await board_view.show_stone_hit_feedback(
				obstacle_result.damaged_stone_cells,
				destroyed_stones
			)
			if generation != _turn_generation:
				return
		if not destroyed_roots.is_empty():
			feedback_event.emit(&"root_cut", destroyed_roots.size())
			action_feedback.show_message(tr("КОРНИ СРЕЗАНЫ!"), true)
			await board_view.show_root_hit_feedback(destroyed_roots)
			if generation != _turn_generation:
				return
		_sync_obstacle_view()
		var dig_result := excavation_model.apply_hit_map_detailed(obstacle_result.overflow_hit_map)
		var changed_excavation_cells: Array[Vector2i] = dig_result.changed_cells
		_update_excavation_view(changed_excavation_cells, true)
		if int(dig_result.hits_applied) > 0:
			feedback_event.emit(&"dig", int(dig_result.hits_applied))
		_add_score(dig_result.hits_applied * score_config.excavation_hit)

		var new_fragments := excavation_model.collect_newly_completed_fragments()
		if is_endless():
			if not new_fragments.is_empty():
				await _collect_endless_finds(new_fragments, streak_multiplier)
				if generation != _turn_generation:
					return
		elif not new_fragments.is_empty():
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
			action_feedback.show_message(tr("ФРАГМЕНТ НАЙДЕН! +%d") % fragment_score, true)
			feedback_event.emit(&"fragment_found", new_fragments.size())
			await board_view.show_fragment_found_feedback(fragment_cells)
			if generation != _turn_generation:
				return
			_sync_excavation_view()
			await artifact_discovery_feedback.show_discoveries(
				fragment_artwork,
				tr(expedition_definition.artifact_name_ru)
			)
			if generation != _turn_generation:
				return

	if is_endless():
		await _apply_endless_events(line_count)
		if generation != _turn_generation:
			return
		_update_endless_hud()
	if not is_endless():
		_update_fragment_progress()
	if not is_endless() and excavation_model.is_goal_complete(obstacle_model):
		if not _victory_bonus_awarded:
			_victory_bonus_awarded = true
			_add_score(score_config.complete_artifact)
		coins_earned = economy_config.base_victory_coins
		var won_text := tr("УЧАСТОК ГОТОВ! +%d") if excavation_model.is_site_preparation() else tr("НАХОДКА ВОССТАНОВЛЕНА! +%d")
		action_feedback.show_message(won_text % score_config.complete_artifact, true)
		_finish_victory()
		return

	await _resolve_root_growth(roots_destroyed_this_turn > 0)
	if generation != _turn_generation:
		return
	piece_tray.consume_slot(slot_index)
	_busy = false
	evaluate_play_state()
	_update_help_ui()


func evaluate_play_state() -> void:
	if piece_tray.all_empty():
		piece_tray.load_set(piece_sequence.next_set(board_model, obstacle_model))
	var active_definitions := piece_tray.remaining_definitions()
	_no_moves = _is_no_moves_state(board_model, active_definitions, obstacle_model)
	# Hard: the move limit ends the attempt like a board with no room.
	_out_of_moves = not is_endless() and move_limit > 0 and moves >= move_limit
	if _out_of_moves:
		_no_moves = true
	no_moves_label.visible = _no_moves and not _out_of_moves
	if _no_moves:
		_input_blocked = true
		piece_tray.set_interaction_enabled(false)
		if is_endless():
			_finish_endless_run()
		else:
			_show_rescue_popup()
		feedback_event.emit(&"no_moves", 0)
		no_moves_reached.emit()
	else:
		_input_blocked = false
		piece_tray.set_interaction_enabled(not _busy and not pause_popup.visible)
	_update_help_ui()


func refresh_no_moves_state() -> void:
	evaluate_play_state()


func is_no_moves_state() -> bool:
	return _no_moves


func is_turn_resolving() -> bool:
	return _busy


func get_root_threat_source() -> Vector2i:
	return _root_threat_source


func get_root_threat_cell() -> Vector2i:
	return _root_threat_cell


## A piece is held by the pointer.
func is_drag_active() -> bool:
	return _active_definition != null


func has_turn_snapshot() -> bool:
	return _last_snapshot != null


func request_undo() -> bool:
	_register_interaction()
	if is_endless():
		return false
	if _busy or _last_snapshot == null or _reward_request_pending:
		return false
	# A held piece (second finger on the button, or a lost pointer release) is
	# dropped back to the tray first, so neither Undo nor its ad acts on a live drag.
	cancel_active_drag()
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
	if _busy or is_endless():
		return false
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
	cancel_active_drag()
	_reward_request_pending = true
	piece_tray.set_interaction_enabled(false)
	var request_id := reward_service.request_reward(RewardedActionService.RewardType.HINT)
	if request_id < 0:
		_reward_request_pending = false
		_update_help_ui()
		return false
	return true


## Hint button: shows the background plan at once when it is ready; if it is
## still being planned, finishes it faster (still sliced) and shows it then.
func _on_hint_button_pressed() -> void:
	if _hint_prefetch_running and not _hint_plan_ready():
		_hint_waiting_for_plan = true
		_hint_prefetch_planner.slice_budget_usec = 12000
		return
	request_hint()


func _hint_plan_ready() -> bool:
	return hint_planner.is_cached(hint_planner.cache_key(self, _capture_hint_search_state()))


func _prefetch_hint() -> void:
	if _hint_plan_ready():
		return
	var state_key := hint_planner.cache_key(self, _capture_hint_search_state())
	_hint_prefetch_running = true
	var planner := _hint_prefetch_planner
	var result: Dictionary = await planner.plan_sliced(self)
	_hint_prefetch_running = false
	planner.slice_budget_usec = 4000
	if not is_inside_tree():
		return
	if not planner.cancelled:
		hint_planner.adopt(state_key, result)
	if _hint_waiting_for_plan:
		_hint_waiting_for_plan = false
		if not planner.cancelled:
			request_hint()


## The board or tray changed: a running background plan is outdated.
func _on_hint_state_changed() -> void:
	_hint_prefetch_dirty = true
	_hint_waiting_for_plan = false
	if _hint_prefetch_running:
		_hint_prefetch_planner.cancelled = true


## Seed of this attempt's pieces: random (a new run every restart) or the
## expedition's own seed (tutorial levels, tests, the difficulty probe).
func _campaign_attempt_seed() -> int:
	if campaign_seed_override != 0:
		return campaign_seed_override
	if not random_campaign_pieces or expedition_definition.fixed_pieces:
		return expedition_definition.resolved_piece_seed()
	return int(randi() | 1)


## The scripted start keeps its pieces (same difficulty) but in a new order:
## the opening tray and the scripted sets are shuffled together.
static func _shuffle_scripted_pieces(
	opening: Array[PieceDefinition],
	curated: Array[PieceDefinition],
	seed_value: int
) -> void:
	var pool: Array[PieceDefinition] = []
	pool.append_array(opening)
	pool.append_array(curated)
	if pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(pool.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := pool[index]
		pool[index] = pool[other]
		pool[other] = held
	var opening_size := opening.size()
	opening.assign(pool.slice(0, opening_size))
	curated.assign(pool.slice(opening_size))


func attempt_seed() -> int:
	return _attempt_seed


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
	_turn_generation += 1
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
	_out_of_moves = false
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
	_on_hint_state_changed()
	turn_undone.emit()


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
	action_feedback.show_message(tr("Награда недоступна"))
	piece_tray.set_interaction_enabled(_can_interact())
	_update_help_ui()


func _show_best_hint() -> void:
	var hint := find_best_hint()
	if hint.is_empty():
		return
	_show_hint(hint)


func _show_hint(hint: Dictionary) -> void:
	cancel_active_drag()
	feedback_event.emit(&"hint", 0)
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
	return HintPlanner.enumerate_now(self, state, simulation_limit)


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
		if excavation.is_target_cell(cell):
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
		if simulated_excavation.is_target_cell(cell):
			artifact_cells_affected += 1
			artifact_excavation_hits += applied_hits
			artifact_hit_cells.append(cell)
	var dig_result := simulated_excavation.apply_hit_map_detailed(excavation_hit_map)
	var excavation_hits: int = dig_result.hits_applied
	var general_excavation_hits := excavation_hits - artifact_excavation_hits
	var completed_fragments := simulated_excavation.collect_newly_completed_fragments().size()
	simulated_board.clear_lines(rows, columns)
	var completes_expedition := (
		not is_endless() and simulated_excavation.is_goal_complete(simulated_obstacles)
	)

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
		var refill := _search_refill(sequence_position, simulated_board, simulated_obstacles)
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


## Same refill the real game would draw (same seed, set number and board).
func _search_refill(sequence_position: int, board: BoardModel, obstacles: ObstacleModel) -> Dictionary:
	var simulated_sequence := PieceSequence.new()
	simulated_sequence.configure(
		piece_sequence.curated_pieces(),
		piece_sequence.generation_config(),
		piece_sequence.seed_value()
	)
	simulated_sequence.restore_position(sequence_position)
	var definitions := simulated_sequence.next_set(board, obstacles)
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
			if simulated_excavation.is_target_cell(cell):
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
		reward_service.is_available(),
		_out_of_moves
	)


func _update_help_ui() -> void:
	# Help changes follow state changes (rescue, refill...): check the plan again.
	_hint_prefetch_dirty = true
	if is_endless():
		# No Undo or Hint in Endless Excavation: the record must mean something.
		undo_button.hide()
		hint_button.hide()
		help_state_changed.emit()
		return
	var has_snapshot := _last_snapshot != null
	# Round buttons show the uses left in a badge (or a video icon when the next
	# use is rewarded); the full sentence stays as the tooltip.
	var undo_text := ""
	var undo_badge := help_state.free_undos_remaining
	if has_snapshot and help_state.free_undos_remaining > 0:
		undo_text = tr("Отменить · %d") % help_state.free_undos_remaining
		undo_button.disabled = false
	elif has_snapshot and help_state.rewarded_undos_remaining > 0 and reward_service.is_available():
		undo_text = tr("Отменить · реклама")
		undo_badge = -1
		undo_button.disabled = false
	else:
		undo_text = tr("Отмена недоступна")
		undo_button.disabled = true
		if help_state.free_undos_remaining <= 0:
			undo_badge = -1 if help_state.rewarded_undos_remaining > 0 and reward_service.is_available() else -2

	var has_legal_hint := not _no_moves and _has_any_legal_move()
	var hint_text := ""
	var hint_badge := help_state.free_hints_remaining
	var hint_badge_text := ""
	if has_legal_hint and is_debug_unlimited_hints_enabled():
		hint_text = "Подсказка ∞ · DEBUG"
		hint_badge_text = "∞"
		hint_button.disabled = false
	elif has_legal_hint and help_state.free_hints_remaining > 0:
		hint_text = tr("Подсказка · %d") % help_state.free_hints_remaining
		hint_button.disabled = false
	elif has_legal_hint and help_state.rewarded_hints_remaining > 0 and reward_service.is_available():
		hint_text = tr("Подсказка · реклама")
		hint_badge = -1
		hint_button.disabled = false
	elif has_legal_hint:
		hint_text = tr("Подсказки закончились")
		hint_badge = -2
		hint_button.disabled = true
	else:
		hint_text = tr("Подсказка недоступна")
		hint_button.disabled = true
		if help_state.free_hints_remaining <= 0:
			hint_badge = -2
	if _busy or (not is_endless() and excavation_model.is_goal_complete(obstacle_model)):
		# A turn is still resolving (or the expedition is won); help actions wait.
		undo_button.disabled = true
		hint_button.disabled = true
	if _tutorial_active:
		undo_text = tr("Следуйте обучению")
		hint_text = tr("Следуйте обучению")
		undo_button.disabled = true
		hint_button.disabled = true
	_show_help_button(undo_button, undo_text, undo_badge)
	_show_help_button(hint_button, hint_text, hint_badge, hint_badge_text)

	if _no_moves and result_popup.visible:
		result_popup.update_rescue_undo(
			has_snapshot and help_state.free_undos_remaining > 0,
			has_snapshot and help_state.rewarded_undos_remaining > 0,
			reward_service.is_available()
		)
	help_state_changed.emit()


func _show_help_button(button: Button, explanation: String, badge: int, badge_text := "") -> void:
	if button.has_method("show_state"):
		button.call("show_state", explanation, badge, badge_text)
	else:
		button.text = explanation


func _add_score(points: int) -> void:
	if points <= 0:
		return
	if not is_endless():
		points = roundi(points * Difficulty.score_multiplier(difficulty))
	score += points
	_update_score_label()
	score_changed.emit(score)


func _update_moves_label() -> void:
	if move_limit > 0 and not is_endless():
		moves_label.text = tr("Ходы: %d / %d") % [moves, move_limit]
		if move_limit - moves <= 3:
			moves_label.add_theme_color_override("font_color", Color(0.9, 0.32, 0.2))
		else:
			moves_label.remove_theme_color_override("font_color")
	else:
		moves_label.text = tr("Ходы: %d") % moves
		moves_label.remove_theme_color_override("font_color")


func _update_score_label() -> void:
	if is_endless():
		score_label.text = format_number(score)
		_update_record_label()
		return
	score_label.text = format_number(score)


func _fragment_progress_text() -> String:
	if excavation_model.is_site_preparation():
		return tr("Осталось завалов: %d") % (excavation_model.soil_cell_count() + obstacle_model.occupied_count())
	return tr("Фрагменты: %d / %d") % [
		excavation_model.collected_fragment_count(),
		excavation_model.fragment_count(),
	]


## "Древний двор 1 — Первая линия" -> "Древний двор 1" for the one-line header.
static func short_title(full_title: String) -> String:
	return full_title.get_slice(" — ", 0).strip_edges()


func _update_fragment_progress() -> void:
	if is_endless():
		return
	if excavation_model.is_site_preparation():
		# Site levels: how much rubble is left (soil cells + stones + roots).
		for child in fragment_progress.get_parent().get_children():
			if child is TextureRect:
				child.visible = false
		fragment_progress.text = tr("Завалы: %d") % (
			excavation_model.soil_cell_count() + obstacle_model.occupied_count()
		)
		return
	var collected := excavation_model.collected_fragment_count()
	var total := excavation_model.fragment_count()
	fragment_progress.text = "%d / %d" % [collected, total]
	# Header silhouettes: one per fragment, lit when it is found.
	var index := 0
	for child in fragment_progress.get_parent().get_children():
		if child is TextureRect:
			child.visible = index < total
			child.modulate = Color.WHITE if index < collected else Color(0.3, 0.24, 0.18, 0.8)
			index += 1


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
			feedback_event.emit(&"root_grow", 1)
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


func _advance_endless_depth(line_count: int, streak_multiplier: float) -> void:
	total_lines += line_count
	if board_model.occupied_count() == 0 and endless_definition.board_clear_bonus > 0:
		var clear_bonus := roundi(endless_definition.board_clear_bonus * streak_multiplier)
		_add_score(clear_bonus)
		action_feedback.show_message(tr("ЧИСТОЕ ПОЛЕ! +%d") % clear_bonus, true)
		feedback_event.emit(&"board_clear", 1)
	var new_depth := endless_definition.depth_for_lines(total_lines)
	if new_depth == depth:
		return
	depth = new_depth
	depth_changed.emit(depth)
	feedback_event.emit(&"depth", depth)
	var new_layer := endless_definition.layer_index_for_depth(depth)
	if new_layer != _layer_index:
		_layer_index = new_layer
		var layer := endless_definition.layers[new_layer]
		piece_sequence.set_generation(layer.piece_generation)
		action_feedback.show_message(tr("ГЛУБИНА %d М: %s") % [depth, tr(layer.title_ru)], true)


func _finish_endless_run() -> void:
	_prepare_for_modal()
	var saved := ProgressStore.submit_endless_run(score, depth)
	if int(saved.error) != OK:
		push_warning("Could not save the endless record: %s" % error_string(int(saved.error)))
	elif bool(saved.new_score_record):
		# Autoload looked up at run time (tools compile this class without autoloads).
		var platform := get_node_or_null("/root/Platform")
		if platform != null:
			platform.call("submit_endless_best")
	_last_endless_result = {
		"score": score,
		"depth": depth,
		"lines": total_lines,
		"moves": moves,
		"best_streak": streak.best_streak,
		"best_score": maxi(int(saved.best_score), score),
		"best_depth": maxi(int(saved.best_depth), depth),
		"new_score_record": bool(saved.new_score_record) and score > 0,
		"new_depth_record": bool(saved.new_depth_record),
		"seed": _endless_seed,
		"finds": endless_events.finds_found,
		"daily": daily_mode,
	}
	if daily_mode:
		var daily := ProgressStore.submit_daily_run(_daily_key, score, endless_events.is_daily_goal_reached())
		_last_endless_result["daily_goal"] = endless_definition.daily_goal_finds
		_last_endless_result["daily_done"] = bool(daily.done)
		_last_endless_result["daily_best"] = int(daily.best_score)
	result_popup.show_endless_result(_last_endless_result)
	endless_run_finished.emit(_last_endless_result)
	_update_help_ui()


## Finds the player has dug up in the campaign: they come back as dig spots.
func _collection_finds() -> Array[ExpeditionDefinition]:
	# Dug up on any difficulty.
	var completed := {}
	for level in Difficulty.COUNT:
		completed.merge(ProgressStore.completed_expeditions_for(level))
	var all_finds: Array[ExpeditionDefinition] = []
	var dug: Array[ExpeditionDefinition] = []
	for chapter in CampaignRoute.chapters():
		for expedition in chapter.dig_expeditions():
			if expedition.full_artifact_texture == null:
				continue
			all_finds.append(expedition)
			if completed.has(expedition.id):
				dug.append(expedition)
	# The Daily Dig is the same for everyone, so it draws from all finds;
	# a player without finds yet gets the first chapter's.
	if daily_mode:
		return all_finds
	if dug.is_empty():
		return all_finds.slice(0, 6)
	return dug


## Spots, stones and roots after a move (EndlessEvents), shown on the board.
func _apply_endless_events(line_count: int) -> void:
	var events := endless_events.after_move(line_count, depth, board_model, obstacle_model, excavation_model)
	for event in events:
		var cell: Vector2i = event.cell
		match String(event.type):
			"spot_expired":
				excavation_model.remove_fragment(event.id)
				_update_excavation_view([cell], false)
				board_view.set_cell_countdown(cell, -1)
				action_feedback.show_message(tr("Грунт осыпался — находка потеряна"), false)
				feedback_event.emit(&"invalid", 0)
			"spot_new":
				excavation_model.add_dig_spot(event.id, cell, int(event.depth))
				_update_excavation_view([cell], true)
				action_feedback.show_message(
					tr("РАСКОП! Откопайте за %d ходов") % endless_definition.spot_moves, true
				)
				feedback_event.emit(&"dig", 1)
			"stone":
				obstacle_model.set_obstacle(cell, int(event.durability), ObstacleModel.Kind.STONE)
				if not _has_any_legal_move():
					obstacle_model.clear_obstacle(cell)
					continue
				_sync_obstacle_view()
				action_feedback.show_message(tr("С потолка упал камень!"), false)
				feedback_event.emit(&"stone_hit", 1)
			"root":
				obstacle_model.set_root(cell)
				if not _has_any_legal_move():
					obstacle_model.clear_obstacle(cell)
					continue
				_sync_obstacle_view()
				_update_root_threat()
				action_feedback.show_message(tr("Пророс корень!"), false)
				feedback_event.emit(&"root_grow", 1)
	for id: StringName in endless_events.spots:
		var spot: Dictionary = endless_events.spots[id]
		board_view.set_cell_countdown(spot.cell, int(spot.moves_left))


## Dig spots dug up this move: points, the find on screen, the Daily goal.
func _collect_endless_finds(fragment_ids: Array[StringName], streak_multiplier: float) -> void:
	var artwork: Array[Texture2D] = []
	var names: PackedStringArray = []
	for fragment_id in fragment_ids:
		var spot := endless_events.on_spot_found(fragment_id)
		if spot.is_empty():
			continue
		board_view.set_cell_countdown(spot.cell, -1)
		var find: ExpeditionDefinition = spot.find
		var bonus := roundi(endless_events.spot_bonus(spot) * streak_multiplier)
		_add_score(bonus)
		action_feedback.show_message(tr("НАХОДКА! +%d") % bonus, true)
		feedback_event.emit(&"fragment_found", 1)
		if find != null and find.full_artifact_texture != null:
			artwork.append(find.full_artifact_texture)
			names.append(tr(find.artifact_name_ru))
		excavation_model.remove_fragment(fragment_id)
		_update_excavation_view([spot.cell as Vector2i], false)
	if not artwork.is_empty():
		await artifact_discovery_feedback.show_discoveries(artwork, ", ".join(names))
	if endless_events.is_daily_goal_reached() and not _daily_goal_announced:
		_daily_goal_announced = true
		_add_score(endless_definition.daily_goal_bonus)
		ProgressStore.submit_daily_run(_daily_key, score, true)
		action_feedback.show_message(tr("РАСКОП ДНЯ ПРОЙДЕН! +%d") % endless_definition.daily_goal_bonus, true)
		feedback_event.emit(&"victory", 0)


func daily_key() -> String:
	return _daily_key


func _update_endless_hud() -> void:
	_update_record_label()
	if finds_label != null:
		finds_label.text = (
			tr("Находки: %d / %d") % [endless_events.finds_found, endless_definition.daily_goal_finds]
			if daily_mode
			else tr("Находки: %d") % endless_events.finds_found
		)
	if depth_label != null:
		var layer := endless_definition.layer_for_depth(depth)
		depth_label.text = tr("Глубина: %d м · %s") % [depth, tr(layer.title_ru) if layer != null else ""]
	if streak_label != null:
		if streak.is_active():
			var dots := ""
			for index in streak.grace_moves:
				dots += "●" if index < streak.moves_left else "○"
			streak_label.text = tr("Серия %s  %s") % [_format_multiplier(streak.multiplier()), dots]
		else:
			streak_label.text = tr("Серия: соберите линию")


func _update_record_label() -> void:
	if record_label == null:
		return
	if _best_score_at_start <= 0:
		record_label.text = tr("Рекорд: —")
	elif score > _best_score_at_start:
		record_label.text = tr("Новый рекорд!")
		if not _record_announced:
			_record_announced = true
			action_feedback.show_message(tr("НОВЫЙ РЕКОРД!"), true)
			feedback_event.emit(&"record", 1)
	elif score * 2 >= _best_score_at_start:
		record_label.text = tr("До рекорда: %s") % format_number(_best_score_at_start - score)
	else:
		record_label.text = tr("Рекорд: %s") % format_number(_best_score_at_start)


## "12 345" with a non-breaking space between thousands.
static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var groups: PackedStringArray = []
	while digits.length() > 3:
		groups.insert(0, digits.substr(digits.length() - 3))
		digits = digits.substr(0, digits.length() - 3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + "\u00a0".join(groups)


## "×1,5" in Russian, "×1.5" in English, "×2" for whole numbers.
static func _format_multiplier(value: float) -> String:
	var text := "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	if TranslationServer.get_locale().begins_with("ru"):
		text = text.replace(".", ",")
	return "×" + text


func _finish_victory() -> void:
	_busy = false
	_no_moves = false
	_out_of_moves = false
	_input_blocked = true
	no_moves_label.hide()
	piece_tray.set_interaction_enabled(false)
	_prepare_for_modal()
	var next_level := difficulty + 1
	var next_was_locked := next_level < Difficulty.COUNT and not Difficulty.is_unlocked(next_level)
	var progress_error := ProgressStore.mark_expedition_completed(expedition_definition.id, difficulty)
	if progress_error != OK:
		push_warning("Could not save expedition progress: %s" % error_string(progress_error))
	var chapter_info: Dictionary = {}
	if (
		progress_error == OK
		and chapter_definition != null
		and chapter_definition.is_finale(expedition_definition.id)
	):
		# The chapter counts as finished when all its finds are dug up.
		var chapter_ids := chapter_definition.dig_ids()
		var chapter_complete := true
		for expedition_id in chapter_ids:
			if not ProgressStore.is_expedition_completed(expedition_id, difficulty):
				chapter_complete = false
				break
		if chapter_complete:
			var reward_result := ProgressStore.claim_chapter_reward(
				chapter_definition.id,
				chapter_ids,
				chapter_definition.completion_reward_coins,
				difficulty
			)
			if reward_result.error != OK:
				push_warning("Could not save chapter reward: %s" % error_string(reward_result.error))
			chapter_info = {
				"complete": true,
				"title": tr(chapter_definition.title_ru),
				"completion_title": tr(chapter_definition.completion_title_ru),
				"collected": chapter_definition.dig_expeditions().size(),
				"total": chapter_definition.dig_expeditions().size(),
				"reward_coins": chapter_definition.completion_reward_coins,
				"reward_granted": bool(reward_result.granted),
				"reward_error": int(reward_result.error),
			}
			# The whole campaign is done: the next difficulty opens.
			if next_was_locked and Difficulty.is_unlocked(next_level):
				chapter_info["unlocked_difficulty"] = Difficulty.name_ru(next_level)
	if expedition_definition.is_site_preparation():
		result_popup.show_site_ready(
			tr(expedition_definition.artifact_name_ru),
			score,
			coins_earned,
			expedition_definition.full_artifact_texture
		)
	else:
		result_popup.show_victory(
			tr(expedition_definition.artifact_name_ru),
			score,
			coins_earned,
			expedition_definition.full_artifact_texture,
			chapter_info,
			not ProgressStore.is_artifact_restored(expedition_definition.artifact_id)
		)
	feedback_event.emit(&"victory", 0)
	victory_reached.emit()
	_update_help_ui()


func _prepare_for_modal() -> void:
	cancel_active_drag()
	action_feedback.clear()
	artifact_discovery_feedback.clear()
	board_view.clear_transient_feedback()


func _line_feedback_text(line_count: int, points: int) -> String:
	if line_count == 1:
		return tr("ЛИНИЯ! +%d") % points
	return tr("%d ЛИНИИ! +%d") % [line_count, points]


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
