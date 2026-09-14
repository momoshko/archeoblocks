class_name ArtifactDiscoveryFeedback
extends Control

@export_range(0.5, 1.0, 0.05) var display_seconds := 0.75

@onready var card: PanelContainer = $Center/DiscoveryCard
@onready var artifact_name: Label = $Center/DiscoveryCard/Layout/ArtifactName
@onready var artwork_slots: Array[TextureRect] = [
	$Center/DiscoveryCard/Layout/ArtworkRow/Artwork01,
	$Center/DiscoveryCard/Layout/ArtworkRow/Artwork02,
	$Center/DiscoveryCard/Layout/ArtworkRow/Artwork03,
]

var _tween: Tween
var _presentation_id := 0


func clear() -> void:
	_presentation_id += 1
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_node_ready():
		hide()
		return
	for slot in artwork_slots:
		slot.texture = null
		slot.hide()
	card.modulate = Color.WHITE
	card.scale = Vector2.ONE
	hide()


func show_discoveries(textures: Array[Texture2D], name_ru: String) -> void:
	var visible_textures: Array[Texture2D] = []
	for texture in textures:
		if texture != null:
			visible_textures.append(texture)
	if visible_textures.is_empty():
		return

	clear()
	var current_id := _presentation_id
	artifact_name.text = name_ru
	for index in artwork_slots.size():
		var slot := artwork_slots[index]
		if index < visible_textures.size():
			slot.texture = ArtifactTextureUtil.fit_visible_alpha(visible_textures[index])
			slot.show()
		else:
			slot.texture = null
			slot.hide()

	show()
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.82
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(card, "scale", Vector2.ONE, 0.18)
	_tween.tween_property(card, "modulate:a", 1.0, 0.14)
	await get_tree().create_timer(display_seconds).timeout
	if current_id != _presentation_id:
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(card, "scale", Vector2.ONE * 1.04, 0.16)
	_tween.tween_property(card, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.16).timeout
	if current_id == _presentation_id:
		clear()
