extends SceneTree

## Campaign attempts draw new pieces: the map stays, the pieces change; the
## onboarding level and headless runs keep the expedition's own seed.

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
	_expect(not GameSession.random_campaign_pieces, "Headless runs keep fixed seeds by default")
	GameSession.random_campaign_pieces = true
	var game := (load("res://scenes/screens/game_screen_ch2_03.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var definition := session.expedition_definition
	var seeds := {}
	var trays := {}
	var board := session.board_model.capture_state()
	var pieces_count := definition.opening_piece_set.size() + definition.curated_piece_sequence.size()
	for attempt in 8:
		session.restart_expedition()
		seeds[session.attempt_seed()] = true
		var ids: Array[String] = []
		for piece in session.piece_tray.capture_state():
			ids.append(String(piece.id) if piece != null else "-")
		trays[",".join(ids)] = true
		_expect(session.board_model.capture_state() == board, "The map is the same on every attempt")
		var scripted := session.piece_sequence.curated_pieces().size() + 3
		_expect(scripted == pieces_count, "The scripted start keeps all its pieces (shuffled)")
	_expect(seeds.size() >= 7, "Every attempt has its own seed (%d of 8)" % seeds.size())
	_expect(trays.size() >= 3, "The first tray changes between attempts (%d different)" % trays.size())
	# Undo and the Hint use the attempt's own pieces.
	var hint := session.find_best_hint()
	_expect(not hint.is_empty() and session.try_place_piece(hint.slot_index, hint.origin), "Hint works with random pieces")
	_expect(session.request_undo(), "Undo works with random pieces")
	game.queue_free()
	await process_frame

	var tutorial := (load("res://scenes/screens/game_screen.tscn") as PackedScene).instantiate() as Control
	root.add_child(tutorial)
	await process_frame
	var first := tutorial.get_node("GameSession") as GameSession
	var first_seed := first.attempt_seed()
	first.restart_expedition()
	_expect(first.attempt_seed() == first_seed and first_seed == first.expedition_definition.resolved_piece_seed(), "Onboarding level keeps its fixed pieces")
	tutorial.queue_free()
	await process_frame
	GameSession.random_campaign_pieces = false

	if _failures.is_empty():
		print("random_pieces_test: %d checks passed" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
