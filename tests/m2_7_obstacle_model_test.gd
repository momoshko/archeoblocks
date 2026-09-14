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
	var expedition := load("res://resources/expeditions/ruined_shrine_prototype_01.tres") as ExpeditionDefinition
	_expect(expedition != null and expedition.validate().is_empty(), "Stone prototype resource should load and validate")
	_expect(expedition.stone_obstacles.size() == 4, "Prototype should contain four Stone cells")
	var board := BoardModel.new()
	var obstacles := ObstacleModel.new()
	var excavation := ExcavationModel.new()
	_expect(obstacles.load_expedition(expedition).is_empty(), "Obstacle layer should load from expedition data")
	_expect(excavation.load_expedition(expedition).is_empty(), "Excavation layer should load independently")
	var single_shape: Array[Vector2i] = [Vector2i.ZERO]
	_expect(not obstacles.can_place(board, single_shape, Vector2i(6, 3)), "Placement overlapping Stone should be invalid")
	_expect(obstacles.can_place(board, single_shape, Vector2i(7, 3)), "Adjacent open terrain should remain placeable")

	for x in [0, 1, 2, 3, 4, 5, 7]:
		board.place(single_shape, Vector2i(x, 3), Color.WHITE)
	_expect(obstacles.get_full_rows(board) == [3], "Stone should count as the eighth filled cell in a row")
	var row_hits := ExcavationModel.build_line_hit_map([3], [])
	var row_result := obstacles.apply_hit_map(row_hits)
	_expect(row_result.obstacle_hits_applied == 1 and row_result.obstacles_destroyed == 1, "One row hit should destroy durability-1 Stone")
	_expect(not row_result.overflow_hit_map.has(Vector2i(6, 3)), "The Stone-destroying hit must not also reach excavation")
	var normal_depth_before := excavation.get_soil_depth(Vector2i(0, 3))
	var stone_depth_before := excavation.get_soil_depth(Vector2i(6, 3))
	excavation.apply_hit_map_detailed(row_result.overflow_hit_map)
	_expect(excavation.get_soil_depth(Vector2i(0, 3)) == normal_depth_before - 1, "Normal cells should preserve existing excavation behaviour")
	_expect(excavation.get_soil_depth(Vector2i(6, 3)) == stone_depth_before, "Soil under Stone should remain untouched by its destroying hit")

	obstacles.load_expedition(expedition)
	excavation.load_expedition(expedition)
	var cross_hits := ExcavationModel.build_line_hit_map([3], [6])
	var cross_result := obstacles.apply_hit_map(cross_hits)
	_expect(cross_result.obstacle_hits_applied == 1 and cross_result.obstacles_destroyed == 1, "Intersection should consume its first hit against Stone")
	_expect(cross_result.overflow_hit_map.get(Vector2i(6, 3), 0) == 1, "Intersection should pass exactly one remaining hit to excavation")
	excavation.apply_hit_map_detailed(cross_result.overflow_hit_map)
	_expect(excavation.get_soil_depth(Vector2i(6, 3)) == 0, "Overflow hit should excavate the soil below the destroyed Stone")

	obstacles.reset()
	_expect(obstacles.set_obstacle(Vector2i(2, 2), 2), "Obstacle layer should support integer durability for future tuning")
	var state := obstacles.capture_state()
	obstacles.apply_hit_map({Vector2i(2, 2): 1})
	_expect(obstacles.get_durability(Vector2i(2, 2)) == 1, "A durability-2 obstacle should retain one durability after one hit")
	obstacles.restore_state(state)
	_expect(obstacles.get_durability(Vector2i(2, 2)) == 2, "Obstacle capture/restore should preserve durability")

	if _failures.is_empty():
		print("M2_7_OBSTACLE_MODEL_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
