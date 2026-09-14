class_name StoneObstacleView
extends Control

@onready var body: Panel = $Body
@onready var intact_tint: ColorRect = $Body/IntactTint
@onready var crack_a: ColorRect = $Body/CrackA
@onready var crack_b: ColorRect = $Body/CrackB

var _durability := 0
var _feedback_tween: Tween


func show_durability(value: int) -> void:
	_stop_feedback()
	_durability = maxi(0, value)
	visible = _durability > 0
	_update_durability_visual()


func clear_obstacle() -> void:
	_stop_feedback()
	_durability = 0
	hide()


func play_hit_feedback(destroyed: bool, duration: float) -> void:
	if not visible:
		return
	_stop_feedback()
	pivot_offset = size * 0.5
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(1.08, 0.92), duration * 0.35)
	_feedback_tween.parallel().tween_property(body, "modulate", Color(1.35, 1.18, 0.9, 1.0), duration * 0.35)
	if destroyed:
		_feedback_tween.tween_property(self, "scale", Vector2(0.72, 0.72), duration * 0.65)
		_feedback_tween.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.65)
		_feedback_tween.tween_callback(clear_obstacle)
	else:
		_feedback_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.65)
		_feedback_tween.parallel().tween_property(body, "modulate", Color.WHITE, duration * 0.65)
		_feedback_tween.tween_callback(_finish_feedback)


func reset_visual() -> void:
	_stop_feedback()
	_durability = 0
	hide()


func get_durability() -> int:
	return _durability


func _update_durability_visual() -> void:
	var reinforced := _durability >= 2
	intact_tint.visible = reinforced
	crack_a.visible = not reinforced
	crack_b.visible = not reinforced


func _finish_feedback() -> void:
	_feedback_tween = null
	scale = Vector2.ONE
	modulate = Color.WHITE
	body.modulate = Color.WHITE


func _stop_feedback() -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
		_feedback_tween = null
	scale = Vector2.ONE
	modulate = Color.WHITE
	if is_instance_valid(body):
		body.modulate = Color.WHITE
