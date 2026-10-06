extends SceneTree

## Rough difficulty estimate for every campaign expedition: plays each one many
## times with a bot (no Undo, no Hint) and prints the win rate and move counts.
##
## Run (headless, from the project folder):
##   Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tools/difficulty_probe.gd
## Options after `--`:
##   --runs=12          games per expedition (default 10)
##   --chapter=2        only this chapter
##   --level=2-3,2-4    only these expeditions
##   --policy=player    casual  - no lookahead, likes lines and digging, ignores the goal
##                      careful - casual, but avoids moves that leave no legal placement
##                      smart   - one of the three best moves by the Hint's one-step value
##                      player  - reads the objective: fills rows/columns that cross
##                                unexcavated finds, avoids dead ends (default; the
##                                reference for the M4.1 targets)
##   --careful          same as --policy=careful
##   --seed=123         try another piece_seed (in memory only; for seed scans)
##   --seed-scan=8      play the layout with 8 other seeds and print the average: shows
##                      how hard the layout is, and which seed fits the target
##   --sites            only the site preparation levels (--digs: only excavations)
##   --verbose          print the board and the tray of every lost game
##   --hard-mods=soil,stones,pieces  which Hard changes are on (default: all)
##   --difficulty=2     play on Easy (0), Medium (1, default) or Hard (2) and print
##                      a "LIMIT <id> <moves>" line: the suggested Hard move limit
##                      (80th percentile of the bot's winning games + 2)
## Debug builds only (uses the validation move applicator).
## Output: one "PROBE ..." line per expedition (and "LAYOUT ..." with --seed-scan);
## the M4.1 targets and results are in GAME_ANALYSIS_M4_RU.md.

const CHAPTERS := [
	"res://resources/chapters/ancient_courtyard.tres",
	"res://resources/chapters/ruined_shrine.tres",
	"res://resources/chapters/overgrown_catacombs.tres",
]
const MAX_MOVES := 120

var _runs := 10
var _policy := "player"
var _only_chapter := 0
var _only_levels: PackedStringArray = []
var _seed_override := 0
var _verbose := false
var _seed_scan := 0
## Only the site preparation levels (--sites) or only the excavations (--digs).
var _sites_only := false
var _digs_only := false
var _game_screen: PackedScene
var _difficulty := 1


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			_runs = int(arg.trim_prefix("--runs="))
		elif arg == "--careful":
			_policy = "careful"
		elif arg.begins_with("--policy="):
			_policy = arg.trim_prefix("--policy=")
		elif arg.begins_with("--chapter="):
			_only_chapter = int(arg.trim_prefix("--chapter="))
		elif arg.begins_with("--level="):
			_only_levels = arg.trim_prefix("--level=").split(",", false)
		elif arg.begins_with("--seed-scan="):
			_seed_scan = int(arg.trim_prefix("--seed-scan="))
		elif arg == "--sites":
			_sites_only = true
		elif arg == "--digs":
			_digs_only = true
		elif arg.begins_with("--hard-mods="):
			var mods := arg.trim_prefix("--hard-mods=").split(",", false)
			Difficulty.hard_deeper_soil = mods.has("soil")
			Difficulty.hard_stronger_stones = mods.has("stones")
			Difficulty.hard_piece_weights = mods.has("pieces")
		elif arg.begins_with("--difficulty="):
			_difficulty = int(arg.trim_prefix("--difficulty="))
		elif arg == "--verbose":
			_verbose = true
		elif arg.begins_with("--seed="):
			_seed_override = int(arg.trim_prefix("--seed="))
	call_deferred("_run")


func _run() -> void:
	OnboardingTutorial.auto_start = false
	Difficulty.override_level = _difficulty
	_game_screen = load("res://scenes/screens/game_screen.tscn")
	for chapter_index in CHAPTERS.size():
		if _only_chapter > 0 and chapter_index + 1 != _only_chapter:
			continue
		var chapter := load(CHAPTERS[chapter_index]) as ChapterDefinition
		for index in chapter.expeditions.size():
			if not _only_levels.is_empty() and not _only_levels.has("%d-%d" % [chapter_index + 1, index + 1]):
				continue
			var kind_is_site: bool = chapter.expeditions[index].is_site_preparation()
			if (_sites_only and not kind_is_site) or (_digs_only and kind_is_site):
				continue
			var seeds: Array[int] = [_seed_override]
			if _seed_scan > 0:
				seeds.clear()
				for k in _seed_scan:
					seeds.append(7919 * (k + 1))
			var layout_wins := 0
			for seed_value in seeds:
				var expedition := chapter.expeditions[index]
				if seed_value != 0:
					expedition = expedition.duplicate() as ExpeditionDefinition
					expedition.piece_seed = seed_value
				var wins := 0
				var win_moves: Array[int] = []
				var loss_moves: Array[int] = []
				for run in _runs:
					var outcome := await _play(chapter, expedition, 1000 * (index + 1) + run)
					if outcome.victory:
						wins += 1
						win_moves.append(outcome.moves)
					else:
						loss_moves.append(outcome.moves)
				layout_wins += wins
				if _difficulty == Difficulty.Level.HARD and not win_moves.is_empty():
					var sorted_moves := win_moves.duplicate()
					sorted_moves.sort()
					var p80: int = sorted_moves[mini(sorted_moves.size() - 1, int(sorted_moves.size() * 0.8))]
					var limit := p80 + 2
					var within := 0
					for value in win_moves:
						if value <= limit:
							within += 1
					print("LIMIT %s %d win_with_limit=%d/%d" % [expedition.id, limit, within, _runs])
				print("PROBE diff=%d policy=%s level=%d-%d seed=%d win=%d/%d win_moves=%s loss_moves=%s | %s | %s" % [
					_difficulty, _policy, chapter_index + 1, index + 1, expedition.resolved_piece_seed(), wins, _runs,
					_summary(win_moves), _summary(loss_moves), expedition.id, expedition.title_ru,
				])
			if _seed_scan > 0:
				print("LAYOUT policy=%s level=%d-%d win=%d/%d (%d%%) over %d seeds" % [
					_policy, chapter_index + 1, index + 1, layout_wins, _runs * seeds.size(),
					roundi(100.0 * layout_wins / (_runs * seeds.size())), seeds.size(),
				])
	quit(0)


func _summary(values: Array[int]) -> String:
	if values.is_empty():
		return "-"
	values.sort()
	var count := values.size()
	return "%d..%d (median %d, middle half %d-%d)" % [
		values[0], values[-1], values[count / 2], values[count / 4], values[mini(count - 1, count * 3 / 4)],
	]


func _play(chapter: ChapterDefinition, expedition: ExpeditionDefinition, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var game := _game_screen.instantiate() as Control
	var session := game.get_node("GameSession") as GameSession
	session.chapter_definition = chapter
	session.expedition_definition = expedition
	root.add_child(game)
	await process_frame
	var victory := false
	while session.moves < MAX_MOVES:
		var moves: Array[Dictionary] = session._enumerate_hint_moves(session._capture_hint_search_state())
		if moves.is_empty():
			break
		var best := _pick_move(moves, rng, session, expedition)
		if best.is_empty():
			best = moves[rng.randi_range(0, moves.size() - 1)]
		var result := session.debug_apply_hint_for_validation(best)
		if result.is_empty():
			break
		if result.completes_expedition:
			victory = true
			break
		if result.immediate_loss:
			break
	var moves_done := session.moves
	if _verbose and not victory:
		_print_board(session, expedition)
	root.remove_child(game)
	game.queue_free()
	await process_frame
	return {"victory": victory, "moves": moves_done}


func _pick_move(
	moves: Array[Dictionary],
	rng: RandomNumberGenerator,
	session: GameSession,
	expedition: ExpeditionDefinition
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for move in moves:
		if _policy != "casual" and bool(move.get("immediate_loss", false)):
			continue
		candidates.append(move)
	if candidates.is_empty():
		candidates = moves
	if _policy == "smart":
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.value) > int(b.value))
		return candidates[rng.randi_range(0, mini(2, candidates.size() - 1))]
	var target_lines := _target_lines(session, expedition) if _policy == "player" else {}
	var best: Dictionary = {}
	var best_value := -INF
	for move in candidates:
		var goal := 0.0
		if _policy == "player":
			goal = (
				_goal_value(move, target_lines)
				+ 1.5 * int(move.get("remaining_legal_moves", 0))
				- 300.0 * int(move.get("blocked_remaining_pieces", 0))
			)
		var value := goal + (
			120.0 * int(move.get("line_count", 0))
			+ 45.0 * int(move.get("artifact_hits", 0))
			+ 12.0 * int(move.get("excavation_hits", 0))
			+ 25.0 * int(move.get("obstacle_hits", 0))
			+ 30.0 * int(move.get("roots_destroyed", 0))
			+ rng.randf_range(0.0, 60.0)
		)
		if value > best_value:
			best_value = value
			best = move
	return best


## Rows ("r3") and columns ("c5") that cross a find that still needs hits,
## mapped to how many of their cells are already filled.
func _target_lines(session: GameSession, expedition: ExpeditionDefinition) -> Dictionary:
	var lines: Dictionary = {}
	var cells: Array[Vector2i] = []
	if expedition.is_site_preparation():
		# Site preparation: every cell with soil or an obstacle is a target.
		for y in 8:
			for x in 8:
				cells.append(Vector2i(x, y))
	else:
		for fragment in expedition.artifact_fragments:
			cells.append_array(fragment.cells)
	for cell in cells:
		if session.excavation_model.get_soil_depth(cell) <= 0 and not session.obstacle_model.has_obstacle(cell):
			continue
		lines["r%d" % cell.y] = _filled(session, Vector2i(0, cell.y), Vector2i(1, 0))
		lines["c%d" % cell.x] = _filled(session, Vector2i(cell.x, 0), Vector2i(0, 1))
	return lines


func _filled(session: GameSession, start: Vector2i, step: Vector2i) -> int:
	var count := 0
	for i in 8:
		var cell := start + step * i
		if not session.board_model.is_empty(cell) or session.obstacle_model.has_obstacle(cell):
			count += 1
	return count


func _goal_value(move: Dictionary, target_lines: Dictionary) -> float:
	var value := 0.0
	for cell: Vector2i in move.get("cells", []):
		for key in ["r%d" % cell.y, "c%d" % cell.x]:
			if target_lines.has(key):
				var filled := float(target_lines[key])
				value += 20.0 * (1.0 + filled * filled / 16.0)
	return value


func _print_board(session: GameSession, expedition: ExpeditionDefinition) -> void:
	var targets: Dictionary = {}
	for fragment in expedition.artifact_fragments:
		for cell in fragment.cells:
			targets[cell] = true
	var tray: PackedStringArray = []
	for piece in session.piece_tray.capture_state():
		tray.append(String(piece.id) if piece != null else "-")
	print("LOST after %d moves, tray: %s   (# block, 1/2 stone, R root, A find under soil, a dug find)" % [session.moves, ", ".join(tray)])
	for y in 8:
		var row := "  "
		for x in 8:
			var cell := Vector2i(x, y)
			var mark := "."
			if session.obstacle_model.is_root(cell):
				mark = "R"
			elif session.obstacle_model.is_stone(cell):
				mark = str(session.obstacle_model.get_durability(cell))
			elif not session.board_model.is_empty(cell):
				mark = "#"
			elif targets.has(cell):
				mark = "A" if session.excavation_model.get_soil_depth(cell) > 0 else "a"
			row += mark
		print(row)
