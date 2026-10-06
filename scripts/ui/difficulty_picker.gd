class_name DifficultyPicker
extends VBoxContainer

## Three difficulty tabs (Лёгкая / Средняя / Сложная) with their medals. A locked
## tab shows a padlock and says what opens it. Layout: scenes/ui/difficulty_picker.tscn.

signal difficulty_changed(level: int)

const DESCRIPTIONS_RU: Array[String] = [
	"3 подсказки и отмены, тонкий грунт, удобные фигуры · бронза",
	"1 подсказка и отмена, обычный грунт · серебро",
	"Грунт над находкой глубже, ходы ограничены, без бесплатных подсказок · очки ×2 · золото",
]
const LOCKED_RU: Array[String] = [
	"",
	"Откроется после прохождения всей игры на лёгкой",
	"Откроется после прохождения всей игры на средней",
]

@onready var _buttons: Array[Button] = [$Buttons/Easy, $Buttons/Medium, $Buttons/Hard]
@onready var _description: Label = %Description


func _ready() -> void:
	for level in _buttons.size():
		_buttons[level].pressed.connect(_on_pressed.bind(level))
	refresh()


func refresh() -> void:
	var current := Difficulty.current()
	for level in _buttons.size():
		var button := _buttons[level]
		var unlocked := Difficulty.is_unlocked(level)
		button.set_pressed_no_signal(level == current)
		# A locked tab stays tappable: it tells what opens it.
		button.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
		button.tooltip_text = tr(DESCRIPTIONS_RU[level]) if unlocked else tr(LOCKED_RU[level])
		button.theme_type_variation = &"ChapterCardDone" if level == current else &"ChapterCard"
		button.get_node("LockIcon").visible = not unlocked
	_description.text = tr(DESCRIPTIONS_RU[current])


func _on_pressed(level: int) -> void:
	if not Difficulty.is_unlocked(level):
		refresh()
		_description.text = tr(LOCKED_RU[level])
		return
	Difficulty.select(level)
	refresh()
	difficulty_changed.emit(level)
