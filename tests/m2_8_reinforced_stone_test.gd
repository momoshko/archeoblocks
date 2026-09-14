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
	_test_durability_and_overflow()
	await _test_scene_visual_states()
	await _test_undo_restores_reinforced_stone()
	if _failures.is_empty():
		print("M2_8_REINFORCED_STONE_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_durability_and_overflow() -> void:
	var cell := Vector2i(3, 3)
	var obstacles := ObstacleModel.new()
	obstacles.set_obstacle(cell, 2)
	var first_hit := obstacles.apply_hit_map({cell: 1})
	_expect(obstacles.get_durability(cell) == 1, "One hit should crack reinforced Stone from 2 to 1")
	_expect(first_hit.obstacle_hits_applied == 1 and first_hit.obstacles_destroyed == 0, "First reinforced hit should damage without destroying")
	var second_hit := obstacles.apply_hit_map({cell: 1})
	_expect(obstacles.get_durability(cell) == 0, "Second hit should destroy reinforced Stone")
	_expect(second_hit.obstacle_hits_applied == 1 and second_hit.obstacles_destroyed == 1, "Second reinforced hit should report destruction")

	obstacles.set_obstacle(cell, 1)
	var normal_intersection := obstacles.apply_hit_map({cell: 2})
	_expect(normal_intersection.obstacles_destroyed == 1, "Two intersection hits should destroy normal Stone")
	_expect(normal_intersection.overflow_hit_map.get(cell, 0) == 1, "Normal Stone intersection should pass one hit to excavation")

	obstacles.set_obstacle(cell, 2)
	var reinforced_intersection := obstacles.apply_hit_map({cell: 2})
	_expect(reinforced_intersection.obstacles_destroyed == 1, "Two intersection hits should destroy reinforced Stone")
	_expect(not reinforced_intersection.overflow_hit_map.has(cell), "Reinforced Stone intersection should leave zero excavation overflow")


func _test_scene_visual_states() -> void:
	var view := load("res://scenes/game/stone_obstacle_view.tscn").instantiate() as StoneObstacleView
	root.add_child(view)
	await process_frame
	view.show_durability(2)
	_expect(view.visible and view.intact_tint.visible, "Durability 2 should show the heavier intact treatment")
	_expect(not view.crack_a.visible and not view.crack_b.visible, "Durability 2 should not look already cracked")
	view.show_durability(1)
	_expect(not view.intact_tint.visible, "Durability 1 should remove the intact dark overlay")
	_expect(view.crack_a.visible and view.crack_b.visible, "Durability 1 should expose the scene-authored cracks")
	view.queue_free()
	await process_frame


func _test_undo_restores_reinforced_stone() -> void:
	var game := load("res://scenes/screens/game_screen_ch2_03.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var cell := Vector2i(2, 2)
	_expect(session.obstacle_model.get_durability(cell) == 2, "Expedition 2-3 should start with reinforced Stone")
	session._last_snapshot = session._create_snapshot()
	session.obstacle_model.apply_hit_map({cell: 1})
	session._sync_obstacle_view()
	_expect(session.obstacle_model.get_durability(cell) == 1, "Fixture should crack Stone before Undo")
	_expect(session.request_undo(), "Undo should accept a reinforced Stone state change")
	_expect(session.obstacle_model.get_durability(cell) == 2, "Undo should restore durability 2")
	var stone_view := session.board_view.get_cell_view(cell).stone_obstacle as StoneObstacleView
	_expect(stone_view.get_durability() == 2 and stone_view.intact_tint.visible, "Undo should restore the reinforced visual state")
	game.queue_free()
	await process_frame
