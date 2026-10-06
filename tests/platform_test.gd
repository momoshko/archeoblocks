extends SceneTree

const TEST_PROGRESS_PATH := "res://tests/.platform_progress.cfg"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	OnboardingTutorial.auto_start = false
	# The cloud format of the first playthrough (Easy keeps the old section names).
	Difficulty.override_level = Difficulty.Level.EASY
	ProgressStore.storage_path = ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	DirAccess.remove_absolute(ProgressStore.storage_path)
	var platform := root.get_node("Platform")

	# Outside a Yandex web build the platform layer is inert and boots instantly.
	_expect(not platform.is_available(), "Platform is unavailable outside the web build")
	var started := Time.get_ticks_msec()
	await platform.boot()
	_expect(Time.get_ticks_msec() - started < 1000, "Boot finishes immediately without the SDK")
	_expect(ProgressStore.changed_hook.is_valid(), "Boot connects progress saves to the cloud mirror")
	_expect(not await platform.show_rewarded(), "Rewarded ads grant nothing without the SDK")

	# No interstitial right after a rewarded video (ad stacking).
	var gap := int(platform.INTERSTITIAL_GAP_AFTER_REWARDED_SECONDS * 1000.0)
	_expect(platform.interstitial_allowed_after_rewarded(5000, -1), "Interstitial allowed when no rewarded ad was shown")
	_expect(not platform.interstitial_allowed_after_rewarded(10000 + gap - 1, 10000), "Interstitial skipped right after a rewarded ad")
	_expect(platform.interstitial_allowed_after_rewarded(10000 + gap, 10000), "Interstitial allowed again after the gap")
	await platform.show_interstitial()
	_expect(true, "Interstitial returns at once without the SDK")

	# Save format: version + merge keeps every completion and the larger balance.
	ProgressStore.mark_expedition_completed(&"expedition_01")
	var state := ProgressStore.export_state()
	_expect(int(state.get("save_version", 0)) == ProgressStore.SAVE_VERSION, "Export carries the save version")
	_expect((state.completed_expeditions as Dictionary).has("expedition_01"), "Export lists completed expeditions")
	ProgressStore.merge_state({
		"completed_expeditions": {"expedition_02": true},
		"chapter_rewards": {"ancient_courtyard": true},
		"coins": 150,
	})
	_expect(ProgressStore.is_expedition_completed(&"expedition_01") and ProgressStore.is_expedition_completed(&"expedition_02"), "Merge keeps local and remote completions")
	_expect(ProgressStore.is_chapter_reward_claimed(&"ancient_courtyard"), "Merge keeps claimed chapter rewards")
	_expect(ProgressStore.get_coin_balance() == 150, "Merge keeps the larger coin balance")
	ProgressStore.merge_state({"coins": 10})
	_expect(ProgressStore.get_coin_balance() == 150, "Merge never lowers the balance")

	# Rewarded provider fails cleanly when the platform cannot show ads.
	var provider := YandexRewardProvider.new()
	var outcome := {"granted": 0, "failed": 0}
	provider.reward_granted.connect(func(_id: int) -> void: outcome.granted += 1)
	provider.reward_failed.connect(func(_id: int) -> void: outcome.failed += 1)
	provider.request_reward(7, RewardedActionService.RewardType.HINT)
	await process_frame
	_expect(outcome.granted == 0 and outcome.failed == 1, "Unavailable rewarded ad reports failure")

	# Game screen reports gameplay boundaries and pauses on platform pause.
	var game := load("res://scenes/screens/game_screen_02.tscn").instantiate() as Control
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(platform.is_gameplay_active(), "Entering an expedition starts gameplay")
	platform.paused_by_platform.emit()
	var pause_popup := game.get_node("%PausePopup") as Control
	_expect(pause_popup.visible, "Platform pause opens the pause menu")
	_expect(not platform.is_gameplay_active(), "Pause menu stops gameplay")
	(pause_popup.get_node("%ResumeButton") as Button).pressed.emit()
	_expect(platform.is_gameplay_active(), "Resume starts gameplay again")

	root.remove_child(game)
	game.queue_free()
	await process_frame
	_expect(not platform.is_gameplay_active(), "Leaving the game screen stops gameplay")

	# Rescue popup: the right button leads to the menu, never to the next expedition.
	var popup := load("res://scenes/ui/result_popup.tscn").instantiate() as ResultPopup
	root.add_child(popup)
	await process_frame
	var routes := {"next": 0, "menu": 0}
	popup.next_requested.connect(func() -> void: routes.next += 1)
	popup.menu_requested.connect(func() -> void: routes.menu += 1)
	popup.show_rescue("Фрагменты: 0 / 1", false, false, false)
	popup.next_button.pressed.emit()
	_expect(routes.menu == 1 and routes.next == 0, "Rescue 'В меню' goes to the menu")
	popup.show_victory("Тест")
	popup.next_button.pressed.emit()
	_expect(routes.next == 1, "Victory 'Дальше' goes to the next expedition")
	popup.queue_free()
	await process_frame

	ProgressStore.changed_hook = Callable()
	DirAccess.remove_absolute(ProgressStore.storage_path)
	ProgressStore.storage_path = ProgressStore.DEFAULT_STORAGE_PATH
	if _failures.is_empty():
		print("PLATFORM_TESTS_OK checks=", _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
