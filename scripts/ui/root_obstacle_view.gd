class_name RootObstacleView
extends Control

@onready var root_body: Control = $RootBody

var _feedback_tween: Tween


func show_root() -> void:
	_stop_feedback()
	show()


func clear_root() -> void:
	_stop_feedback()
	hide()


func play_hit_feedback(destroyed: bool, duration: float) -> void:
	if not visible:
		return
	_stop_feedback()
	pivot_offset = size * 0.5
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "rotation", -0.07, duration * 0.2)
	_feedback_tween.parallel().tween_property(self, "scale", Vector2(1.08, 0.9), duration * 0.2)
	_feedback_tween.tween_property(self, "rotation", 0.06, duration * 0.2)
	if destroyed:
		_feedback_tween.tween_property(self, "scale", Vector2(0.35, 0.35), duration * 0.6)
		_feedback_tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.6)
		_feedback_tween.tween_callback(clear_root)
	else:
		_feedback_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.6)
		_feedback_tween.tween_callback(_finish_feedback)


func play_growth_source_feedback(duration: float) -> void:
	if not visible:
		return
	_stop_feedback()
	pivot_offset = size * 0.5
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(1.08, 1.08), duration * 0.45)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.55)
	_feedback_tween.tween_callback(_finish_feedback)


func play_growth_appear(duration: float) -> void:
	_stop_feedback()
	show()
	pivot_offset = size * 0.5
	scale = Vector2(0.25, 0.25)
	modulate = Color(0.72, 0.9, 0.55, 0.3)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(1.08, 1.08), duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.parallel().tween_property(self, "modulate", Color.WHITE, duration * 0.7)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.3)
	_feedback_tween.tween_callback(_finish_feedback)


func reset_visual() -> void:
	_stop_feedback()
	hide()


func _finish_feedback() -> void:
	_feedback_tween = null
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	root_body.modulate = Color.WHITE


func _stop_feedback() -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
		_feedback_tween = null
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	if is_instance_valid(root_body):
		root_body.modulate = Color.WHITE
