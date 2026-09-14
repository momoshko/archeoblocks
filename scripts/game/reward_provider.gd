class_name RewardProvider
extends RefCounted

signal reward_granted(request_id: int)
signal reward_failed(request_id: int)


func is_available() -> bool:
	return false


func request_reward(_request_id: int, _reward_type: int) -> void:
	push_error("RewardProvider.request_reward must be implemented by a provider")
