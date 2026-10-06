class_name PopInMotion
extends Node

## Put this node inside a window scene (pause, victory, rescue...). When its
## parent Control is shown, the window fades in and the panel grows from
## `start_scale` to full size with a light spring. Hiding stays instant, so
## the game logic never waits for an animation.

@export var panel_path: NodePath
@export_range(0.5, 1.0, 0.01) var start_scale := 0.85
@export_range(0.05, 0.6, 0.01) var duration := 0.22
## Sound when the window opens (AudioManager name; silent if the file is missing).
@export var open_sound: StringName = &"popup_open"

var _tween: Tween


func _ready() -> void:
	var window := get_parent() as CanvasItem
	if window != null:
		window.visibility_changed.connect(_on_visibility_changed)
	var panel := _panel()
	if panel != null:
		panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)


func _panel() -> Control:
	return get_node_or_null(panel_path) as Control


func _on_visibility_changed() -> void:
	var window := get_parent() as CanvasItem
	var panel := _panel()
	if window == null or panel == null:
		return
	if _tween != null:
		_tween.kill()
	if not window.visible:
		window.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and not open_sound.is_empty():
		audio.call("play_sfx", open_sound)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * start_scale
	window.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(window, "modulate:a", 1.0, duration * 0.6)
	_tween.tween_property(panel, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
