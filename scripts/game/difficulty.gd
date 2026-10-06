class_name Difficulty
extends RefCounted

## Three playthroughs of the campaign (see TODO.md, M6):
## Easy is open from the start, Medium opens after the whole campaign on Easy,
## Hard after Medium. Each has its own campaign progress; a find gets a medal
## (bronze / silver / gold) for the highest difficulty it was dug up on.
## Endless Excavation and restoration do not depend on difficulty.
##
## What changes (campaign only):
## - free Undo / Hint per level;
## - piece weights: Easy favours small pieces;
## - Easy: strong soil and reinforced stones are one layer weaker;
##   Hard: soil over the find is one layer deeper;
##   (Hard large pieces and reinforced stones exist but are off: with them the
##   bot won 1 game in 15-30 on chapter II/III, see GAME_ANALYSIS_M4_RU.md §7);
## - Hard: a move limit (ExpeditionDefinition.hard_move_limit or a formula);
## - score x2 on Hard.

enum Level { EASY, MEDIUM, HARD }

const COUNT := 3
const NAMES_RU: Array[String] = ["Лёгкая", "Средняя", "Сложная"]
const MEDAL_NAMES_RU: Array[String] = ["Бронза", "Серебро", "Золото"]
## Only Hard doubles the score: medals, not points, are the reward for replaying.
const SCORE_MULTIPLIERS: Array[float] = [1.0, 1.0, 2.0]
const FREE_UNDOS: Array[int] = [3, 1, 0]
const FREE_HINTS: Array[int] = [3, 1, 0]
## Hard move limit when the level has no hand-set one: expected_moves_max * this.
const HARD_LIMIT_FACTOR := 1.6
const HARD_LIMIT_MIN := 12

## Overrides the saved choice (tests, difficulty probe). -1 = use the save.
## Headless runs (tests, probes) play the tuned Medium balance unless they set it.
static var override_level := Level.MEDIUM if DisplayServer.get_name() == "headless" else -1
## Which Hard changes are on (the difficulty probe switches them to compare;
## stones and pieces were too much together with the move limit).
static var hard_deeper_soil := true
static var hard_stronger_stones := false
static var hard_piece_weights := false


static func current() -> int:
	if override_level >= 0:
		return clampi(override_level, 0, COUNT - 1)
	return ProgressStore.get_selected_difficulty()


static func select(level: int) -> void:
	if is_unlocked(level):
		ProgressStore.set_selected_difficulty(level)


static func name_ru(level: int) -> String:
	return NAMES_RU[clampi(level, 0, COUNT - 1)]


## Easy is always open; the next one opens when the whole campaign is done on
## the previous one.
static func is_unlocked(level: int) -> bool:
	if level <= Level.EASY:
		return true
	if level >= COUNT:
		return false
	return is_campaign_complete(level - 1)


static func is_campaign_complete(level: int) -> bool:
	var completed := ProgressStore.completed_expeditions_for(level)
	for chapter in CampaignRoute.chapters():
		for dig in chapter.dig_expeditions():
			if not completed.has(dig.id):
				return false
	return true


static func score_multiplier(level: int = -1) -> float:
	return SCORE_MULTIPLIERS[_resolve(level)]


## A copy of the help config with this difficulty's free Undo / Hint.
static func help_config_for(base: HelpConfig, level: int = -1) -> HelpConfig:
	if base == null:
		return null
	var resolved := _resolve(level)
	if resolved == Level.MEDIUM:
		return base
	var copy := base.duplicate() as HelpConfig
	copy.free_undos = FREE_UNDOS[resolved]
	copy.free_hints = FREE_HINTS[resolved]
	return copy


## A copy of the piece weights tuned for the difficulty (Medium: unchanged).
static func piece_generation_for(base: PieceGenerationConfig, level: int = -1) -> PieceGenerationConfig:
	if base == null:
		return null
	var resolved := _resolve(level)
	if resolved == Level.MEDIUM or (resolved == Level.HARD and not hard_piece_weights):
		return base
	var copy := base.duplicate() as PieceGenerationConfig
	var weights := PackedFloat32Array(base.weights)
	for index in mini(weights.size(), base.pieces.size()):
		var piece := base.pieces[index]
		if piece == null:
			continue
		weights[index] *= _size_weight(piece.cells.size(), resolved)
	copy.weights = weights
	return copy


static func _size_weight(cells: int, level: int) -> float:
	if level == Level.EASY:
		if cells <= 3:
			return 1.6
		if cells == 4:
			return 1.0
		return 0.55
	# Hard
	if cells <= 2:
		return 0.6
	if cells == 3:
		return 0.85
	if cells == 4:
		return 1.1
	return 1.45


## Applies the soil and stone changes to freshly loaded models.
static func apply_to_models(
	excavation: ExcavationModel,
	obstacles: ObstacleModel,
	level: int = -1
) -> void:
	var resolved := _resolve(level)
	if resolved == Level.MEDIUM:
		return
	for y in ExcavationModel.HEIGHT:
		for x in ExcavationModel.WIDTH:
			var cell := Vector2i(x, y)
			var depth := excavation.get_soil_depth(cell)
			if depth <= 0:
				continue
			if resolved == Level.EASY and depth >= 2:
				excavation.set_soil_depth(cell, 1)
			elif resolved == Level.HARD and hard_deeper_soil and depth == 1 and excavation.get_artifact_fragment_id(cell) != &"":
				excavation.set_soil_depth(cell, 2)
	for cell: Vector2i in obstacles.get_stone_cells():
		var durability := obstacles.get_durability(cell)
		if resolved == Level.EASY and durability >= 2:
			obstacles.set_obstacle(cell, 1, ObstacleModel.Kind.STONE)
		elif resolved == Level.HARD and hard_stronger_stones and durability == 1:
			obstacles.set_obstacle(cell, 2, ObstacleModel.Kind.STONE)


## Moves allowed on this level, 0 = no limit (Easy, Medium).
static func move_limit(definition: ExpeditionDefinition, level: int = -1) -> int:
	if definition == null or _resolve(level) != Level.HARD:
		return 0
	if definition.hard_move_limit > 0:
		return definition.hard_move_limit
	if definition.expected_moves_max <= 0:
		return 0
	return maxi(HARD_LIMIT_MIN, ceili(definition.expected_moves_max * HARD_LIMIT_FACTOR))


static func _resolve(level: int) -> int:
	return clampi(level if level >= 0 else current(), 0, COUNT - 1)
