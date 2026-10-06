class_name FindCard
extends Button

## One find on the chapter page: its picture (dark until dug up), the three steps
## Site clearing -> Excavation -> Cleaning, and what comes next. Layout lives in
## scenes/ui/find_card.tscn; ChapterDetail decides the states.

enum Step { HIDDEN, LOCKED, NEXT, DONE }

const LOCKED_TINT := Color(1, 1, 1, 0.4)
const SILHOUETTE := Color(0.22, 0.15, 0.09, 0.85)
const NEXT_TEXT := Color(0.3, 0.42, 0.16)
const DONE_TEXT := Color(0.42, 0.29, 0.12)
const LOCKED_TEXT := Color(0.38, 0.36, 0.33)

@onready var _picture: TextureRect = %Picture
@onready var _title: Label = %Title
@onready var _next_label: Label = %NextLabel
@onready var _lock: TextureRect = %LockIcon
@onready var _steps: Array[Control] = [$Margin/Row/Info/Steps/SiteStep, $Margin/Row/Info/Steps/DigStep, $Margin/Row/Info/Steps/CleanStep]


## states: [site, dig, clean] as Step values.
func show_find(title: String, picture: Texture2D, dug: bool, states: Array, next_text: String, locked: bool) -> void:
	_title.text = title
	_picture.texture = picture
	_picture.modulate = Color.WHITE if dug else SILHOUETTE
	for index in _steps.size():
		var state: int = states[index] if index < states.size() else Step.HIDDEN
		var chip := _steps[index]
		chip.visible = state != Step.HIDDEN
		chip.modulate = LOCKED_TINT if state == Step.LOCKED or locked else Color.WHITE
		chip.get_node("Icon/Check").visible = state == Step.DONE
	_next_label.text = next_text
	# Green when something is waiting, brown when the find is finished, grey when closed.
	var finished := states.size() > 2 and int(states[2]) == Step.DONE
	_next_label.add_theme_color_override(
		"font_color",
		LOCKED_TEXT if locked else (DONE_TEXT if finished else NEXT_TEXT)
	)
	_lock.visible = locked
	disabled = locked


## What the card says comes next ("Дальше: раскопка", "Готово", "Закрыто").
func state_text() -> String:
	return _next_label.text
