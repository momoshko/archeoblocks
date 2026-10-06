class_name EndlessDefinition
extends Resource

## Rules of Endless Excavation (resources/endless/endless_default.tres).
## The run goes on until no piece fits. Every `lines_per_meter` cleared lines
## take the dig one metre deeper; deeper layers bring heavier pieces.

@export var id: StringName = &"endless"
@export var title_ru := "Бесконечные раскопки"
@export var instruction_ru := "Собирайте линии подряд: серия умножает очки"
## Layers from the surface down. The first one must start at depth 0.
@export var layers: Array[EndlessLayer] = []
@export_range(1, 100, 1) var lines_per_meter := 10
## Moves allowed between two line moves before the streak ends.
@export_range(1, 10, 1) var streak_grace_moves := 3
## Streak multiplier grows by this much per line move (x1, x1.5, x2 ...).
@export_range(0.0, 2.0, 0.05) var streak_step := 0.5
@export_range(1.0, 10.0, 0.5) var streak_max_multiplier := 4.0
## Bonus for a move that leaves the board without blocks (times the streak multiplier).
@export_range(0, 10000, 50) var board_clear_bonus := 1000
## Dig spots: a find under the soil appears after this many cleared lines.
@export_range(1, 100, 1) var find_every_lines := 8
## Moves to dig a spot up before the soil caves in.
@export_range(2, 40, 1) var spot_moves := 12
## Points for a dug-up find (times the streak multiplier; twice for a deep spot).
@export_range(0, 10000, 50) var spot_bonus := 300
## From this depth the spots have strong soil (two hits).
@export_range(0, 999, 1) var deep_spot_from_depth := 8
## How many spots can wait on the board at once.
@export_range(1, 4, 1) var max_spots := 1
## Daily Dig: the same pieces for everyone today; the goal is this many finds.
@export_range(1, 20, 1) var daily_goal_finds := 3
@export_range(1, 100, 1) var daily_find_every_lines := 4
@export_range(0, 10000, 50) var daily_goal_bonus := 1000
## The main menu unlocks the mode after this campaign expedition.
@export var unlock_expedition_id: StringName = &"expedition_03"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if layers.is_empty():
		errors.append("endless mode needs at least one layer")
		return errors
	var previous_depth := -1
	for index in layers.size():
		var layer := layers[index]
		if layer == null:
			errors.append("endless layers contain a null entry")
			continue
		errors.append_array(layer.validate())
		if index == 0 and layer.from_depth != 0:
			errors.append("the first endless layer must start at depth 0")
		if layer.from_depth <= previous_depth:
			errors.append("endless layers must go deeper in order")
		previous_depth = layer.from_depth
	return errors


## Seed of the Daily Dig for a date key "YYYY-MM-DD": the same for every player.
static func daily_seed(date_key: String) -> int:
	return int(hash("archeoblocks-daily-" + date_key) & 0x7fffffff) | 1


func depth_for_lines(total_lines: int) -> int:
	return maxi(0, total_lines) / maxi(1, lines_per_meter)


## Index of the layer the given depth belongs to.
func layer_index_for_depth(depth: int) -> int:
	var result := 0
	for index in layers.size():
		if layers[index] != null and depth >= layers[index].from_depth:
			result = index
	return result


func layer_for_depth(depth: int) -> EndlessLayer:
	if layers.is_empty():
		return null
	return layers[layer_index_for_depth(depth)]
