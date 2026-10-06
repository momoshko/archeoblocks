class_name FindGlow
extends Control

## Soft golden light around a find: a slowly turning burst of rays behind it,
## a few sparkles and a glint sweeping across now and then.
## Used by the victory window and the "fragment found" card. The sprites are
## set in scenes/ui/find_glow.tscn; size it in the parent scene with `scale`.

@export_range(4.0, 40.0, 0.5) var turn_seconds := 18.0
@export_range(1.0, 8.0, 0.1) var glint_every_seconds := 2.6
## Fragment card: one short flash instead of a loop.
@export var loop := true

@onready var _glow: TextureRect = $Glow
@onready var _sparkles: CPUParticles2D = $Sparkles
@onready var _glint: TextureRect = $Glint

var _tweens: Array[Tween] = []


func _ready() -> void:
	_glow.pivot_offset = _glow.size * 0.5
	_glint.pivot_offset = _glint.size * 0.5
	visibility_changed.connect(_on_visibility_changed)
	_reset()


func play() -> void:
	stop()
	show()
	_glow.modulate.a = 0.0
	_glow.scale = Vector2.ONE * 0.6
	var appear := _track(create_tween().set_parallel(true))
	appear.tween_property(_glow, "modulate:a", 1.0, 0.35)
	appear.tween_property(_glow, "scale", Vector2.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if loop:
		var turn := _track(create_tween().set_loops())
		turn.tween_property(_glow, "rotation", TAU, turn_seconds).from(0.0)
		var glint := _track(create_tween().set_loops())
		glint.tween_callback(_start_glint)
		glint.tween_interval(glint_every_seconds)
	else:
		appear.tween_property(_glow, "rotation", 0.5, 1.0).from(0.0)
		_start_glint()
	_sparkles.one_shot = not loop
	_sparkles.restart()


func stop() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	if is_node_ready():
		_reset()


func _start_glint() -> void:
	_glint.position = Vector2(-150.0, -110.0) - _glint.size * 0.5
	_glint.modulate.a = 0.0
	var sweep := _track(create_tween().set_parallel(true))
	sweep.tween_property(_glint, "position", Vector2(60.0, 40.0) - _glint.size * 0.5, 0.7).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(_glint, "modulate:a", 1.0, 0.18)
	sweep.tween_property(_glint, "modulate:a", 0.0, 0.3).set_delay(0.4)


func _track(tween: Tween) -> Tween:
	# Finished tweens drop out, so a long loop does not grow the list.
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t != null and t.is_valid())
	_tweens.append(tween)
	return tween


func _reset() -> void:
	_sparkles.emitting = false
	_glow.modulate.a = 0.0
	_glow.rotation = 0.0
	_glint.modulate.a = 0.0


func _on_visibility_changed() -> void:
	# The window was closed: nothing keeps running behind it.
	if not is_visible_in_tree():
		stop()
