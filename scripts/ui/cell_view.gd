class_name CellView
extends Control

@onready var artifact_hint: ColorRect = $ArtifactHint
@onready var soil_visual: ColorRect = $SoilVisual
@onready var block_visual: ColorRect = $BlockVisual
@onready var valid_preview: ColorRect = $ValidPreview
@onready var invalid_preview: ColorRect = $InvalidPreview
@onready var selection_highlight: Panel = $SelectionHighlight


func set_empty() -> void:
	artifact_hint.hide()
	soil_visual.hide()
	block_visual.hide()
	block_visual.modulate = Color.WHITE
	clear_preview()


func set_occupied(color: Color) -> void:
	artifact_hint.hide()
	soil_visual.hide()
	block_visual.color = color
	block_visual.modulate = Color.WHITE
	block_visual.show()
	clear_preview()


func set_preview(is_valid: bool, cosmetic_color: Color) -> void:
	valid_preview.hide()
	invalid_preview.hide()
	if is_valid:
		valid_preview.color = Color(cosmetic_color.r, cosmetic_color.g, cosmetic_color.b, valid_preview.color.a)
		valid_preview.show()
	else:
		invalid_preview.show()
	selection_highlight.show()


func clear_preview() -> void:
	valid_preview.hide()
	invalid_preview.hide()
	selection_highlight.hide()


func start_clear_feedback(duration: float) -> void:
	if not block_visual.visible:
		return
	var tween := create_tween()
	tween.tween_property(block_visual, "modulate:a", 0.1, duration)

