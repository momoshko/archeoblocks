extends SceneTree

# Seeded weighted piece generation: deterministic, weighted, fair, and the Hint
# planner predicts exactly the refill the real game draws.

const CONFIG_PATHS := [
	"res://resources/config/pieces_chapter_1.tres",
	"res://resources/config/pieces_chapter_2.tres",
	"res://resources/config/pieces_chapter_3.tres",
]
const CHAPTER_PATHS := [
	"res://resources/chapters/ancient_courtyard.tres",
	"res://resources/chapters/ruined_shrine.tres",
	"res://resources/chapters/overgrown_catacombs.tres",
]

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _ids(pieces: Array[PieceDefinition]) -> String:
	var parts: PackedStringArray = []
	for piece in pieces:
		parts.append(String(piece.id) if piece != null else "null")
	return ",".join(parts)


func _run() -> void:
	OnboardingTutorial.auto_start = false
	var config := load(CONFIG_PATHS[1]) as PieceGenerationConfig
	for path in CONFIG_PATHS:
		var errors := (load(path) as PieceGenerationConfig).validate()
		_expect(errors.is_empty(), "%s is valid: %s" % [path, errors])

	# A: same seed and set number -> same set; another seed -> another sequence.
	var a := PieceSequence.new()
	a.configure([], config, 42)
	var b := PieceSequence.new()
	b.configure([], config, 42)
	var c := PieceSequence.new()
	c.configure([], config, 43)
	var same := true
	var differs := false
	for i in 20:
		var set_a := a.next_set()
		var set_b := b.next_set()
		var set_c := c.next_set()
		same = same and _ids(set_a) == _ids(set_b)
		differs = differs or _ids(set_a) != _ids(set_c)
		_expect(set_a.size() == 3, "A: every set has three pieces")
	_expect(same, "A: same seed gives the same sequence")
	_expect(differs, "A: another seed gives another sequence")
	_expect(a.capture_position() == 20, "A: generated positions count up without looping")

	# B: restore_position replays the same set (Undo).
	var replay := PieceSequence.new()
	replay.configure([], config, 42)
	replay.restore_position(7)
	var direct := PieceSequence.new()
	direct.configure([], config, 42)
	_expect(_ids(replay.next_set()) == _ids(direct.set_at(7)), "B: restored position replays the same set")

	# C: weights and the max-same rule over many sets.
	var counts: Dictionary = {}
	var triple := false
	var many := PieceSequence.new()
	many.configure([], config, 7)
	for i in 600:
		var pieces := many.next_set()
		var per_set: Dictionary = {}
		for piece in pieces:
			counts[piece.id] = int(counts.get(piece.id, 0)) + 1
			per_set[piece.id] = int(per_set.get(piece.id, 0)) + 1
		for key in per_set:
			triple = triple or int(per_set[key]) > config.max_same_piece
	_expect(not triple, "C: no piece more than max_same_piece times in a set")
	_expect(int(counts.get(&"square_2", 0)) > int(counts.get(&"plus_5", 0)) * 2, "C: heavy pieces come clearly more often than light ones")
	var chapter_one := load(CONFIG_PATHS[0]) as PieceGenerationConfig
	var easy := PieceSequence.new()
	easy.configure([], chapter_one, 7)
	var has_plus := false
	for i in 300:
		for piece in easy.next_set():
			has_plus = has_plus or piece.id == &"plus_5"
	_expect(not has_plus, "C: weight 0 removes a piece (no Cross 5 in Chapter I)")

	# D: fairness - on a nearly full board at least one piece fits.
	var board := BoardModel.new()
	for y in BoardModel.HEIGHT:
		for x in BoardModel.WIDTH:
			if not (x == 3 and y == 3):
				board.place([Vector2i.ZERO] as Array[Vector2i], Vector2i(x, y))
	var obstacles := ObstacleModel.new()
	var fair := PieceSequence.new()
	fair.configure([], config, 99)
	var all_fair := true
	for i in 30:
		var pieces := fair.next_set(board, obstacles)
		var fits := false
		for piece in pieces:
			fits = fits or obstacles.has_legal_placement(board, piece.cells)
		all_fair = all_fair and fits
	_expect(all_fair, "D: with one free cell every set still contains a piece that fits")

	# E: curated triples play once, then generation takes over.
	var single := load("res://resources/pieces/single.tres") as PieceDefinition
	var square := load("res://resources/pieces/square_2.tres") as PieceDefinition
	var curated: Array[PieceDefinition] = [single, single, square, square, square, single]
	var mixed := PieceSequence.new()
	mixed.configure(curated, config, 5)
	_expect(_ids(mixed.next_set()) == "single,single,square_2", "E: first curated triple")
	_expect(_ids(mixed.next_set()) == "square_2,square_2,single", "E: second curated triple")
	var after := PieceSequence.new()
	after.configure([], config, 5)
	_expect(_ids(mixed.next_set()) == _ids(after.set_at(2)), "E: then generated sets")
	var legacy := PieceSequence.new()
	legacy.configure(curated)
	legacy.next_set()
	legacy.next_set()
	_expect(_ids(legacy.next_set()) == "single,single,square_2", "E: without a config the curated triples still loop")

	# F: every campaign expedition uses its chapter config, and the seed is stable.
	for index in CHAPTER_PATHS.size():
		var chapter := load(CHAPTER_PATHS[index]) as ChapterDefinition
		for expedition in chapter.expeditions:
			_expect(expedition.piece_generation != null and expedition.piece_generation.resource_path == CONFIG_PATHS[index],
				"F: %s uses %s" % [expedition.id, CONFIG_PATHS[index]])
			_expect(expedition.validate().is_empty(), "F: %s validates" % expedition.id)
	_expect(PieceSequence.seed_for("expedition_01") == PieceSequence.seed_for("expedition_01"), "F: seed is stable")
	_expect(PieceSequence.seed_for("expedition_01") != PieceSequence.seed_for("expedition_02"), "F: seeds differ per expedition")

	# G: through the real placement path, every refill equals what the Hint
	# simulation predicted for that move.
	var game := (load("res://scenes/screens/game_screen_ch2_03.tscn") as PackedScene).instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	var session := game.get_node("GameSession") as GameSession
	var refills_checked := 0
	for turn in 40:
		var hint := session.find_best_hint()
		if hint.is_empty():
			break
		var slot_index := int(hint.slot_index)
		var origin: Vector2i = hint.origin
		var last_piece := session.piece_tray.get_active_slot_indices().size() == 1
		var predicted := session._simulate_hint_move(
			session._capture_hint_search_state(), slot_index, session.piece_tray.get_definition(slot_index), origin)
		if predicted.get("invalid", false) or predicted.get("completes_expedition", false):
			break
		_expect(session.try_place_piece(slot_index, origin), "G: hint move %d places" % turn)
		while session.is_turn_resolving():
			await process_frame
		if session.is_no_moves_state():
			break
		if last_piece:
			var expected: Array[PieceDefinition] = []
			expected.assign(predicted.next_state.tray_state)
			var live: Array[PieceDefinition] = session.piece_tray.capture_state()
			_expect(_ids(live) == _ids(expected), "G: real refill after turn %d = planner prediction (%s vs %s)" % [turn, _ids(live), _ids(expected)])
			refills_checked += 1
	_expect(refills_checked >= 3, "G: at least three refills were compared (got %d)" % refills_checked)
	root.remove_child(game)
	game.queue_free()
	await process_frame

	if _failures.is_empty():
		print("PIECE_GENERATION_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
