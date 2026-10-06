extends SceneTree

## M3.5 animations: button press, window pop-in, piece landing, line pop with
## gem shards of the block colour.

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	OnboardingTutorial.auto_start = false
	var game := (load("res://scenes/screens/game_screen_ch2_01.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame

	# Button press: squeezed while held, back to full size after release.
	var pause := game.get_node("ContentCenter/PortraitContent/MainLayout/Header/PauseButton") as Button
	await create_timer(0.2).timeout  # the first frames after loading are long
	pause.button_down.emit()
	await process_frame
	await create_timer(0.1).timeout
	_expect(pause.scale.x < 0.99 and pause.scale.x > 0.85, "A held button is squeezed (%s)" % pause.scale)
	_expect(pause.pivot_offset.is_equal_approx(pause.size * 0.5), "A button squeezes around its centre")
	pause.button_up.emit()
	await create_timer(0.25).timeout
	_expect(pause.scale.is_equal_approx(Vector2.ONE), "A released button springs back (%s)" % pause.scale)

	# Window pop-in: starts small and transparent, ends at full size.
	var session := game.get_node("GameSession") as GameSession
	var result := session.result_popup
	var panel := result.get_node("PopupCenter/PopupPanel") as Control
	result.show_victory("Test", 10, 0, null)
	_expect(panel.scale.x < 0.9 and result.modulate.a < 0.5, "A window starts its pop-in small and faint")
	_expect(result.visible, "The window is visible at once (the game does not wait)")
	await create_timer(0.35).timeout
	_expect(panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(result.modulate.a, 1.0), "The window ends at full size")
	result.close_popup()
	_expect(not result.visible and panel.scale == Vector2.ONE, "Closing is instant and resets the window")

	# Victory celebration: ribbon, confetti, score counts up, buttons come later.
	result.show_victory("Test", 500, 0, null)
	_expect(result.ribbon.visible and result.confetti.emitting, "Victory shows the ribbon and confetti")
	_expect(result.score_label.text == "Счёт: 0", "The score starts counting from 0")
	_expect(result.buttons.modulate.a < 0.1, "Buttons wait until the find is seen")
	await create_timer(result.score_count_seconds + 0.6).timeout
	_expect(result.score_label.text == "Счёт: 500", "The score counts up to the final value (%s)" % result.score_label.text)
	_expect(is_equal_approx(result.buttons.modulate.a, 1.0), "Buttons appear after the pause")
	result.show_rescue("0 / 2", false, false, false)
	_expect(not result.ribbon.visible and not result.confetti.emitting and is_equal_approx(result.buttons.modulate.a, 1.0), "Rescue has no celebration")
	result.close_popup()

	# Landing: the placed blocks drop in bigger and settle.
	var board := session.board_view
	var cells: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
	board.set_cells_occupied(cells, Color(0.2, 0.6, 0.3))
	board.play_landing(cells)
	var block := board.get_cell_view(Vector2i(0, 7)).block_visual
	_expect(block.scale.x > 1.05, "A landing block starts bigger (%s)" % block.scale)
	await create_timer(0.2).timeout
	_expect(block.scale.is_equal_approx(Vector2.ONE), "A landing block settles at its size")

	# Line pop: a wave from the piece, gem shards tinted with the block colour.
	var row: Array[Vector2i] = []
	for x in BoardModel.WIDTH:
		row.append(Vector2i(x, 0))
	board.set_cells_occupied(row, Color(0.8, 0.2, 0.2))
	board.clear_cells_with_feedback.call_deferred(row, Vector2(0.0, 0.0))
	await process_frame
	await process_frame
	var fx := game.get_node("FeedbackUI/BoardFx") as BoardFx
	var shards := fx.get_node("Shards") as CPUParticles2D
	_expect(shards.emitting, "Popping blocks throw gem shards")
	_expect(shards.color.r > shards.color.g and shards.color.r > shards.color.b, "Shards take the block colour (%s)" % shards.color)
	_expect(shards.amount <= fx.max_particles, "Shards stay light (%d)" % shards.amount)
	await create_timer(0.07).timeout
	var near := board.get_cell_view(Vector2i(0, 0)).block_visual
	var far := board.get_cell_view(Vector2i(7, 0)).block_visual
	_expect(near.modulate.a < far.modulate.a, "The wave reaches the near block first (%.2f vs %.2f)" % [near.modulate.a, far.modulate.a])
	await create_timer(board.clear_feedback_duration).timeout
	_expect(not far.visible, "After the wave the line is empty")

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_MOTION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
