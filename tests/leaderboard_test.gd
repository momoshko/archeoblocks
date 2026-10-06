extends SceneTree

## Endless leaderboard: the lobby button opens the panel, rows and the own
## place are shown, guests get the sign-in button, other states have a message.

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var screen := (load("res://scenes/screens/endless_screen.tscn") as PackedScene).instantiate() as Control
	root.add_child(screen)
	await process_frame
	var lobby := screen.get_node("ModalUI/EndlessLobby") as EndlessLobby
	var panel := lobby.get_node("%LeaderboardPanel") as LeaderboardPanel
	_expect(not panel.visible, "A: the leaderboard is closed at first")
	(lobby.get_node("%LeadersButton") as Button).pressed.emit()
	_expect(panel.visible, "A: «Лидеры» opens the leaderboard")
	# Debug build outside Yandex: the plugin's mock answers with sample players.
	for frame in 30:
		await process_frame
	var rows := panel.get_node("%Rows").get_children()
	var shown := 0
	for row in rows:
		if (row as Control).visible:
			shown += 1
	_expect(shown > 0, "A: the debug mock fills the rows (%d)" % shown)

	panel.show_data({
		"state": "ok", "authorized": false,
		"entries": [{"rank": 1, "name": "Анна", "score": 5000, "me": false}, {"rank": 2, "name": "", "score": 4000, "me": false}],
		"me": {},
	})
	_expect((rows[0].get_node("Line/Name") as Label).text == "Анна" and (rows[1].get_node("Line/Name") as Label).text == "Игрок", "B: names, and «Игрок» for a hidden name")
	_expect((rows[0].get_node("Line/Score") as Label).text == GameSession.format_number(5000), "B: scores are formatted")
	_expect(not (rows[2] as Control).visible, "B: unused rows are hidden")
	_expect((panel.get_node("%AuthButton") as Control).visible, "B: a guest sees the sign-in button")
	_expect(not (panel.get_node("%MyPlace") as Control).visible, "B: no own place for a guest")

	panel.show_data({
		"state": "ok", "authorized": true,
		"entries": [{"rank": 1, "name": "Вы", "score": 9000, "me": true}],
		"me": {"rank": 1, "score": 9000},
	})
	_expect(not (panel.get_node("%AuthButton") as Control).visible, "C: no sign-in button when signed in")
	_expect((panel.get_node("%MyPlace") as Label).text.contains("1"), "C: the own place is shown")
	_expect(rows[0].self_modulate != Color.WHITE, "C: the own row is highlighted")

	panel.show_data({"state": "offline"})
	_expect((panel.get_node("%Status") as Label).text.contains("Яндекс"), "D: outside Yandex the panel says where it works")
	panel.show_data({"state": "error"})
	_expect((panel.get_node("%Status") as Label).visible, "D: a load error has a message")
	(panel.get_node("%CloseButton") as Button).pressed.emit()
	_expect(not panel.visible and lobby.visible, "D: «Назад» returns to the lobby")
	screen.queue_free()
	await process_frame

	if _failures.is_empty():
		print("LEADERBOARD_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
