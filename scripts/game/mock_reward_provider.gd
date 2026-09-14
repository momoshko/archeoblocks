class_name MockRewardProvider
extends RewardProvider

var should_succeed := true


func is_available() -> bool:
	return OS.is_debug_build()


func request_reward(request_id: int, _reward_type: int) -> void:
	if not OS.is_debug_build():
		reward_failed.emit(request_id)
		return
	if should_succeed:
		reward_granted.emit(request_id)
	else:
		reward_failed.emit(request_id)
