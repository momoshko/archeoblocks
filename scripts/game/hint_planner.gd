class_name HintPlanner
extends RefCounted

const NEGATIVE_INFINITY := -2147483648

var _cached_state_key := ""
var _cached_result: Dictionary = {}


func find_best(session: GameSession) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	var initial_state := session._capture_hint_search_state()
	var state_key := "%s|depth=%d|beam=%d" % [
		session._hint_search_state_key(initial_state),
		session.help_config.hint_planning_depth,
		session.help_config.hint_beam_width,
	]
	if state_key == _cached_state_key and not _cached_result.is_empty():
		var cached := _cached_result.duplicate(true)
		cached["cache_hit"] = true
		cached["planning_time_ms"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
		return cached
	var candidates := session._enumerate_hint_moves(initial_state)
	if candidates.is_empty():
		return {}
	var explored_states := candidates.size()
	var feasibility_cache: Dictionary = {}
	for index in candidates.size():
		var candidate: Dictionary = candidates[index]
		candidate["planner_index"] = index
		candidate["plan_survives"] = false
		candidate["planning_depth_reached"] = 1
		candidate["best_continuation_value"] = NEGATIVE_INFINITY
		candidate["predicted_terminal"] = "immediate_loss" if candidate.immediate_loss else "short_survival"
		if candidate.completes_expedition:
			candidate["current_tray_possible"] = true
			candidate["predicted_terminal"] = "victory"
		elif candidate.immediate_loss:
			candidate["current_tray_possible"] = false
		else:
			var feasibility_stats := {"explored": 0}
			candidate["current_tray_possible"] = (
				candidate.used_refill
				or _can_complete_current_tray(
					session,
					candidate.next_state,
					int(initial_state.refill_generation) + 1,
					feasibility_cache,
					feasibility_stats
				)
			)
			explored_states += int(feasibility_stats.explored)

	var victories: Array[Dictionary] = []
	for candidate in candidates:
		if candidate.completes_expedition:
			victories.append(candidate)
	if not victories.is_empty():
		victories.sort_custom(_candidate_better)
		return _remember(state_key, _finalize(victories[0], explored_states, started_usec))

	_run_beam_search(session, candidates, explored_states)
	# Beam search stores its total in each candidate so the selected result can report it.
	for candidate in candidates:
		explored_states = maxi(explored_states, int(candidate.get("planner_explored_states", explored_states)))

	candidates.sort_custom(_candidate_better)
	return _remember(state_key, _finalize(candidates[0], explored_states, started_usec))


func _remember(state_key: String, result: Dictionary) -> Dictionary:
	_cached_state_key = state_key
	_cached_result = result.duplicate(true)
	result["cache_hit"] = false
	return result


func _run_beam_search(session: GameSession, candidates: Array[Dictionary], initial_explored: int) -> void:
	var depth_limit := maxi(1, session.help_config.hint_planning_depth)
	var beam_width := maxi(1, session.help_config.hint_beam_width)
	if depth_limit <= 1:
		return
	var viable_seed_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if candidate.survives and candidate.current_tray_possible:
			viable_seed_candidates.append(candidate)
	if viable_seed_candidates.is_empty():
		for candidate in candidates:
			if candidate.survives:
				viable_seed_candidates.append(candidate)
	viable_seed_candidates.sort_custom(_seed_better)
	if viable_seed_candidates.size() > beam_width:
		viable_seed_candidates.resize(beam_width)

	var frontier_by_key: Dictionary = {}
	for candidate in viable_seed_candidates:
		var state: Dictionary = candidate.next_state
		var key := session._hint_search_state_key(state)
		var node := {
			"state": state,
			"first_indices": [int(candidate.planner_index)],
			"path_value": int(candidate.value),
			"rank": int(candidate.value),
		}
		_merge_node(frontier_by_key, key, node)
	var frontier: Array[Dictionary] = []
	frontier.assign(frontier_by_key.values())
	var explored_states := initial_explored
	var per_node_limit := maxi(4, int(ceili(float(beam_width) * 0.25)))

	for search_depth in range(2, depth_limit + 1):
		var expanded_by_key: Dictionary = {}
		for node in frontier:
			var moves := session._enumerate_hint_moves(node.state, per_node_limit)
			explored_states += moves.size()
			moves.sort_custom(_move_better)
			for move in moves:
				if move.immediate_loss:
					continue
				var path_value := int(node.path_value) + int(move.value)
				var rank := path_value
				if move.completes_expedition:
					_mark_plan(candidates, node.first_indices, search_depth, "victory", rank)
					continue
				var next_node := {
					"state": move.next_state,
					"first_indices": node.first_indices.duplicate(),
					"path_value": path_value,
					"rank": rank,
				}
				_merge_node(
					expanded_by_key,
					session._hint_search_state_key(move.next_state),
					next_node
				)
		if expanded_by_key.is_empty():
			break
		var expanded: Array[Dictionary] = []
		expanded.assign(expanded_by_key.values())
		frontier = _select_diverse_frontier(expanded, beam_width)
		if search_depth == depth_limit:
			for node in frontier:
				var continuation_value := (
					int(node.path_value) + session._evaluate_hint_leaf(node.state)
				)
				_mark_plan(
					candidates,
					node.first_indices,
					search_depth,
					"horizon",
					continuation_value
				)
	for candidate in candidates:
		candidate["planner_explored_states"] = explored_states


func _can_complete_current_tray(
	session: GameSession,
	state: Dictionary,
	target_generation: int,
	cache: Dictionary,
	stats: Dictionary
) -> bool:
	if state.get("victory", false) or int(state.refill_generation) >= target_generation:
		return true
	if state.get("no_moves", false):
		return false
	var key := "%s|tray_target=%d" % [session._hint_search_state_key(state), target_generation]
	if cache.has(key):
		return bool(cache[key])
	var board := BoardModel.new()
	board.restore_state(state.board_state)
	var obstacles := ObstacleModel.new()
	obstacles.restore_state(state.obstacle_state)
	var tray: Array[PieceDefinition] = []
	tray.assign(state.tray_state)
	var seen_piece_ids: Dictionary = {}
	for slot_index in tray.size():
		var definition := tray[slot_index]
		if definition == null or seen_piece_ids.has(definition.id):
			continue
		seen_piece_ids[definition.id] = true
		for y in BoardModel.HEIGHT:
			for x in BoardModel.WIDTH:
				var origin := Vector2i(x, y)
				if not obstacles.can_place(board, definition.cells, origin):
					continue
				var move := session._simulate_hint_move(state, slot_index, definition, origin)
				stats.explored = int(stats.explored) + 1
				if move.immediate_loss:
					continue
				if (
					move.completes_expedition
					or int(move.next_state.refill_generation) >= target_generation
					or _can_complete_current_tray(
						session,
						move.next_state,
						target_generation,
						cache,
						stats
					)
				):
					cache[key] = true
					return true
	cache[key] = false
	return false


func _merge_node(nodes_by_key: Dictionary, key: String, incoming: Dictionary) -> void:
	if not nodes_by_key.has(key):
		nodes_by_key[key] = incoming
		return
	var existing: Dictionary = nodes_by_key[key]
	for first_index in incoming.first_indices:
		if not existing.first_indices.has(first_index):
			existing.first_indices.append(first_index)
	if int(incoming.rank) > int(existing.rank):
		existing.state = incoming.state
		existing.path_value = incoming.path_value
		existing.rank = incoming.rank
	nodes_by_key[key] = existing


func _select_diverse_frontier(expanded: Array[Dictionary], beam_width: int) -> Array[Dictionary]:
	expanded.sort_custom(_node_better)
	var selected: Array[Dictionary] = []
	var covered_first_moves: Dictionary = {}
	for node in expanded:
		var adds_lineage := false
		for first_index in node.first_indices:
			if not covered_first_moves.has(first_index):
				adds_lineage = true
				break
		if adds_lineage:
			selected.append(node)
			for first_index in node.first_indices:
				covered_first_moves[first_index] = true
			if selected.size() >= beam_width:
				return selected
	for node in expanded:
		if not selected.has(node):
			selected.append(node)
			if selected.size() >= beam_width:
				break
	return selected


func _mark_plan(
	candidates: Array[Dictionary],
	first_indices: Array,
	depth: int,
	terminal: String,
	continuation_value: int
) -> void:
	for first_index in first_indices:
		var candidate: Dictionary = candidates[int(first_index)]
		candidate.plan_survives = true
		candidate.planning_depth_reached = maxi(int(candidate.planning_depth_reached), depth)
		if continuation_value > int(candidate.best_continuation_value):
			candidate.best_continuation_value = continuation_value
			candidate.predicted_terminal = terminal


func _finalize(candidate: Dictionary, explored_states: int, started_usec: int) -> Dictionary:
	var result := candidate.duplicate(true)
	result["safety_class"] = _safety_class(result)
	result["explored_states"] = explored_states
	result["planning_time_ms"] = float(Time.get_ticks_usec() - started_usec) / 1000.0
	result.erase("next_state")
	result.erase("planner_index")
	result.erase("planner_explored_states")
	return result


func _safety_class(candidate: Dictionary) -> String:
	if candidate.get("completes_expedition", false):
		return "IMMEDIATE_VICTORY"
	if candidate.get("plan_survives", false):
		return "PLAN_SURVIVES"
	if candidate.get("survives", false):
		return "SHORT_SURVIVES"
	return "IMMEDIATE_LOSS"


func _candidate_better(first: Dictionary, second: Dictionary) -> bool:
	var first_class := _class_rank(first)
	var second_class := _class_rank(second)
	if first_class != second_class:
		return first_class > second_class
	if bool(first.get("current_tray_possible", false)) != bool(second.get("current_tray_possible", false)):
		return bool(first.get("current_tray_possible", false))
	var first_continuation := int(first.get("best_continuation_value", NEGATIVE_INFINITY))
	var second_continuation := int(second.get("best_continuation_value", NEGATIVE_INFINITY))
	if first_continuation != second_continuation:
		return first_continuation > second_continuation
	return _move_better(first, second)


func _class_rank(candidate: Dictionary) -> int:
	if candidate.get("completes_expedition", false):
		return 3
	if candidate.get("plan_survives", false):
		return 2
	if candidate.get("survives", false):
		return 1
	return 0


func _seed_better(first: Dictionary, second: Dictionary) -> bool:
	if bool(first.current_tray_possible) != bool(second.current_tray_possible):
		return bool(first.current_tray_possible)
	return _move_better(first, second)


func _move_better(first: Dictionary, second: Dictionary) -> bool:
	if int(first.value) != int(second.value):
		return int(first.value) > int(second.value)
	if int(first.get("slot_index", 0)) != int(second.get("slot_index", 0)):
		return int(first.get("slot_index", 0)) < int(second.get("slot_index", 0))
	var first_origin: Vector2i = first.get("origin", Vector2i.ZERO)
	var second_origin: Vector2i = second.get("origin", Vector2i.ZERO)
	return first_origin.y < second_origin.y or (first_origin.y == second_origin.y and first_origin.x < second_origin.x)


func _node_better(first: Dictionary, second: Dictionary) -> bool:
	return int(first.rank) > int(second.rank)
