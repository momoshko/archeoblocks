class_name RestorationScreen
extends Control

## Restoration of a find (see RESTORATION_RU.md). Every find has its own list
## of stages (ExpeditionDefinition.restoration_stages, by material):
## - soil: brush the earth away;
## - shards: under the soil the find turns out broken; it falls apart and the
##   player drags the pieces onto its outline, the glue seams fade;
## - crust: the scalpel chips off hard lime lumps (several strokes per spot);
## - patina: wipe the dull film with a sponge;
## then the shine and the card. The dirt is drawn by
## resources/shaders/restoration.gdshader over the clean artwork, so a find
## needs no extra pictures. Rubbing stages finish by themselves at ~90 %.

signal stage_changed(stage: int)
signal restoration_finished(artifact_id: StringName)

enum Stage { SOIL, PATINA, SHINE, DONE, SHARDS, CRUST }

const MASK_SIZE := 256
const DIRTY_THRESHOLD := 90          # mask byte above this counts as still dirty
const AUTO_FINISH_SHARE := 0.10      # finish the stage when <= 10 % is left
const SOUND_INTERVAL := 0.12
const SCALPEL_SOUND_INTERVAL := 0.16
## Stage names used in ExpeditionDefinition.restoration_stages.
const STAGE_BY_NAME := {&"shards": Stage.SHARDS, &"soil": Stage.SOIL, &"crust": Stage.CRUST, &"patina": Stage.PATINA}
const DEFAULT_STAGES: Array[StringName] = [&"soil", &"patina"]
## shard_map value for pixels outside the find.
const NO_SHARD := 255
## A shard snaps into place when dropped closer than this (share of the view width).
const SNAP_DISTANCE := 0.09

## Set by the caller before changing to this scene (victory popup, collection).
static var pending_expedition: ExpeditionDefinition
static var pending_return_scene := ""

@export var expedition_definition: ExpeditionDefinition
@export_file("*.tscn") var return_scene_path := "res://scenes/app/main.tscn"
## Brush, scalpel and sponge radius in mask pixels (the mask is 256 x 256).
@export_range(4, 64, 1) var brush_radius := 22
@export_range(4, 64, 1) var scalpel_radius := 13
@export_range(4, 64, 1) var sponge_radius := 26
## How much one touch removes (0..1); lower = more rubbing. The crust is hard:
## a spot needs several scalpel strokes.
@export_range(0.05, 1.0, 0.05) var brush_strength := 0.3
@export_range(0.02, 1.0, 0.01) var scalpel_strength := 0.16
@export_range(0.05, 1.0, 0.05) var sponge_strength := 0.25
@export var soil_particle_color := Color(0.55, 0.41, 0.26)
@export var crust_particle_color := Color(0.9, 0.88, 0.8)
@export var patina_particle_color := Color(0.78, 0.8, 0.72)

var stage := Stage.SOIL
## The stages of this find, in order (Stage values; SHINE and DONE follow).
var stages: Array[int] = []

var _masks := {}            # Stage -> PackedByteArray
var _textures := {}         # Stage -> ImageTexture
var _targets := {}          # Stage -> int (dirty pixels at the start)
var _left := {}             # Stage -> int (dirty pixels left)
var _shard_map := PackedByteArray()
var _shard_texture: ImageTexture
var _shard_views: Array[TextureRect] = []
var _shard_placed: Array[bool] = []
var _dragged_shard := -1
var _drag_offset := Vector2.ZERO
var _stage_index := 0
var _shard_rng: RandomNumberGenerator
var _dirty := false
var _pressed := false
var _last_uv := Vector2(-1, -1)
var _sound_cooldown := 0.0
var _finishing := false
var _material: ShaderMaterial

@onready var artifact_view: TextureRect = %ArtifactView
@onready var stage_label: Label = %StageLabel
@onready var brush_icon: Control = %BrushIcon
@onready var sponge_icon: Control = %SpongeIcon
@onready var scalpel_icon: Control = %ScalpelIcon
@onready var shards_icon: Control = %ShardsIcon
@onready var stage_steps: Label = %StageSteps
@onready var stage_progress: ProgressBar = %StageProgress
@onready var hint_label: Label = %HintLabel
@onready var artifact_name: Label = %ArtifactName
@onready var info_card: Control = %InfoCard
@onready var info_title: Label = %InfoTitle
@onready var info_text: Label = %InfoText
@onready var skip_button: Button = %SkipButton
@onready var done_button: Button = %DoneButton
@onready var dust: CPUParticles2D = %Dust


func _ready() -> void:
	if pending_expedition != null:
		expedition_definition = pending_expedition
		pending_expedition = null
	if not pending_return_scene.is_empty():
		return_scene_path = pending_return_scene
		pending_return_scene = ""
	_audio_call("play_music_track", [&"restoration", &"menu"])
	artifact_view.gui_input.connect(_on_view_input)
	skip_button.pressed.connect(skip)
	done_button.pressed.connect(_leave)
	_material = artifact_view.material as ShaderMaterial
	_setup_artifact()


func _process(delta: float) -> void:
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)
	if _dirty:
		_dirty = false
		_upload_masks()
		_refresh_progress()


## Stage progress 0..1 (share of the dirty area already cleaned, or of the
## shards already in place).
func get_progress() -> float:
	if stage == Stage.SHARDS:
		var placed := 0
		for flag in _shard_placed:
			if flag:
				placed += 1
		return float(placed) / maxf(1.0, _shard_placed.size())
	if _is_rubbing_stage(stage):
		return 1.0 - float(_left[stage]) / float(_targets[stage])
	return 1.0


## Brush, scalpel or sponge along a line, in UV of the find (0..1). Used by input and tests.
func rub_uv_line(from_uv: Vector2, to_uv: Vector2) -> void:
	if not _is_rubbing_stage(stage) or _finishing:
		return
	var radius := _tool_radius()
	var from_px := from_uv * MASK_SIZE
	var to_px := to_uv * MASK_SIZE
	var steps := maxi(1, ceili(from_px.distance_to(to_px) / (radius * 0.45)))
	for index in steps + 1:
		_stamp(from_px.lerp(to_px, float(index) / steps), radius)
	_dirty = true


func shard_count() -> int:
	return _shard_views.size()


func is_shard_placed(index: int) -> bool:
	return index >= 0 and index < _shard_placed.size() and _shard_placed[index]


## Where the shard is now, as an offset from its place (share of the view size).
func shard_offset(index: int) -> Vector2:
	if index < 0 or index >= _shard_views.size():
		return Vector2.ZERO
	return _shard_views[index].position / artifact_view.size.x


## Moves a shard by `delta_uv` (share of the view size) and drops it there:
## close enough to its place, it snaps in. Used by input and tests.
func drop_shard(index: int, offset_uv: Vector2) -> bool:
	if stage != Stage.SHARDS or index < 0 or index >= _shard_views.size() or _shard_placed[index]:
		return false
	_shard_views[index].position = offset_uv * artifact_view.size.x
	return _try_snap(index)


## Finishes everything at once (the "Пропустить" button).
func skip() -> void:
	for index in _shard_views.size():
		_shard_placed[index] = true
		_shard_views[index].position = Vector2.ZERO
	_clear_shards()
	for key in _masks:
		_clear_mask(key)
		_left[key] = 0
	_upload_masks()
	for parameter in ["soil_fade", "crust_fade", "patina_fade", "seams"]:
		_material.set_shader_parameter(parameter, 0.0)
	_material.set_shader_parameter("silhouette", 0.0)
	_finishing = false
	_start_shine(false)


func _setup_artifact() -> void:
	var texture: Texture2D = expedition_definition.full_artifact_texture if expedition_definition != null else null
	artifact_view.texture = texture
	artifact_name.text = tr(expedition_definition.artifact_name_ru) if expedition_definition != null else ""
	info_card.hide()
	done_button.hide()
	skip_button.show()
	stages.clear()
	var names: Array[StringName] = DEFAULT_STAGES
	if expedition_definition != null and not expedition_definition.restoration_stages.is_empty():
		names = expedition_definition.restoration_stages
	for name in names:
		if STAGE_BY_NAME.has(name) and not stages.has(STAGE_BY_NAME[name]):
			stages.append(STAGE_BY_NAME[name])
	var alpha := _alpha_mask(texture)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(expedition_definition.artifact_id)) if expedition_definition != null else 1
	_build_soil(alpha)
	_build_patina(alpha)
	_build_crust(alpha, rng)
	_build_shard_map(alpha, rng)
	for key in [Stage.SOIL, Stage.CRUST, Stage.PATINA]:
		# A find without this stage starts with that layer already clean.
		if not stages.has(key):
			_clear_mask(key)
			_left[key] = 0
		_textures[key] = ImageTexture.create_from_image(_mask_image(_masks[key]))
	_shard_texture = ImageTexture.create_from_image(_mask_image(_shard_map))
	_material.set_shader_parameter("soil_mask", _textures[Stage.SOIL])
	_material.set_shader_parameter("crust_mask", _textures[Stage.CRUST])
	_material.set_shader_parameter("patina_mask", _textures[Stage.PATINA])
	_material.set_shader_parameter("shard_map", _shard_texture)
	_material.set_shader_parameter("shard_id", -1)
	_material.set_shader_parameter("soil_fade", 1.0)
	_material.set_shader_parameter("crust_fade", 1.0)
	_material.set_shader_parameter("patina_fade", 1.0)
	_material.set_shader_parameter("seams", 0.0)
	_material.set_shader_parameter("silhouette", 0.0)
	_material.set_shader_parameter("shine", -1.0)
	_stage_index = 0
	_shard_rng = rng
	_set_stage(stages[0] if not stages.is_empty() else Stage.SHINE)
	if stage == Stage.SHARDS:
		_create_shards(_shard_rng)


func _build_soil(alpha: PackedByteArray) -> void:
	# The object plus a soft lump around it, torn by the shader's noise.
	var blurred := _blur(alpha)
	var mask := PackedByteArray()
	mask.resize(MASK_SIZE * MASK_SIZE)
	var target := 0
	for index in alpha.size():
		var x := index % MASK_SIZE
		var y := index / MASK_SIZE
		var centre := 1.0 - Vector2(x, y).distance_to(Vector2(MASK_SIZE, MASK_SIZE) * 0.5) / (MASK_SIZE * 0.47)
		var soil_value := clampf(maxf(blurred[index] / 255.0 * 1.6, centre * 1.2), 0.0, 1.0)
		mask[index] = int(soil_value * 255.0)
		if mask[index] > DIRTY_THRESHOLD:
			target += 1
	_store_mask(Stage.SOIL, mask, target)


func _build_patina(alpha: PackedByteArray) -> void:
	var mask := PackedByteArray()
	mask.resize(MASK_SIZE * MASK_SIZE)
	var target := 0
	for index in alpha.size():
		if alpha[index] > 128:
			mask[index] = 255
			target += 1
	_store_mask(Stage.PATINA, mask, target)


## Hard crust: uneven patches that follow noise over the object (about a
## quarter of it), thicker in the middle of a patch.
func _build_crust(alpha: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var mask := PackedByteArray()
	mask.resize(MASK_SIZE * MASK_SIZE)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 3
	var inside := 0
	var values := PackedFloat32Array()
	values.resize(MASK_SIZE * MASK_SIZE)
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			var index := y * MASK_SIZE + x
			if alpha[index] < 150:
				values[index] = -1.0
				continue
			inside += 1
			values[index] = noise.get_noise_2d(x, y)
	if inside == 0:
		_store_mask(Stage.CRUST, mask, 0)
		return
	# The threshold that covers ~25 % of the object.
	var sorted := values.duplicate()
	sorted.sort()
	var cut := sorted[sorted.size() - maxi(1, inside / 4)]
	var target := 0
	for index in values.size():
		var v := values[index]
		if v < cut:
			continue
		mask[index] = int(clampf((v - cut) * 14.0 + 0.45, 0.0, 1.0) * 255.0)
		if mask[index] > DIRTY_THRESHOLD:
			target += 1
	_store_mask(Stage.CRUST, mask, target)


## Shards: nearest of N seeds inside the object (a Voronoi split).
func _build_shard_map(alpha: PackedByteArray, rng: RandomNumberGenerator) -> void:
	_shard_map.resize(MASK_SIZE * MASK_SIZE)
	_shard_map.fill(NO_SHARD)
	var count := _requested_shards()
	var inside: Array[Vector2] = []
	for index in range(0, alpha.size(), 5):
		if alpha[index] > 128:
			inside.append(Vector2(index % MASK_SIZE, index / MASK_SIZE))
	if inside.is_empty():
		return
	# Seeds spread out: each next one is the farthest of a few random candidates.
	var seeds: Array[Vector2] = [inside[rng.randi_range(0, inside.size() - 1)]]
	while seeds.size() < count:
		var best := inside[0]
		var best_distance := -1.0
		for attempt in 12:
			var candidate := inside[rng.randi_range(0, inside.size() - 1)]
			var nearest := INF
			for existing in seeds:
				nearest = minf(nearest, candidate.distance_squared_to(existing))
			if nearest > best_distance:
				best_distance = nearest
				best = candidate
		seeds.append(best)
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			var index := y * MASK_SIZE + x
			if alpha[index] <= 40:
				continue
			# A little wobble makes the cracks less straight.
			var point := Vector2(x, y) + Vector2(sin(y * 0.21) * 3.0, cos(x * 0.19) * 3.0)
			var nearest_index := 0
			var nearest_distance := INF
			for seed_index in seeds.size():
				var distance := point.distance_squared_to(seeds[seed_index])
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_index = seed_index
			_shard_map[index] = nearest_index * 32


func _requested_shards() -> int:
	if expedition_definition != null and expedition_definition.restoration_shards > 0:
		return clampi(expedition_definition.restoration_shards, 2, 6)
	return 4


func _create_shards(rng: RandomNumberGenerator) -> void:
	var count := _requested_shards()
	var start_angle := rng.randf_range(0.0, TAU)
	for index in count:
		var view := TextureRect.new()
		view.name = "Shard%d" % index
		view.texture = artifact_view.texture
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_SCALE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		var material := _material.duplicate() as ShaderMaterial
		material.set_shader_parameter("shard_id", index)
		material.set_shader_parameter("silhouette", 0.0)
		view.material = material
		artifact_view.add_child(view)
		_shard_views.append(view)
		_shard_placed.append(false)
	# The find falls apart: the pieces fly from their places (after the layout
	# has given the view a size).
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_audio_call("play_sfx", [&"stone_break"])
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index in _shard_views.size():
		var angle := start_angle + TAU * index / maxf(1.0, _shard_views.size()) + rng.randf_range(-0.3, 0.3)
		var target := Vector2.from_angle(angle) * artifact_view.size.x * rng.randf_range(0.2, 0.27)
		tween.tween_property(_shard_views[index], "position", target, 0.45)


## Packed arrays are values: a cleared copy must be stored back.
func _clear_mask(key: int) -> void:
	var empty := PackedByteArray()
	empty.resize(MASK_SIZE * MASK_SIZE)
	_masks[key] = empty
	_left[key] = 0


func _store_mask(key: int, mask: PackedByteArray, target: int) -> void:
	_masks[key] = mask
	_targets[key] = maxi(1, target)
	_left[key] = target


func _alpha_mask(texture: Texture2D) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(MASK_SIZE * MASK_SIZE)
	if texture == null:
		return result
	var image := texture.get_image()
	if image == null:
		return result
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)
	var data := image.get_data()
	for index in result.size():
		result[index] = data[index * 4 + 3]
	return result


## Cheap blur: shrink to 1/8 and grow back.
func _blur(mask: PackedByteArray) -> PackedByteArray:
	var image := _mask_image(mask)
	image.resize(MASK_SIZE / 8, MASK_SIZE / 8, Image.INTERPOLATE_BILINEAR)
	image.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)
	return image.get_data()


func _mask_image(mask: PackedByteArray) -> Image:
	return Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, mask)


func _is_rubbing_stage(value: int) -> bool:
	return value == Stage.SOIL or value == Stage.CRUST or value == Stage.PATINA


func _tool_radius() -> int:
	match stage:
		Stage.CRUST:
			return scalpel_radius
		Stage.PATINA:
			return sponge_radius
	return brush_radius


func _tool_strength() -> float:
	match stage:
		Stage.CRUST:
			return scalpel_strength
		Stage.PATINA:
			return sponge_strength
	return brush_strength


func _stamp(centre: Vector2, radius: int) -> void:
	var mask: PackedByteArray = _masks[stage]
	var strength := _tool_strength()
	var left: int = _left[stage]
	var min_x := maxi(0, int(centre.x) - radius)
	var max_x := mini(MASK_SIZE - 1, int(centre.x) + radius)
	var min_y := maxi(0, int(centre.y) - radius)
	var max_y := mini(MASK_SIZE - 1, int(centre.y) + radius)
	var radius_squared := float(radius * radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance_squared := (x - centre.x) * (x - centre.x) + (y - centre.y) * (y - centre.y)
			if distance_squared > radius_squared:
				continue
			var falloff := 1.0 - distance_squared / radius_squared
			var index := y * MASK_SIZE + x
			var old_value := mask[index]
			if old_value == 0:
				continue
			var new_value := maxi(0, old_value - int(255.0 * strength * falloff))
			mask[index] = new_value
			if old_value > DIRTY_THRESHOLD and new_value <= DIRTY_THRESHOLD:
				left -= 1
	_masks[stage] = mask
	_left[stage] = left


func _upload_masks() -> void:
	for key in _textures:
		(_textures[key] as ImageTexture).update(_mask_image(_masks[key]))


func _refresh_progress() -> void:
	stage_progress.value = get_progress() * 100.0
	if _finishing or not _is_rubbing_stage(stage):
		return
	if _left[stage] <= _targets[stage] * AUTO_FINISH_SHARE:
		_auto_finish()


func _fade_parameter(value: int) -> String:
	match value:
		Stage.SOIL:
			return "soil_fade"
		Stage.CRUST:
			return "crust_fade"
	return "patina_fade"


func _auto_finish() -> void:
	_finishing = true
	_pressed = false
	dust.emitting = false
	var parameter := _fade_parameter(stage)
	var finished_stage := stage
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: _material.set_shader_parameter(parameter, value), 1.0, 0.0, 0.45)
	await tween.finished
	if not is_inside_tree():
		return
	_clear_mask(finished_stage)
	_left[finished_stage] = 0
	_upload_masks()
	_finishing = false
	_next_stage()


## Goes to the next stage of this find, or to the shine after the last one.
func _next_stage() -> void:
	_stage_index += 1
	if _stage_index >= stages.size():
		_start_shine(true)
		return
	_audio_call("play_sfx", [&"stone_hit", 1.2])
	_set_stage(stages[_stage_index])
	if stage == Stage.SHARDS:
		_create_shards(_shard_rng)


func _try_snap(index: int) -> bool:
	var view := _shard_views[index]
	if view.position.length() > SNAP_DISTANCE * artifact_view.size.x:
		return false
	_shard_placed[index] = true
	var tween := create_tween()
	tween.tween_property(view, "position", Vector2.ZERO, 0.12)
	_audio_call("play_sfx", [&"restore_snap", randf_range(0.95, 1.08)])
	stage_progress.value = get_progress() * 100.0
	if not _shard_placed.has(false):
		_finish_shards()
	return true


## All shards are in place: the glue seams fade, the whole find is shown again.
func _finish_shards() -> void:
	_finishing = true
	_material.set_shader_parameter("silhouette", 0.0)
	_material.set_shader_parameter("seams", 1.0)
	_clear_shards()
	hint_label.text = tr("Осколки склеены!")
	var tween := create_tween()
	tween.tween_interval(0.35)
	tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("seams", value), 1.0, 0.0, 0.6)
	await tween.finished
	if not is_inside_tree():
		return
	_finishing = false
	_next_stage()


func _clear_shards() -> void:
	for view in _shard_views:
		view.queue_free()
	_shard_views.clear()
	_dragged_shard = -1


func _start_shine(animated: bool) -> void:
	_set_stage(Stage.SHINE)
	_audio_call("play_sfx", [&"fragment_found"])
	if animated:
		var tween := create_tween()
		tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("shine", value), -0.4, 1.4, 0.9)
		await tween.finished
		if not is_inside_tree():
			return
	_material.set_shader_parameter("shine", -1.0)
	_finish()


func _finish() -> void:
	var artifact_id := expedition_definition.artifact_id if expedition_definition != null else &""
	if artifact_id != &"":
		var error := ProgressStore.mark_artifact_restored(artifact_id)
		if error != OK:
			push_warning("Could not save the restored find: %s" % error_string(error))
	info_title.text = tr(expedition_definition.artifact_name_ru) if expedition_definition != null else ""
	info_text.text = tr("Находка очищена и заняла место в коллекции.")
	info_card.show()
	skip_button.hide()
	done_button.show()
	_audio_call("play_sfx", [&"victory"])
	_set_stage(Stage.DONE)
	restoration_finished.emit(artifact_id)


func _set_stage(new_stage: int) -> void:
	stage = new_stage
	match stage:
		Stage.SHARDS:
			stage_label.text = tr("Осколки: соберите находку")
			hint_label.text = tr("Находка разбита! Перетащите осколки на свои места")
			_material.set_shader_parameter("silhouette", 1.0)
		Stage.SOIL:
			stage_label.text = tr("Кисть: снимите грунт")
			hint_label.text = tr("Водите пальцем по находке")
		Stage.CRUST:
			stage_label.text = tr("Скальпель: снимите корку")
			hint_label.text = tr("Проведите несколько раз по светлым наростам")
		Stage.PATINA:
			stage_label.text = tr("Губка: сотрите налёт")
			hint_label.text = tr("Протрите находку, чтобы вернуть цвет")
		Stage.SHINE, Stage.DONE:
			stage_label.text = tr("Находка отреставрирована!")
			hint_label.text = ""
	var working := stage == Stage.SHARDS or _is_rubbing_stage(stage)
	stage_progress.visible = working
	brush_icon.visible = stage == Stage.SOIL
	sponge_icon.visible = stage == Stage.PATINA
	scalpel_icon.visible = stage == Stage.CRUST
	shards_icon.visible = stage == Stage.SHARDS
	# "Этап 2 из 3" while working.
	stage_steps.visible = working and stages.size() > 1
	stage_steps.text = tr("Этап %d из %d") % [_stage_index + 1, stages.size()]
	stage_progress.value = get_progress() * 100.0
	stage_changed.emit(stage)


func _on_view_input(event: InputEvent) -> void:
	if stage == Stage.SHARDS:
		_on_shard_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		dust.emitting = false
		if event.pressed:
			_last_uv = _to_uv(event.position)
			rub_uv_line(_last_uv, _last_uv)
			_feedback(event.position)
		return
	if event is InputEventMouseMotion and _pressed:
		var uv := _to_uv(event.position)
		rub_uv_line(_last_uv, uv)
		_last_uv = uv
		_feedback(event.position)


func _on_shard_input(event: InputEvent) -> void:
	if _finishing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragged_shard = _shard_at(event.position)
			if _dragged_shard >= 0:
				var view := _shard_views[_dragged_shard]
				_drag_offset = view.position - event.position
				view.move_to_front()
				view.scale = Vector2.ONE * 1.03
				_audio_call("play_sfx", [&"pick"])
		elif _dragged_shard >= 0:
			var index := _dragged_shard
			_dragged_shard = -1
			_shard_views[index].scale = Vector2.ONE
			_try_snap(index)
		return
	if event is InputEventMouseMotion and _dragged_shard >= 0:
		var view := _shard_views[_dragged_shard]
		var limit := artifact_view.size.x * 0.45
		view.position = (event.position + _drag_offset).clamp(Vector2(-limit, -limit), Vector2(limit, limit))


## The topmost loose shard under a point of the view (pixel test on shard_map).
func _shard_at(local_position: Vector2) -> int:
	for child_index in range(artifact_view.get_child_count() - 1, -1, -1):
		var view := artifact_view.get_child(child_index) as TextureRect
		var index := _shard_views.find(view)
		if index < 0 or _shard_placed[index]:
			continue
		var uv := _to_uv(local_position - view.position)
		# A finger is bigger than a pixel: look around the point a little.
		for offset: Vector2 in [Vector2.ZERO, Vector2(0.03, 0), Vector2(-0.03, 0), Vector2(0, 0.03), Vector2(0, -0.03)]:
			var p: Vector2 = ((uv + offset) * MASK_SIZE).floor()
			if p.x < 0 or p.y < 0 or p.x >= MASK_SIZE or p.y >= MASK_SIZE:
				continue
			if _shard_map[int(p.y) * MASK_SIZE + int(p.x)] == index * 32:
				return index
	return -1


func _to_uv(local_position: Vector2) -> Vector2:
	var size := artifact_view.size
	return Vector2(local_position.x / maxf(1.0, size.x), local_position.y / maxf(1.0, size.y))


func _feedback(local_position: Vector2) -> void:
	if not _is_rubbing_stage(stage):
		return
	dust.global_position = artifact_view.get_global_transform() * local_position
	match stage:
		Stage.SOIL:
			dust.color = soil_particle_color
		Stage.CRUST:
			dust.color = crust_particle_color
		_:
			dust.color = patina_particle_color
	dust.emitting = true
	if _sound_cooldown > 0.0:
		return
	match stage:
		Stage.SOIL:
			_sound_cooldown = SOUND_INTERVAL
			_audio_call("play_sfx", [&"restore_brush", randf_range(0.9, 1.12)])
		Stage.CRUST:
			_sound_cooldown = SCALPEL_SOUND_INTERVAL
			_audio_call("play_sfx", [&"restore_scalpel", randf_range(0.9, 1.15)])
		Stage.PATINA:
			_sound_cooldown = SOUND_INTERVAL * 1.6
			_audio_call("play_sfx", [&"restore_sponge", randf_range(0.92, 1.06)])


## Autoload looked up at run time: this class can then be compiled before the
## autoloads exist (tests that name the class, tools).
func _audio_call(method: String, arguments: Array) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.callv(method, arguments)


func _leave() -> void:
	ScreenCache.change_to(get_tree(), return_scene_path)
