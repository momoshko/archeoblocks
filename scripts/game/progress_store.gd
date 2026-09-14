class_name ProgressStore
extends RefCounted

const DEFAULT_STORAGE_PATH := "user://progress.cfg"
const EXPEDITIONS_SECTION := "completed_expeditions"
const CHAPTER_REWARDS_SECTION := "chapter_rewards"
const WALLET_SECTION := "wallet"
const COINS_KEY := "coins"

static var storage_path := DEFAULT_STORAGE_PATH


static func mark_expedition_completed(expedition_id: StringName) -> Error:
	if expedition_id == &"":
		return ERR_INVALID_PARAMETER
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return directory_error
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(EXPEDITIONS_SECTION, String(expedition_id), true)
	return config.save(storage_path)


static func is_expedition_completed(expedition_id: StringName) -> bool:
	if expedition_id == &"":
		return false
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return false
	return config.get_value(EXPEDITIONS_SECTION, String(expedition_id), false)


static func completed_expeditions() -> Dictionary:
	var completed := {}
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return completed
	for key in config.get_section_keys(EXPEDITIONS_SECTION):
		if config.get_value(EXPEDITIONS_SECTION, key, false):
			completed[StringName(key)] = true
	return completed


static func claim_chapter_reward(
	chapter_id: StringName,
	expedition_ids: Array[StringName],
	reward_coins: int
) -> Dictionary:
	var result := {
		"granted": false,
		"coins": 0,
		"error": OK,
	}
	if chapter_id == &"" or expedition_ids.is_empty() or reward_coins < 0:
		result.error = ERR_INVALID_PARAMETER
		return result
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		result.error = directory_error
		return result
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		result.error = load_error
		return result
	for expedition_id in expedition_ids:
		if not config.get_value(EXPEDITIONS_SECTION, String(expedition_id), false):
			return result
	if config.get_value(CHAPTER_REWARDS_SECTION, String(chapter_id), false):
		return result
	var balance := int(config.get_value(WALLET_SECTION, COINS_KEY, 0))
	config.set_value(CHAPTER_REWARDS_SECTION, String(chapter_id), true)
	config.set_value(WALLET_SECTION, COINS_KEY, balance + reward_coins)
	var save_error := config.save(storage_path)
	if save_error != OK:
		result.error = save_error
		return result
	result.granted = true
	result.coins = reward_coins
	return result


static func is_chapter_reward_claimed(chapter_id: StringName) -> bool:
	if chapter_id == &"":
		return false
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return false
	return config.get_value(CHAPTER_REWARDS_SECTION, String(chapter_id), false)


static func get_coin_balance() -> int:
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return 0
	return int(config.get_value(WALLET_SECTION, COINS_KEY, 0))


static func _ensure_storage_directory() -> Error:
	var directory_path := ProjectSettings.globalize_path(storage_path).get_base_dir()
	if DirAccess.dir_exists_absolute(directory_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(directory_path)
