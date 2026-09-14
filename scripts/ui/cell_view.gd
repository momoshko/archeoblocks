class_name CellView
extends Control

@export var block_texture_set: BlockTextureSet

@onready var background: TextureRect = $Background
@onready var artifact_hint: Control = $ArtifactHint
@onready var burial_depth_2: TextureRect = $ArtifactHint/BurialDepth2
@onready var burial_depth_1: TextureRect = $ArtifactHint/BurialDepth1
@onready var soil_visual: TextureRect = $SoilVisual
@onready var strong_soil_visual: TextureRect = $StrongSoilVisual
@onready var artifact_target_border: Panel = $ArtifactTargetBorder
@onready var artifact_target_prediction: Panel = $ArtifactTargetBorder/PredictionEmphasis
@onready var dig_flash: ColorRect = $DigFlash
@onready var block_visual: TextureRect = $BlockVisual
@onready var stone_obstacle: StoneObstacleView = $StoneObstacle
@onready var root_obstacle: RootObstacleView = $RootObstacle
@onready var valid_preview: TextureRect = $ValidPreview
@onready var invalid_preview: TextureRect = $InvalidPreview
@onready var hint_ghost: TextureRect = $HintGhost
@onready var selection_highlight: Panel = $SelectionHighlight
@onready var root_growth_warning: Control = $RootGrowthWarning

@export_range(0.05, 1.0, 0.01) var dig_feedback_duration := 0.18
@export_range(0.2, 1.0, 0.05) var artifact_intro_pulse_duration := 0.45
@export_range(1.0, 1.2, 0.01) var artifact_intro_pulse_scale := 1.08
@export_range(0.45, 0.6, 0.01) var hint_ghost_alpha := 0.52

var _artifact_target_depth := 0
var _artifact_target_emphasized := false
var _dig_feedback_tween: Tween
var _fragment_feedback_tween: Tween
var _clear_feedback_tween: Tween
var _artifact_intro_tween: Tween


func reset_visual_state() -> void:
	clear_transient_feedback()
	background.show()
	soil_visual.hide()
	strong_soil_visual.hide()
	artifact_hint.hide()
	burial_depth_2.hide()
	burial_depth_1.hide()
	artifact_target_border.hide()
	artifact_target_prediction.hide()
	dig_flash.hide()
	block_visual.hide()
	block_visual.modulate = Color.WHITE
	stone_obstacle.reset_visual()
	root_obstacle.reset_visual()
	hint_ghost.hide()
	root_growth_warning.hide()


func set_empty() -> void:
	block_visual.hide()
	block_visual.modulate = Color.WHITE
	clear_preview()


func set_occupied(color: Color) -> void:
	var resolved_texture := BlockTextureResolver.texture_for_color(block_texture_set, color)
	if resolved_texture != null:
		block_visual.texture = resolved_texture
	block_visual.modulate = Color.WHITE
	block_visual.show()
	hint_ghost.hide()
	clear_preview()


func set_stone_obstacle(durability: int) -> void:
	root_obstacle.clear_root()
	stone_obstacle.show_durability(durability)


func clear_stone_obstacle() -> void:
	stone_obstacle.clear_obstacle()


func set_root_obstacle() -> void:
	stone_obstacle.clear_obstacle()
	root_obstacle.show_root()


func clear_root_obstacle() -> void:
	root_obstacle.clear_root()


func play_root_hit_feedback(destroyed: bool, duration: float) -> void:
	root_obstacle.play_hit_feedback(destroyed, duration)


func play_root_growth_source_feedback(duration: float) -> void:
	root_obstacle.play_growth_source_feedback(duration)


func play_root_growth_appear(duration: float) -> void:
	root_obstacle.play_growth_appear(duration)


func set_root_growth_warning(enabled: bool) -> void:
	root_growth_warning.visible = enabled


func play_stone_hit_feedback(destroyed: bool, duration: float) -> void:
	stone_obstacle.play_hit_feedback(destroyed, duration)


func set_excavation_state(
	soil_depth: int,
	has_artifact: bool,
	_fragment_collected := false,
	_emphasize_remaining := false
) -> void:
	background.visible = soil_depth <= 0
	soil_visual.visible = soil_depth == 1
	strong_soil_visual.visible = soil_depth >= 2

	artifact_hint.visible = has_artifact and soil_depth > 0
	burial_depth_2.visible = has_artifact and soil_depth >= 2
	burial_depth_1.visible = has_artifact and soil_depth == 1
	_artifact_target_depth = soil_depth
	artifact_target_border.visible = has_artifact and soil_depth > 0 and not _fragment_collected
	if not artifact_target_border.visible:
		_stop_artifact_target_intro()
	set_artifact_target_emphasized(false)


func set_artifact_target_emphasized(enabled: bool) -> void:
	if enabled and _artifact_intro_tween != null:
		_stop_artifact_target_intro()
	_artifact_target_emphasized = enabled and artifact_target_border.visible
	artifact_target_prediction.visible = _artifact_target_emphasized or _artifact_intro_tween != null
	if _artifact_intro_tween == null:
		artifact_target_border.modulate = (
			Color(1.12, 1.08, 0.82, 1.0)
			if _artifact_target_emphasized
			else _artifact_target_default_modulate()
		)


func play_artifact_target_intro() -> void:
	if not artifact_target_border.visible:
		return
	_stop_artifact_target_intro()
	artifact_target_border.pivot_offset = artifact_target_border.size * 0.5
	artifact_target_border.scale = Vector2.ONE
	artifact_target_prediction.show()
	_artifact_intro_tween = create_tween()
	var rise_duration := artifact_intro_pulse_duration * 0.4
	var settle_duration := artifact_intro_pulse_duration - rise_duration
	_artifact_intro_tween.tween_property(
		artifact_target_border,
		"scale",
		Vector2.ONE * artifact_intro_pulse_scale,
		rise_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_artifact_intro_tween.parallel().tween_property(
		artifact_target_border,
		"modulate",
		Color(1.16, 1.1, 0.76, 1.0),
		rise_duration
	)
	_artifact_intro_tween.tween_property(
		artifact_target_border,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_artifact_intro_tween.parallel().tween_property(
		artifact_target_border,
		"modulate",
		_artifact_target_default_modulate(),
		settle_duration
	)
	_artifact_intro_tween.tween_callback(_finish_artifact_target_intro)


func is_artifact_target_intro_active() -> bool:
	return _artifact_intro_tween != null and _artifact_intro_tween.is_running()


func _finish_artifact_target_intro() -> void:
	_artifact_intro_tween = null
	artifact_target_border.scale = Vector2.ONE
	artifact_target_border.modulate = _artifact_target_default_modulate()
	artifact_target_prediction.visible = _artifact_target_emphasized


func _stop_artifact_target_intro() -> void:
	if _artifact_intro_tween != null:
		_artifact_intro_tween.kill()
		_artifact_intro_tween = null
	if is_instance_valid(artifact_target_border):
		artifact_target_border.scale = Vector2.ONE
		artifact_target_border.modulate = _artifact_target_default_modulate()
	if is_instance_valid(artifact_target_prediction):
		artifact_target_prediction.visible = _artifact_target_emphasized


func _artifact_target_default_modulate() -> Color:
	var marker_alpha := 0.72 if _artifact_target_depth >= 2 else 1.0
	return Color(1.0, 1.0, 1.0, marker_alpha)


func play_dig_feedback() -> void:
	if _dig_feedback_tween != null:
		_dig_feedback_tween.kill()
	dig_flash.modulate = Color.WHITE
	dig_flash.show()
	_dig_feedback_tween = create_tween()
	_dig_feedback_tween.tween_property(dig_flash, "modulate:a", 0.0, dig_feedback_duration)
	_dig_feedback_tween.tween_callback(func() -> void:
		_dig_feedback_tween = null
		dig_flash.hide()
		dig_flash.modulate = Color.WHITE
	)


func start_fragment_found_feedback() -> void:
	if _fragment_feedback_tween != null:
		_fragment_feedback_tween.kill()
	selection_highlight.modulate = Color.WHITE
	selection_highlight.show()
	_fragment_feedback_tween = create_tween()
	_fragment_feedback_tween.tween_property(selection_highlight, "modulate:a", 0.25, 0.14)
	_fragment_feedback_tween.tween_property(selection_highlight, "modulate:a", 1.0, 0.14)


func finish_fragment_found_feedback() -> void:
	if _fragment_feedback_tween != null:
		_fragment_feedback_tween.kill()
		_fragment_feedback_tween = null
	selection_highlight.hide()
	selection_highlight.modulate = Color.WHITE


func set_hint_highlight(enabled: bool, cosmetic_color: Color = Color.WHITE) -> void:
	selection_highlight.hide()
	valid_preview.hide()
	invalid_preview.hide()
	if enabled:
		var resolved_texture := BlockTextureResolver.texture_for_color(block_texture_set, cosmetic_color)
		if resolved_texture != null:
			hint_ghost.texture = resolved_texture
		hint_ghost.modulate = Color(1.0, 1.0, 1.0, hint_ghost_alpha)
	hint_ghost.visible = enabled


func set_preview(is_valid: bool, _cosmetic_color: Color) -> void:
	hint_ghost.hide()
	valid_preview.visible = is_valid
	invalid_preview.visible = not is_valid
	selection_highlight.hide()


func clear_preview() -> void:
	valid_preview.hide()
	invalid_preview.hide()
	selection_highlight.hide()


func start_clear_feedback(duration: float) -> void:
	if not block_visual.visible:
		return
	if _clear_feedback_tween != null:
		_clear_feedback_tween.kill()
	_clear_feedback_tween = create_tween()
	_clear_feedback_tween.tween_property(block_visual, "modulate:a", 0.1, duration)


func clear_transient_feedback() -> void:
	_stop_artifact_target_intro()
	if _dig_feedback_tween != null:
		_dig_feedback_tween.kill()
		_dig_feedback_tween = null
	if _fragment_feedback_tween != null:
		_fragment_feedback_tween.kill()
		_fragment_feedback_tween = null
	if _clear_feedback_tween != null:
		_clear_feedback_tween.kill()
		_clear_feedback_tween = null
	dig_flash.hide()
	dig_flash.modulate = Color.WHITE
	selection_highlight.hide()
	selection_highlight.modulate = Color.WHITE
	hint_ghost.hide()
	hint_ghost.modulate = Color.WHITE
	block_visual.modulate = Color.WHITE
	clear_preview()
	set_artifact_target_emphasized(false)
