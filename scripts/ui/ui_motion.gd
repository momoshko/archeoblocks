extends Node

## Autoload "UiMotion": every button in the game gets a small press animation
## (squeeze while held, spring back on release). Nothing in the layout changes:
## only the button's scale, around its centre.
## A button can opt out with the metadata "no_press_motion" = true.

## How small a held button gets, and how long the squeeze / the spring take.
@export_range(0.8, 1.0, 0.01) var press_scale := 0.94
@export_range(0.02, 0.2, 0.01) var press_seconds := 0.06
@export_range(0.05, 0.4, 0.01) var release_seconds := 0.12

const TWEEN_META := &"_press_tween"

## Buttons held down right now. A container that re-sorts its children resets
## their scale to 1, so a held button is squeezed again if that happens.
var _held: Array[BaseButton] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.get_meta(&"no_press_motion", false):
		return
	if button.button_down.is_connected(_on_button_down):
		return
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: BaseButton) -> void:
	if not _held.has(button):
		_held.append(button)
	_animate(button, Vector2.ONE * press_scale, press_seconds, Tween.TRANS_QUAD)


func _on_button_up(button: BaseButton) -> void:
	_held.erase(button)
	_animate(button, Vector2.ONE, release_seconds, Tween.TRANS_BACK)


func _process(_delta: float) -> void:
	for index in range(_held.size() - 1, -1, -1):
		var button := _held[index]
		if not is_instance_valid(button) or not button.is_inside_tree():
			_held.remove_at(index)
			continue
		var tween: Tween = button.get_meta(TWEEN_META) if button.has_meta(TWEEN_META) else null
		if (tween == null or not tween.is_running()) and not button.scale.is_equal_approx(Vector2.ONE * press_scale):
			button.pivot_offset = button.size * 0.5
			button.scale = Vector2.ONE * press_scale


func _animate(button: BaseButton, target: Vector2, seconds: float, transition: Tween.TransitionType) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if button.has_meta(TWEEN_META):
		var old := button.get_meta(TWEEN_META) as Tween
		if old != null and old.is_valid():
			old.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target, seconds).set_trans(transition).set_ease(Tween.EASE_OUT)
	button.set_meta(TWEEN_META, tween)
