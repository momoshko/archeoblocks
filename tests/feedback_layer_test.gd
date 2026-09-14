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
	var game := load("res://scenes/screens/game_screen_stone_prototype.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var feedback_layer := game.get_node("FeedbackUI") as CanvasLayer
	var modal_layer := game.get_node("ModalUI") as CanvasLayer
	var feedback := session.action_feedback
	_expect(feedback.get_parent() == feedback_layer, "ActionFeedback should belong to the dedicated gameplay feedback layer")
	_expect(feedback_layer.layer > 0, "Gameplay feedback layer should render above the normal gameplay canvas")
	_expect(feedback_layer.layer < modal_layer.layer, "ModalUI should remain above gameplay feedback")
	_expect(session.artifact_discovery_feedback.get_parent() == feedback_layer, "Artifact discovery feedback should share the semantic feedback layer")

	var hint := session.find_best_hint()
	_expect(not hint.is_empty() and session.request_hint(), "Hint ghost fixture should activate")
	feedback.show_message("ОЧИЩЕНО: +10")
	await process_frame
	_expect(feedback.visible and feedback.message_label.text == "ОЧИЩЕНО: +10", "Ordinary board feedback should still display")
	var ghost_count := 0
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if session.board_view.get_cell_view(Vector2i(x, y)).hint_ghost.visible:
				ghost_count += 1
	_expect(ghost_count > 0, "Board-local Hint ghost should remain present below feedback")
	_expect(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Raised feedback layer must continue ignoring pointer input")

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FEEDBACK_LAYER_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
