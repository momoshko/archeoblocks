class_name ActionFeedback
extends Control

@export_range(0.2, 2.0, 0.1) var display_seconds := 0.85
@onready var message_label: Label = $Center/MessagePanel/Message

var _tween: Tween
var _queue: Array[Dictionary] = []
var _playing := false


func clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_queue.clear()
	_playing = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	hide()


func show_message(message: String, strong := false) -> void:
	_queue.append({"message": message, "strong": strong})
	if not _playing:
		_play_next()


func show_unique_message(message: String, strong := false) -> void:
	for index in range(_queue.size() - 1, -1, -1):
		if _queue[index].message == message:
			_queue.remove_at(index)
	if _playing and message_label.text == message:
		_restart_current(message, strong)
		return
	show_message(message, strong)


func queued_message_count() -> int:
	return _queue.size()


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		hide()
		return
	_playing = true
	var item: Dictionary = _queue.pop_front()
	message_label.text = item.message
	modulate = Color.WHITE
	show()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * (0.88 if item.strong else 0.94)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * (1.08 if item.strong else 1.0), 0.18)
	_tween.tween_interval(display_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(_finish_current)


func _restart_current(message: String, strong: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_playing = false
	_queue.push_front({"message": message, "strong": strong})
	_play_next()


func _finish_current() -> void:
	_tween = null
	modulate = Color.WHITE
	scale = Vector2.ONE
	hide()
	_play_next()
