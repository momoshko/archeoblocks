class_name YandexRewardProvider
extends RewardProvider

## Rewarded video through the platform layer. The reward is granted only when
## the platform confirms it (onRewarded); closing early or any error fails.


func is_available() -> bool:
	var platform := _platform()
	return platform != null and platform.is_available()


func request_reward(request_id: int, _reward_type: int) -> void:
	_show(request_id)


func _show(request_id: int) -> void:
	var platform := _platform()
	var rewarded := false
	if platform != null:
		rewarded = await platform.show_rewarded()
	if rewarded:
		reward_granted.emit(request_id)
	else:
		reward_failed.emit(request_id)


# Looked up at runtime so this class also compiles where autoloads are not registered yet.
static func _platform() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Platform") if tree != null else null
