class_name LeaderboardPanel
extends Control

## Endless Excavation leaderboard (Yandex): top 10, the player's own place and a
## sign-in button for guests (Yandex keeps scores only for signed-in players).
## Layout: scenes/ui/leaderboard_panel.tscn; data: Platform.fetch_endless_leaderboard().

signal closed

const ME_TINT := Color(1.0, 0.93, 0.7)

var _request := 0


func _ready() -> void:
	%CloseButton.pressed.connect(close)
	%AuthButton.pressed.connect(_authorize)


func open() -> void:
	show()
	move_to_front()
	_show_rows([])
	%MyPlace.hide()
	%AuthButton.hide()
	%Status.text = tr("Загрузка…")
	%Status.show()
	_request += 1
	var request := _request
	var data: Dictionary = await _platform().fetch_endless_leaderboard()
	if request != _request or not is_inside_tree():
		return
	show_data(data)


func close() -> void:
	_request += 1
	hide()
	closed.emit()


## Separate from open() so tests and screenshots can feed their own data.
func show_data(data: Dictionary) -> void:
	var state := String(data.get("state", "offline"))
	var entries: Array = data.get("entries", [])
	_show_rows(entries)
	var me: Dictionary = data.get("me", {})
	%MyPlace.visible = not me.is_empty()
	if not me.is_empty():
		%MyPlace.text = tr("Ваше место: %d · %s") % [int(me.rank), GameSession.format_number(int(me.score))]
	var authorized := bool(data.get("authorized", false))
	%AuthButton.visible = state == "ok" and not authorized
	match state:
		"offline":
			%Status.text = tr("Таблица лидеров работает в Яндекс Играх.")
		"error":
			%Status.text = tr("Не удалось загрузить таблицу. Попробуйте позже.")
		_:
			if entries.is_empty():
				%Status.text = tr("Пока здесь пусто — станьте первым!")
			elif not authorized:
				%Status.text = tr("Ваш рекорд: %s. Войдите в аккаунт Яндекса, чтобы он попал в таблицу.") % GameSession.format_number(ProgressStore.get_endless_best_score())
			else:
				%Status.text = ""
	%Status.visible = not %Status.text.is_empty()


func _show_rows(entries: Array) -> void:
	var rows := %Rows.get_children()
	for index in rows.size():
		var row := rows[index] as Control
		row.visible = index < entries.size()
		if not row.visible:
			continue
		var entry: Dictionary = entries[index]
		var name := String(entry.get("name", ""))
		row.get_node("Line/Rank").text = str(int(entry.get("rank", index + 1)))
		row.get_node("Line/Name").text = name if not name.is_empty() else tr("Игрок")
		row.get_node("Line/Score").text = GameSession.format_number(int(entry.get("score", 0)))
		row.self_modulate = ME_TINT if bool(entry.get("me", false)) else Color.WHITE


func _authorize() -> void:
	%AuthButton.disabled = true
	await _platform().authorize_player()
	%AuthButton.disabled = false
	if is_inside_tree() and visible:
		open()


## Autoload looked up at run time (tools and tests compile UI classes first).
func _platform() -> Node:
	return get_node("/root/Platform")
