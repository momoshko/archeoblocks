class_name BoardFx
extends Node2D

## Light particle effects over the board (Gemini sprites, see CREDITS.md).
## Dust and stone chips: line clear, soil dug away, stone broken.
## Sparkles, light burst and a glint: a piece of the find is uncovered.
## Every emitter is one-shot with a few particles; a few emitters of each kind
## take turns (a turn can raise dust three times: line, stone, soil), so a new
## burst does not cut the previous one short.
## BoardView calls these with global cell centres; nothing here changes the game.

## Particles per cell, and the most one burst may use.
@export_range(1, 6, 1) var dust_per_cell := 2
@export_range(1, 6, 1) var chips_per_cell := 2
@export_range(1, 6, 1) var shards_per_cell := 2
@export_range(8, 64, 1) var max_particles := 28
@export_range(0.2, 1.5, 0.05) var light_burst_seconds := 0.7

@onready var _dust: Array[CPUParticles2D] = [$Dust, $Dust2, $Dust3]
@onready var _chips: Array[CPUParticles2D] = [$Chips, $Chips2]
@onready var _shards: Array[CPUParticles2D] = [$Shards, $Shards2, $Shards3]
@onready var _sparkles: CPUParticles2D = $Sparkles
@onready var _light_burst: Sprite2D = $LightBurst
@onready var _glint: Sprite2D = $Glint

var _queued_dust := PackedVector2Array()
var _flush_pending := false
var _burst_tween: Tween


func _ready() -> void:
	_light_burst.hide()
	_glint.hide()


## A full row/column: a puff of dust and a few chips along it.
func play_line_clear(points: PackedVector2Array) -> void:
	_emit(_dust, points, dust_per_cell)
	_emit(_chips, _every_other(points), 1)


## A piece lands: a small puff of dust under its blocks.
func play_land(points: PackedVector2Array) -> void:
	_emit(_dust, points, 1)


## Blocks of a full line pop into gem shards of their own colour.
## `points_by_colour`: block colour -> global centres of those blocks.
func play_gem_shards(points_by_colour: Dictionary) -> void:
	var used := 0
	for colour: Color in points_by_colour:
		if used >= _shards.size():
			break
		var emitter := _shards[used]
		# The shard sprites are pale grey glass: tint them light, keep them bright.
		emitter.color = colour.lightened(0.35)
		_emit([emitter], points_by_colour[colour], shards_per_cell)
		used += 1


## Soil dug away under a cleared line. Cells arrive one by one, so they are
## collected and released together at the end of the frame.
func queue_dig(point: Vector2) -> void:
	_queued_dust.append(point)
	if not _flush_pending:
		_flush_pending = true
		_flush_dig.call_deferred()


## A stone is hit (cracks) or broken (falls apart).
func play_stone_break(broken: PackedVector2Array, cracked: PackedVector2Array) -> void:
	if not broken.is_empty():
		_emit(_chips, broken, chips_per_cell * 3)
		_emit(_dust, broken, dust_per_cell)
	elif not cracked.is_empty():
		_emit(_chips, cracked, chips_per_cell)


## A fragment of the find is uncovered: sparkles on its cells, a soft burst
## of light in the middle and a glint sweeping across.
func play_find(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	_emit([_sparkles], points, 2)
	var centre := Vector2.ZERO
	for point in points:
		centre += point
	centre /= points.size()
	var local_centre := to_local(centre)
	if _burst_tween != null:
		_burst_tween.kill()
	_light_burst.position = local_centre
	_light_burst.scale = Vector2.ONE * 0.35
	_light_burst.rotation = randf() * TAU
	_light_burst.modulate.a = 0.0
	_light_burst.show()
	_glint.position = local_centre + Vector2(-70.0, -50.0)
	_glint.modulate.a = 0.0
	_glint.show()
	var half := light_burst_seconds * 0.5
	_burst_tween = create_tween().set_parallel(true)
	_burst_tween.tween_property(_light_burst, "scale", Vector2.ONE * 1.25, light_burst_seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_burst_tween.tween_property(_light_burst, "rotation", _light_burst.rotation + 0.6, light_burst_seconds)
	_burst_tween.tween_property(_light_burst, "modulate:a", 0.9, half * 0.5)
	_burst_tween.tween_property(_light_burst, "modulate:a", 0.0, half).set_delay(half)
	_burst_tween.tween_property(_glint, "position", local_centre + Vector2(70.0, 50.0), light_burst_seconds * 0.8).set_delay(0.1)
	_burst_tween.tween_property(_glint, "modulate:a", 1.0, 0.12).set_delay(0.1)
	_burst_tween.tween_property(_glint, "modulate:a", 0.0, 0.25).set_delay(light_burst_seconds * 0.6)
	_burst_tween.chain().tween_callback(_hide_find_sprites)


func clear() -> void:
	if not is_node_ready():
		return
	_queued_dust.clear()
	for emitter in _dust + _chips + _shards + [_sparkles]:
		emitter.emitting = false
	if _burst_tween != null:
		_burst_tween.kill()
	_hide_find_sprites()


func _flush_dig() -> void:
	_flush_pending = false
	if _queued_dust.is_empty():
		return
	_emit(_dust, _queued_dust, dust_per_cell)
	_queued_dust = PackedVector2Array()


func _hide_find_sprites() -> void:
	_light_burst.hide()
	_glint.hide()


## Restarts the free (or the oldest) emitter of a kind at the given global points.
func _emit(pool: Array, global_points: PackedVector2Array, per_point: int) -> void:
	if global_points.is_empty():
		return
	var emitter: CPUParticles2D = pool[0]
	for candidate: CPUParticles2D in pool:
		if not candidate.emitting:
			emitter = candidate
			break
	if emitter == pool[0] and pool.size() > 1 and pool[0].emitting:
		# Both busy: reuse the first one and move it to the back of the queue.
		pool.push_back(pool.pop_front())
	var local_points := PackedVector2Array()
	for point in global_points:
		local_points.append(emitter.to_local(point))
	emitter.emission_points = local_points
	var count := clampi(global_points.size() * per_point, 4, max_particles)
	if emitter.amount != count:
		emitter.amount = count
	emitter.restart()


func _every_other(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in points.size():
		if index % 2 == 0:
			result.append(points[index])
	return result
