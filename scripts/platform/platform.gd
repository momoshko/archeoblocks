extends Node

## Game-facing platform layer. On Yandex Games (web build) it talks to the
## YandexGames plugin; in the editor, tests and other web hosts it stays inert
## and everything works locally. Game code calls only this node.

signal paused_by_platform
signal resumed_by_platform

const CLOUD_PROGRESS_KEY := "progress"
## Technical name of the Endless Excavation leaderboard. Create a leaderboard
## with exactly this name in the Yandex Games console (YANDEX_RELEASE_CHECKLIST.md).
const LEADERBOARD_ENDLESS := "endlessScore"
const LEADERBOARD_TOP := 10
const BOOT_TIMEOUT_SECONDS := 6.0
## No fullscreen ad right after a rewarded video: the player just watched one.
const INTERSTITIAL_GAP_AFTER_REWARDED_SECONDS := 60.0

var _booted := false
var _booting := false
var _loading_ready_sent := false
var _gameplay_active := false
# While our own ad call runs, SDK pause events are the ad itself: mute only,
# do not open the pause menu under the player.
var _ad_in_progress := false
var _last_rewarded_end_msec := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sdk := _sdk()
	if sdk != null:
		sdk.game_paused.connect(_on_sdk_paused)
		sdk.game_resumed.connect(_on_sdk_resumed)


## True only inside a web build where the Yandex SDK bridge exists.
func is_available() -> bool:
	var sdk := _sdk()
	return sdk != null and sdk.is_web() and JavaScriptBridge.get_interface("GodotYandexBridge") != null


## Startup: SDK init and cloud progress merge. Safe to call many times;
## never waits longer than BOOT_TIMEOUT_SECONDS.
func boot() -> void:
	if _booted:
		return
	if _booting:
		while _booting:
			await get_tree().process_frame
		return
	_booting = true
	if is_available():
		var state := {"done": false}
		_boot_async(state)
		var deadline := Time.get_ticks_msec() + int(BOOT_TIMEOUT_SECONDS * 1000.0)
		while not state.done and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not state.done:
			push_warning("Platform boot timed out; continuing with local progress")
	ProgressStore.changed_hook = push_progress
	_booting = false
	_booted = true


## LoadingAPI.ready(): call once, when the first interactive screen is shown.
func notify_loading_ready() -> void:
	if _loading_ready_sent:
		return
	_loading_ready_sent = true
	if is_available():
		_sdk().game_ready()


func gameplay_start() -> void:
	if _gameplay_active:
		return
	_gameplay_active = true
	if is_available():
		_sdk().gameplay_start()


func gameplay_stop() -> void:
	if not _gameplay_active:
		return
	_gameplay_active = false
	if is_available():
		_sdk().gameplay_stop()


func is_gameplay_active() -> bool:
	return _gameplay_active


## Platform interface language ("ru", "en", ...) or "" outside Yandex.
func language() -> String:
	if not is_available():
		return ""
	return _sdk().environment.get_lang()


## Interstitial at a logical pause. Returns after the ad closed (or at once).
func show_interstitial() -> void:
	if not is_available() or _ad_in_progress:
		return
	if not interstitial_allowed_after_rewarded(Time.get_ticks_msec(), _last_rewarded_end_msec):
		return
	var was_active := _gameplay_active
	gameplay_stop()
	_ad_in_progress = true
	await _sdk().ads.show_interstitial_if_available()
	_ad_in_progress = false
	_restore_after_ad(was_active)


## Rewarded video. True only when the platform confirmed the reward.
func show_rewarded() -> bool:
	if not is_available() or _ad_in_progress:
		return false
	var was_active := _gameplay_active
	gameplay_stop()
	_ad_in_progress = true
	var result: Dictionary = await _sdk().ads.show_rewarded()
	_ad_in_progress = false
	_last_rewarded_end_msec = Time.get_ticks_msec()
	_restore_after_ad(was_active)
	return bool(result.get("rewarded", false))


## False while a rewarded video ended less than INTERSTITIAL_GAP_AFTER_REWARDED_SECONDS ago.
static func interstitial_allowed_after_rewarded(now_msec: int, last_rewarded_end_msec: int) -> bool:
	if last_rewarded_end_msec < 0:
		return true
	return now_msec - last_rewarded_end_msec >= int(INTERSTITIAL_GAP_AFTER_REWARDED_SECONDS * 1000.0)


func _restore_after_ad(was_active: bool) -> void:
	# The SDK may leave its pause state on if the tab is hidden; audio follows it.
	if not _sdk().is_platform_paused:
		AudioManager.set_muted_for(&"platform", false)
	if was_active:
		gameplay_start()


## Mirrors local progress to the Yandex cloud (called after every progress save).
func push_progress() -> void:
	if not is_available():
		return
	var payload := {CLOUD_PROGRESS_KEY: ProgressStore.export_state()}
	await _sdk().player.set_data(payload)


## Leaderboards work on Yandex; debug builds elsewhere use the plugin's mock
## (sample players), release builds elsewhere show "only on Yandex Games".
func has_leaderboards() -> bool:
	return is_available() or (OS.is_debug_build() and _sdk() != null)


func is_player_authorized() -> bool:
	if not is_available():
		return OS.is_debug_build() and _sdk() != null
	return _sdk().player.is_authorized()


## Opens the Yandex sign-in dialog; true when the player is signed in after it.
func authorize_player() -> bool:
	if not is_available():
		return is_player_authorized()
	await _sdk().player.open_auth_dialog()
	var ok: bool = _sdk().player.is_authorized()
	if ok:
		submit_endless_best()
	return ok


## Sends the local Endless record (Yandex keeps one score per player; only
## signed-in players can have one). Debounced: at most one request a second.
func submit_endless_best() -> void:
	var best := ProgressStore.get_endless_best_score()
	if best <= 0 or not is_available() or not _sdk().player.is_authorized():
		return
	_sdk().leaderboards.set_score_debounced(LEADERBOARD_ENDLESS, best)


## Top players and the player's own place.
## {state: "ok" | "offline" | "error", entries: [{rank, name, score, me}],
##  me: {rank, score} or {}, authorized: bool}
func fetch_endless_leaderboard() -> Dictionary:
	var result := {"state": "offline", "entries": [], "me": {}, "authorized": false}
	if not has_leaderboards():
		return result
	var sdk := _sdk()
	result.authorized = is_player_authorized()
	var data: Dictionary = await sdk.leaderboards.get_entries(
		LEADERBOARD_ENDLESS,
		{"quantityTop": LEADERBOARD_TOP, "includeUser": result.authorized, "quantityAround": 1}
	)
	if data.is_empty():
		result.state = "error"
		return result
	result.state = "ok"
	var my_id := ""
	if is_available() and result.authorized:
		my_id = sdk.player.get_id()
	var raw: Array = data.get("entries", [])
	# Yandex ranks start at 1; guard against a 0-based source.
	var rank_shift := 0
	for entry: Variant in raw:
		if entry is Dictionary and int(entry.get("rank", 1)) == 0:
			rank_shift = 1
	var entries: Array[Dictionary] = []
	for entry: Variant in raw:
		if not entry is Dictionary:
			continue
		var player: Dictionary = entry.get("player", {})
		var name := String(player.get("publicName", ""))
		var is_me := not my_id.is_empty() and String(player.get("uniqueID", "")) == my_id
		entries.append({
			"rank": int(entry.get("rank", 0)) + rank_shift,
			"name": name,
			"score": int(entry.get("score", 0)),
			"me": is_me,
		})
		if is_me:
			result.me = {"rank": int(entry.get("rank", 0)) + rank_shift, "score": int(entry.get("score", 0))}
	if result.me.is_empty() and data.has("userRank") and int(data.get("userRank", 0)) > 0 and is_available():
		result.me = {"rank": int(data.userRank), "score": ProgressStore.get_endless_best_score()}
	result.entries = entries
	return result


func _boot_async(state: Dictionary) -> void:
	var sdk := _sdk()
	var ok: bool = await sdk.ensure_initialized()
	if ok:
		Locale.apply_platform_language(sdk.environment.get_lang())
		await sdk.player.init()
		var cloud: Dictionary = await sdk.player.get_data()
		var remote: Variant = cloud.get(CLOUD_PROGRESS_KEY, {})
		if remote is Dictionary and not (remote as Dictionary).is_empty():
			ProgressStore.merge_state(remote)
		await sdk.player.set_data({CLOUD_PROGRESS_KEY: ProgressStore.export_state()})
		submit_endless_best()
	state.done = true


func _on_sdk_paused() -> void:
	AudioManager.set_muted_for(&"platform", true)
	if not _ad_in_progress:
		paused_by_platform.emit()


func _on_sdk_resumed() -> void:
	AudioManager.set_muted_for(&"platform", false)
	if not _ad_in_progress:
		resumed_by_platform.emit()


func _sdk() -> YandexGamesNode:
	return get_node_or_null("/root/YandexGames") as YandexGamesNode
