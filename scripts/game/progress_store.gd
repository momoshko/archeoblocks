class_name ProgressStore
extends RefCounted

const DEFAULT_STORAGE_PATH := "user://progress.cfg"
const EXPEDITIONS_SECTION := "completed_expeditions"
const CHAPTER_REWARDS_SECTION := "chapter_rewards"
const WALLET_SECTION := "wallet"
const COINS_KEY := "coins"
const RECORDS_SECTION := "records"
const RESTORED_SECTION := "restored_artifacts"
const ENDLESS_BEST_SCORE_KEY := "endless_best_score"
const ENDLESS_BEST_DEPTH_KEY := "endless_best_depth"
const ENDLESS_RUNS_KEY := "endless_runs"

## Daily Dig: date "YYYY-MM-DD" -> best score of that day / goal reached that day.
const DAILY_BEST_SECTION := "daily_best"
const DAILY_DONE_SECTION := "daily_done"

## Campaign progress per difficulty (Difficulty.Level): Easy keeps the old
## section names, so saves from before difficulties count as Easy.
const EXPEDITIONS_SECTIONS: Array[String] = [
	"completed_expeditions", "completed_expeditions_medium", "completed_expeditions_hard",
]
const CHAPTER_REWARDS_SECTIONS: Array[String] = [
	"chapter_rewards", "chapter_rewards_medium", "chapter_rewards_hard",
]
const PLAYER_SECTION := "player"
const DIFFICULTY_KEY := "difficulty"

const META_SECTION := "meta"
const SAVE_VERSION_KEY := "save_version"
const SAVE_VERSION := 1

static var storage_path := DEFAULT_STORAGE_PATH
## Called after every successful progress save (cloud mirror hooks in here).
static var changed_hook: Callable


static func mark_expedition_completed(expedition_id: StringName, level: int = -1) -> Error:
	if expedition_id == &"":
		return ERR_INVALID_PARAMETER
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return directory_error
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(_expeditions_section(level), String(expedition_id), true)
	return _save(config)


## Completed on the current difficulty (or the given one).
static func is_expedition_completed(expedition_id: StringName, level: int = -1) -> bool:
	if expedition_id == &"":
		return false
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return false
	return config.get_value(_expeditions_section(level), String(expedition_id), false)


## Completed on any difficulty (collection, tutorial, Endless unlock).
static func is_expedition_completed_any(expedition_id: StringName) -> bool:
	return highest_difficulty_completed(expedition_id) >= 0


## -1 when never completed, otherwise the highest Difficulty.Level.
static func highest_difficulty_completed(expedition_id: StringName) -> int:
	if expedition_id == &"":
		return -1
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return -1
	for level in range(EXPEDITIONS_SECTIONS.size() - 1, -1, -1):
		if config.get_value(EXPEDITIONS_SECTIONS[level], String(expedition_id), false):
			return level
	return -1


## Completed expeditions of the current difficulty (or the given one).
static func completed_expeditions(level: int = -1) -> Dictionary:
	return completed_expeditions_for(_resolve_level(level))


static func completed_expeditions_for(level: int) -> Dictionary:
	var completed := {}
	var section := EXPEDITIONS_SECTIONS[clampi(level, 0, EXPEDITIONS_SECTIONS.size() - 1)]
	var config := ConfigFile.new()
	if config.load(storage_path) != OK or not config.has_section(section):
		return completed
	for key in config.get_section_keys(section):
		if config.get_value(section, key, false):
			completed[StringName(key)] = true
	return completed


static func get_selected_difficulty() -> int:
	return clampi(int(_load_value(PLAYER_SECTION, DIFFICULTY_KEY, 0)), 0, EXPEDITIONS_SECTIONS.size() - 1)


static func set_selected_difficulty(level: int) -> Error:
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return directory_error
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(PLAYER_SECTION, DIFFICULTY_KEY, clampi(level, 0, EXPEDITIONS_SECTIONS.size() - 1))
	return _save(config)


static func _resolve_level(level: int) -> int:
	if level >= 0:
		return clampi(level, 0, EXPEDITIONS_SECTIONS.size() - 1)
	return Difficulty.current()


static func _expeditions_section(level: int) -> String:
	return EXPEDITIONS_SECTIONS[_resolve_level(level)]


static func _chapter_rewards_section(level: int) -> String:
	return CHAPTER_REWARDS_SECTIONS[_resolve_level(level)]


static func claim_chapter_reward(
	chapter_id: StringName,
	expedition_ids: Array[StringName],
	reward_coins: int,
	level: int = -1
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
	var expeditions_section := _expeditions_section(level)
	var rewards_section := _chapter_rewards_section(level)
	for expedition_id in expedition_ids:
		if not config.get_value(expeditions_section, String(expedition_id), false):
			return result
	if config.get_value(rewards_section, String(chapter_id), false):
		return result
	var balance := int(config.get_value(WALLET_SECTION, COINS_KEY, 0))
	config.set_value(rewards_section, String(chapter_id), true)
	config.set_value(WALLET_SECTION, COINS_KEY, balance + reward_coins)
	var save_error := _save(config)
	if save_error != OK:
		result.error = save_error
		return result
	result.granted = true
	result.coins = reward_coins
	return result


static func is_chapter_reward_claimed(chapter_id: StringName, level: int = -1) -> bool:
	if chapter_id == &"":
		return false
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return false
	return config.get_value(_chapter_rewards_section(level), String(chapter_id), false)


static func get_coin_balance() -> int:
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return 0
	return int(config.get_value(WALLET_SECTION, COINS_KEY, 0))


## Endless Excavation: stores a finished run and returns the records.
## Result keys: best_score, best_depth, runs, new_score_record, new_depth_record, error.
static func submit_endless_run(run_score: int, run_depth: int) -> Dictionary:
	var result := {
		"best_score": 0,
		"best_depth": 0,
		"runs": 0,
		"new_score_record": false,
		"new_depth_record": false,
		"error": OK,
	}
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		result.error = directory_error
		return result
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		result.error = load_error
		return result
	var best_score := int(config.get_value(RECORDS_SECTION, ENDLESS_BEST_SCORE_KEY, 0))
	var best_depth := int(config.get_value(RECORDS_SECTION, ENDLESS_BEST_DEPTH_KEY, 0))
	var runs := int(config.get_value(RECORDS_SECTION, ENDLESS_RUNS_KEY, 0)) + 1
	result.new_score_record = run_score > best_score
	result.new_depth_record = run_depth > best_depth
	best_score = maxi(best_score, maxi(0, run_score))
	best_depth = maxi(best_depth, maxi(0, run_depth))
	config.set_value(RECORDS_SECTION, ENDLESS_BEST_SCORE_KEY, best_score)
	config.set_value(RECORDS_SECTION, ENDLESS_BEST_DEPTH_KEY, best_depth)
	config.set_value(RECORDS_SECTION, ENDLESS_RUNS_KEY, runs)
	result.best_score = best_score
	result.best_depth = best_depth
	result.runs = runs
	result.error = _save(config)
	return result


## Daily Dig: stores the best score of the day and whether the goal was reached.
## Result keys: best_score, new_record, done, error.
static func submit_daily_run(day: String, run_score: int, goal_reached: bool) -> Dictionary:
	var result := {"best_score": 0, "new_record": false, "done": false, "error": OK}
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		result.error = directory_error
		return result
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		result.error = load_error
		return result
	var best := int(config.get_value(DAILY_BEST_SECTION, day, 0))
	result.new_record = run_score > best
	best = maxi(best, maxi(0, run_score))
	config.set_value(DAILY_BEST_SECTION, day, best)
	var done := bool(config.get_value(DAILY_DONE_SECTION, day, false)) or goal_reached
	if done:
		config.set_value(DAILY_DONE_SECTION, day, true)
	result.best_score = best
	result.done = done
	result.error = _save(config)
	return result


static func is_daily_done(day: String) -> bool:
	return bool(_load_value(DAILY_DONE_SECTION, day, false))


static func get_daily_best(day: String) -> int:
	return int(_load_value(DAILY_BEST_SECTION, day, 0))


## "YYYY-MM-DD" for a date dictionary (Time.get_date_dict_from_system()).
static func date_key(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]


## Restoration: the find was cleaned by the player (see RESTORATION_RU.md).
static func mark_artifact_restored(artifact_id: StringName) -> Error:
	if artifact_id == &"":
		return ERR_INVALID_PARAMETER
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return directory_error
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	config.set_value(RESTORED_SECTION, String(artifact_id), true)
	return _save(config)


static func is_artifact_restored(artifact_id: StringName) -> bool:
	if artifact_id == &"":
		return false
	return bool(_load_value(RESTORED_SECTION, String(artifact_id), false))


static func get_endless_best_score() -> int:
	return int(_load_value(RECORDS_SECTION, ENDLESS_BEST_SCORE_KEY, 0))


static func get_endless_best_depth() -> int:
	return int(_load_value(RECORDS_SECTION, ENDLESS_BEST_DEPTH_KEY, 0))


## Whole progress as plain data (cloud save format).
static func export_state() -> Dictionary:
	var config := ConfigFile.new()
	config.load(storage_path)
	var state := {
		SAVE_VERSION_KEY: SAVE_VERSION,
		DIFFICULTY_KEY: int(config.get_value(PLAYER_SECTION, DIFFICULTY_KEY, 0)),
		RESTORED_SECTION: _section_flags(config, RESTORED_SECTION),
		DAILY_DONE_SECTION: _section_flags(config, DAILY_DONE_SECTION),
		COINS_KEY: int(config.get_value(WALLET_SECTION, COINS_KEY, 0)),
		RECORDS_SECTION: {
			ENDLESS_BEST_SCORE_KEY: int(config.get_value(RECORDS_SECTION, ENDLESS_BEST_SCORE_KEY, 0)),
			ENDLESS_BEST_DEPTH_KEY: int(config.get_value(RECORDS_SECTION, ENDLESS_BEST_DEPTH_KEY, 0)),
			ENDLESS_RUNS_KEY: int(config.get_value(RECORDS_SECTION, ENDLESS_RUNS_KEY, 0)),
		},
	}
	for section in EXPEDITIONS_SECTIONS + CHAPTER_REWARDS_SECTIONS:
		state[section] = _section_flags(config, section)
	return state


## Merges progress from another device/cloud: completed things never get lost,
## coins keep the larger balance. Does not call changed_hook.
static func merge_state(remote: Dictionary) -> Error:
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return directory_error
	var config := ConfigFile.new()
	var load_error := config.load(storage_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return load_error
	var flag_sections: Array[String] = [RESTORED_SECTION, DAILY_DONE_SECTION]
	flag_sections.append_array(EXPEDITIONS_SECTIONS)
	flag_sections.append_array(CHAPTER_REWARDS_SECTIONS)
	for section in flag_sections:
		var flags: Variant = remote.get(section, {})
		if flags is Dictionary:
			for key in flags:
				if bool(flags[key]):
					config.set_value(section, String(key), true)
	# The chosen difficulty: the higher one wins (it is only ever unlocked forward).
	var remote_difficulty := clampi(int(remote.get(DIFFICULTY_KEY, 0)), 0, EXPEDITIONS_SECTIONS.size() - 1)
	config.set_value(PLAYER_SECTION, DIFFICULTY_KEY, maxi(int(config.get_value(PLAYER_SECTION, DIFFICULTY_KEY, 0)), remote_difficulty))
	var remote_coins := int(remote.get(COINS_KEY, 0))
	var local_coins := int(config.get_value(WALLET_SECTION, COINS_KEY, 0))
	config.set_value(WALLET_SECTION, COINS_KEY, maxi(local_coins, remote_coins))
	# Records keep the best value from either side.
	var remote_records: Variant = remote.get(RECORDS_SECTION, {})
	if remote_records is Dictionary:
		for key in [ENDLESS_BEST_SCORE_KEY, ENDLESS_BEST_DEPTH_KEY, ENDLESS_RUNS_KEY]:
			var local_value := int(config.get_value(RECORDS_SECTION, key, 0))
			config.set_value(RECORDS_SECTION, key, maxi(local_value, int(remote_records.get(key, 0))))
	config.set_value(META_SECTION, SAVE_VERSION_KEY, SAVE_VERSION)
	return config.save(storage_path)


static func _load_value(section: String, key: String, default_value: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return default_value
	return config.get_value(section, key, default_value)


static func _section_flags(config: ConfigFile, section: String) -> Dictionary:
	var flags := {}
	if config.has_section(section):
		for key in config.get_section_keys(section):
			if bool(config.get_value(section, key, false)):
				flags[key] = true
	return flags


static func _save(config: ConfigFile) -> Error:
	config.set_value(META_SECTION, SAVE_VERSION_KEY, SAVE_VERSION)
	var error := config.save(storage_path)
	if error == OK and changed_hook.is_valid():
		changed_hook.call()
	return error


static func _ensure_storage_directory() -> Error:
	var directory_path := ProjectSettings.globalize_path(storage_path).get_base_dir()
	if DirAccess.dir_exists_absolute(directory_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(directory_path)
