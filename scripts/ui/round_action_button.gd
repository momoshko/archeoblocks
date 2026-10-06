class_name RoundActionButton
extends Button

## Round icon button for Undo / Hint with a small badge in the corner:
## a number (free uses left), a video icon (next use costs an ad) or nothing.
## The full explanation goes to the tooltip, so the button itself has no text.

@onready var badge: Control = $Badge
@onready var count_label: Label = $Badge/CountLabel
@onready var ad_icon: TextureRect = $Badge/AdIcon


## `explanation`: the old button text ("Подсказка · 2"), shown as a tooltip.
## `count` >= 0 shows that number, -1 shows the video icon, -2 hides the badge.
## `count_text` replaces the number (for example "∞").
func show_state(explanation: String, count: int, count_text := "") -> void:
	tooltip_text = explanation
	text = ""
	if not is_node_ready():
		return
	badge.visible = count != -2
	ad_icon.visible = count == -1
	count_label.visible = count >= 0
	count_label.text = count_text if not count_text.is_empty() else str(maxi(count, 0))


func badge_text() -> String:
	if not badge.visible:
		return ""
	return "ad" if ad_icon.visible else count_label.text
