class_name EndlessLobby
extends Control

## Start window of Endless Excavation: records, the Daily Dig with this week's
## stars, buttons for a normal run or today's dig. Layout: scenes/ui/endless_lobby.tscn.

signal play_requested(daily: bool)
signal menu_requested

const WEEKDAYS: Array[String] = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]
const STAR_DONE := Color(1, 1, 1, 1)
const STAR_MISSED := Color(0.35, 0.3, 0.25, 0.45)


func _ready() -> void:
	%PlayButton.pressed.connect(func() -> void: play_requested.emit(false))
	%DailyButton.pressed.connect(func() -> void: play_requested.emit(true))
	%MenuButton.pressed.connect(func() -> void: menu_requested.emit())
	%LeadersButton.pressed.connect(open_leaderboard)


func open_leaderboard() -> void:
	(%LeaderboardPanel as LeaderboardPanel).open()


## today: Time.get_date_dict_from_system() (tests pass their own date).
func refresh(definition: EndlessDefinition, today: Dictionary) -> void:
	%RecordLabel.text = tr("Рекорд: %s · глубина %d м") % [
		GameSession.format_number(ProgressStore.get_endless_best_score()),
		ProgressStore.get_endless_best_depth(),
	]
	%DailyGoal.text = tr("Одни и те же фигуры для всех. Откопайте %d находки.") % definition.daily_goal_finds
	var today_key := ProgressStore.date_key(today)
	var today_unix := Time.get_unix_time_from_datetime_dict(today)
	# Monday .. Sunday of this week; today's star pulses when not done yet.
	var weekday := int(today.get("weekday", Time.get_datetime_dict_from_unix_time(int(today_unix)).weekday))
	var days_from_monday := (weekday + 6) % 7
	var row := %WeekRow
	for index in 7:
		var day_unix := today_unix + (index - days_from_monday) * 86400
		var key := ProgressStore.date_key(Time.get_datetime_dict_from_unix_time(int(day_unix)))
		var day := row.get_child(index)
		var star := day.get_node("Star") as TextureRect
		var label := day.get_node("Label") as Label
		label.text = tr(WEEKDAYS[index])
		star.modulate = STAR_DONE if ProgressStore.is_daily_done(key) else STAR_MISSED
		label.add_theme_color_override("font_color", Color(0.55, 0.3, 0.05) if key == today_key else Color(0.36, 0.27, 0.13))
	var done := ProgressStore.is_daily_done(today_key)
	var best := ProgressStore.get_daily_best(today_key)
	%DailyStatus.text = (
		tr("Сегодня пройден! Лучший счёт дня: %s") % GameSession.format_number(best)
		if done
		else tr("Сегодня ещё не пройден")
	)
	%DailyButton.text = tr("Сыграть ещё раз") if done else tr("Раскоп дня")
