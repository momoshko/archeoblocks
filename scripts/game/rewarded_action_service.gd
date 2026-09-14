class_name RewardedActionService
extends Node

signal reward_granted(request_id: int, reward_type: int)
signal reward_failed(request_id: int, reward_type: int)

enum RewardType {
	UNDO,
	HINT,
	DOUBLE_COINS,
}

@export var debug_mock_succeeds := true

var provider: RewardProvider
var _next_request_id := 1
var _pending_requests: Dictionary = {}
var _consumed_requests: Dictionary = {}


func _ready() -> void:
	if OS.is_debug_build():
		var mock := MockRewardProvider.new()
		mock.should_succeed = debug_mock_succeeds
		set_provider(mock)


func set_provider(value: RewardProvider) -> void:
	if provider != null:
		if provider.reward_granted.is_connected(_on_provider_reward_granted):
			provider.reward_granted.disconnect(_on_provider_reward_granted)
		if provider.reward_failed.is_connected(_on_provider_reward_failed):
			provider.reward_failed.disconnect(_on_provider_reward_failed)
	provider = value
	if provider != null:
		provider.reward_granted.connect(_on_provider_reward_granted)
		provider.reward_failed.connect(_on_provider_reward_failed)


func is_available() -> bool:
	return provider != null and provider.is_available()


func request_reward(reward_type: RewardType) -> int:
	if not is_available():
		return -1
	var request_id := _next_request_id
	_next_request_id += 1
	_pending_requests[request_id] = reward_type
	provider.request_reward(request_id, reward_type)
	return request_id


func _on_provider_reward_granted(request_id: int) -> void:
	if not _pending_requests.has(request_id) or _consumed_requests.has(request_id):
		return
	var reward_type: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_consumed_requests[request_id] = true
	reward_granted.emit(request_id, reward_type)


func _on_provider_reward_failed(request_id: int) -> void:
	if not _pending_requests.has(request_id) or _consumed_requests.has(request_id):
		return
	var reward_type: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_consumed_requests[request_id] = true
	reward_failed.emit(request_id, reward_type)
