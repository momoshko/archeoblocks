extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var expedition := load("res://resources/expeditions/overgrown_catacombs_prototype_01.tres") as ExpeditionDefinition
	_expect(expedition != null and expedition.validate().is_empty(), "Root prototype resource should load and validate")
	var obstacles := ObstacleModel.new()
	var board := BoardModel.new()
	_expect(obstacles.load_expedition(expedition).is_empty(), "ObstacleModel should load typed Roots")
	_expect(obstacles.root_count() == 4, "Prototype should begin with four Roots")
	_expect(not obstacles.can_place(board, [Vector2i.ZERO], Vector2i(1, 1)), "Placement overlapping Root should be invalid")
	var excavation := ExcavationModel.new()
	excavation.load_expedition(expedition)
	var artifact_root := Vector2i(6, 5)
	var artifact_depth_before := excavation.get_soil_depth(artifact_root)
	var artifact_cross := obstacles.apply_hit_map({artifact_root: 2})
	excavation.apply_hit_map_detailed(artifact_cross.overflow_hit_map)
	_expect(excavation.get_soil_depth(artifact_root) == artifact_depth_before - 1, "Second intersection hit should reach excavation below destroyed Root")

	obstacles.reset()
	obstacles.set_root(Vector2i(7, 0))
	for x in 7:
		board.place([Vector2i.ZERO], Vector2i(x, 0), Color.WHITE)
	_expect(obstacles.get_full_rows(board) == [0], "Root should count as filled for line completion")
	var row_result := obstacles.apply_hit_map(ExcavationModel.build_line_hit_map([0], []))
	_expect(row_result.roots_destroyed == 1 and not obstacles.has_obstacle(Vector2i(7, 0)), "One hit should destroy durability-1 Root")
	_expect(not row_result.overflow_hit_map.has(Vector2i(7, 0)), "Root-destroying hit should not overflow into excavation")

	obstacles.set_root(Vector2i(3, 3))
	var cross_result := obstacles.apply_hit_map({Vector2i(3, 3): 2})
	_expect(cross_result.roots_destroyed == 1, "Row-column intersection should destroy Root")
	_expect(cross_result.overflow_hit_map.get(Vector2i(3, 3), 0) == 1, "Intersection should pass exactly one hit through Root")

	board.reset()
	obstacles.reset()
	obstacles.set_root(Vector2i(1, 1))
	var first_threat := obstacles.find_root_growth_target(board)
	var second_threat := obstacles.find_root_growth_target(board)
	_expect(first_threat == second_threat, "Same board state should always produce the same warning")
	_expect(first_threat.source == Vector2i(1, 1) and first_threat.destination == Vector2i(2, 1), "Deterministic ordering should select rightward open cell first")
	_expect(obstacles.grow_root(first_threat.source, first_threat.destination, board), "Root should grow into the warned free cell")
	_expect(obstacles.is_root(Vector2i(2, 1)) and obstacles.root_count() == 2, "Growth should add exactly one Root")

	obstacles.reset()
	obstacles.set_root(Vector2i(1, 1))
	obstacles.set_obstacle(Vector2i(2, 1), 1)
	_expect(not obstacles.set_root(Vector2i(2, 1)) and obstacles.is_stone(Vector2i(2, 1)), "Root and Stone cannot replace each other in one obstacle cell")
	_expect(not obstacles.can_grow_root_to(Vector2i(1, 1), Vector2i(2, 1), board), "Root cannot grow onto Stone")
	obstacles.set_root(Vector2i(1, 2))
	_expect(not obstacles.can_grow_root_to(Vector2i(1, 1), Vector2i(1, 2), board), "Root cannot grow onto another Root")
	board.place([Vector2i.ZERO], Vector2i(0, 1), Color.WHITE)
	_expect(not obstacles.can_grow_root_to(Vector2i(1, 1), Vector2i(0, 1), board), "Root cannot grow onto a player block")

	var state := obstacles.capture_state()
	obstacles.reset()
	obstacles.restore_state(state)
	_expect(obstacles.is_root(Vector2i(1, 1)) and obstacles.is_stone(Vector2i(2, 1)), "Obstacle snapshot should preserve both kinds")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("M2_9_ROOT_MODEL_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
