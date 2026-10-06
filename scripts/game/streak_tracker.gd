class_name StreakTracker
extends RefCounted

## Line streak for Endless Excavation.
##
## Every move that clears at least one line adds one step to the streak. After a
## line the player has `grace_moves` moves to clear the next one; when that many
## moves pass without a line, the streak ends. The multiplier for a move's line
## score is 1 + step * (streak - 1), capped at `max_multiplier`:
## 1st line move x1, 2nd x1.5, 3rd x2 ... (with step 0.5).

var grace_moves := 3
var step := 0.5
var max_multiplier := 4.0

var streak := 0
var best_streak := 0
var moves_left := 0


func configure(grace: int, multiplier_step: float, multiplier_cap: float) -> void:
	grace_moves = maxi(1, grace)
	step = maxf(0.0, multiplier_step)
	max_multiplier = maxf(1.0, multiplier_cap)
	reset()


func reset() -> void:
	streak = 0
	best_streak = 0
	moves_left = 0


## Registers one placed piece. Returns the multiplier for this move's line score
## (1.0 when the move cleared nothing).
func register_move(line_count: int) -> float:
	if line_count > 0:
		streak += 1
		best_streak = maxi(best_streak, streak)
		moves_left = grace_moves
		return multiplier()
	if streak > 0:
		moves_left -= 1
		if moves_left <= 0:
			streak = 0
			moves_left = 0
	return 1.0


func multiplier() -> float:
	if streak <= 0:
		return 1.0
	return minf(max_multiplier, 1.0 + step * float(streak - 1))


func is_active() -> bool:
	return streak > 0


func capture_state() -> Dictionary:
	return {"streak": streak, "best_streak": best_streak, "moves_left": moves_left}


func restore_state(state: Dictionary) -> void:
	streak = int(state.get("streak", 0))
	best_streak = int(state.get("best_streak", 0))
	moves_left = int(state.get("moves_left", 0))
